module Lockfree = Project_lockfree_sync_dual_queue.Lockfree_sync_dual_queue
module Blocking = Project_lock_sync_dual_queue.Lock_sync_dual_queue
module Exchanger = Project_lockfree_exchanger.Lockfree_exchanger

type workload =
  | Balanced
  | Enqueue_heavy
  | Dequeue_heavy

type implementation = {
  name : string;
  run : pairs:int -> producers:int -> consumers:int -> float;
  workloads : workload list;
}

let workload_name = function
  | Balanced -> "balanced"
  | Enqueue_heavy -> "enqueue-heavy"
  | Dequeue_heavy -> "dequeue-heavy"

let split_workers workload domains =
  match workload with
  | Balanced -> (domains / 2, domains / 2)
  | Enqueue_heavy ->
      let producers = max 1 ((3 * domains) / 4) in
      (producers, domains - producers)
  | Dequeue_heavy ->
      let consumers = max 1 ((3 * domains) / 4) in
      (domains - consumers, consumers)

let operation_counts ~total ~workers =
  Array.init workers (fun i ->
    let base = total / workers in
    if i < total mod workers then base + 1 else base)

let wait_for_start start =
  while not (Atomic.get start) do
    Domain.cpu_relax ()
  done

let time f =
  let start_time = Unix.gettimeofday () in
  f ();
  Unix.gettimeofday () -. start_time

let run_lockfree ~pairs ~producers ~consumers =
  let q = Lockfree.create () in
  let start = Atomic.make false in
  let producer_counts = operation_counts ~total:pairs ~workers:producers in
  let consumer_counts = operation_counts ~total:pairs ~workers:consumers in
  let producer_domains =
    Array.map
      (fun count ->
        Domain.spawn (fun () ->
          wait_for_start start;
          for i = 1 to count do
            Lockfree.put q i
          done))
      producer_counts
  in
  let consumer_domains =
    Array.map
      (fun count ->
        Domain.spawn (fun () ->
          wait_for_start start;
          for _ = 1 to count do
            ignore (Lockfree.take q)
          done))
      consumer_counts
  in
  let elapsed =
    time (fun () ->
      Atomic.set start true;
      Array.iter Domain.join producer_domains;
      Array.iter Domain.join consumer_domains)
  in
  elapsed

let run_blocking ~pairs ~producers ~consumers =
  let q = Blocking.create () in
  let start = Atomic.make false in
  let producer_counts = operation_counts ~total:pairs ~workers:producers in
  let consumer_counts = operation_counts ~total:pairs ~workers:consumers in
  let producer_domains =
    Array.map
      (fun count ->
        Domain.spawn (fun () ->
          wait_for_start start;
          for i = 1 to count do
            Blocking.put q i
          done))
      producer_counts
  in
  let consumer_domains =
    Array.map
      (fun count ->
        Domain.spawn (fun () ->
          wait_for_start start;
          for _ = 1 to count do
            ignore (Blocking.take q)
          done))
      consumer_counts
  in
  let elapsed =
    time (fun () ->
      Atomic.set start true;
      Array.iter Domain.join producer_domains;
      Array.iter Domain.join consumer_domains)
  in
  elapsed

  (* create one slot for each exchange pair to avoid the races *)
let run_exchanger ~pairs ~producers ~consumers =
  let domains = producers + consumers in
  let pair_count = domains / 2 in
  let exchanges_per_domain = operation_counts ~total:pairs ~workers:pair_count in
  let slots = Array.init pair_count (fun _ -> Exchanger.create ()) in
  let start = Atomic.make false in
  let workers =
    Array.init domains
      (fun domain_id ->
        let slot_id = domain_id / 2 in
        let count = exchanges_per_domain.(slot_id) in
        let ex = slots.(slot_id) in
        Domain.spawn (fun () ->
          wait_for_start start;
          for i = 1 to count do
            ignore (Exchanger.exchange ex i)
          done))
  in
  let elapsed =
    time (fun () ->
      Atomic.set start true;
      Array.iter Domain.join workers)
  in
  elapsed

let workloads = [ Balanced; Enqueue_heavy; Dequeue_heavy ]
let domain_counts = [ 2; 4; 6; 8 ]

let implementations =
  [
    { name = "lockfree"; run = run_lockfree; workloads };
    { name = "blocking"; run = run_blocking; workloads };
    { name = "exchanger"; run = run_exchanger; workloads = [ Balanced ] };
  ]

let pairs =
  if Array.length Sys.argv >= 2 then
    int_of_string Sys.argv.(1)
  else
    100_000

let output_path =
  if Array.length Sys.argv >= 3 then
    Some Sys.argv.(2)
  else
    None

let write_row out_channel row =
  output_string stdout row;
  output_string out_channel row;
  flush stdout;
  flush out_channel

let run_one out_channel implementation workload domains =
  let producers, consumers = split_workers workload domains in
  let seconds = implementation.run ~pairs ~producers ~consumers in
  let throughput = float_of_int pairs /. seconds in
  let row =
    Printf.sprintf "%s,%s,%d,%d,%d,%d,%.6f,%.2f\n"
    implementation.name
    (workload_name workload)
    domains
    producers
    consumers
    pairs
    seconds
    throughput
  in
  write_row out_channel row

let with_output_channel f =
  match output_path with
  | None -> f stdout
  | Some path ->
      let directory = Filename.dirname path in
      if directory <> "." && not (Sys.file_exists directory) then
        Unix.mkdir directory 0o755;
      let out_channel = open_out path in
      Fun.protect
        ~finally:(fun () -> close_out out_channel)
        (fun () -> f out_channel)

let () =
  with_output_channel (fun out_channel ->
    write_row out_channel
      "implementation,workload,domains,producers,consumers,pairs,seconds,pairs_per_second\n";
    List.iter
      (fun implementation ->
        List.iter
          (fun workload ->
            List.iter
              (fun domains -> run_one out_channel implementation workload domains)
              domain_counts)
          implementation.workloads)
      implementations)
