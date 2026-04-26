module Q = Project_lockfree_sync_dual_queue.Lockfree_sync_dual_queue
module Bq = Project_lock_sync_dual_queue.Lock_sync_dual_queue
module Ex = Project_lockfree_exchanger.Lockfree_exchanger

let log message =
  print_endline message;
  flush stdout

let test_lockfree_single_pair () =
  log "lockfree queue: single pair";
  let q = Q.create () in
  let producer =
    Domain.spawn (fun () -> Q.put q 42)
  in
  let received = Q.take q in
  Domain.join producer;
  if received <> 42 then
    failwith "lockfree_sync_dual_queue returned the wrong value"

let test_lockfree_repeated_pairs count =
  log (Printf.sprintf "lockfree queue: %d repeated pairs" count);
  let q = Q.create () in
  let producer =
    Domain.spawn (fun () ->
      for i = 1 to count do
        Q.put q i
      done)
  in
  for expected = 1 to count do
    let received = Q.take q in
    if received <> expected then
      failwith "lockfree_sync_dual_queue returned values out of order"
  done;
  Domain.join producer

let operation_counts ~total ~workers =
  Array.init workers (fun i ->
    let base = total / workers in
    if i < total mod workers then base + 1 else base)

let check_seen label seen =
  Array.iteri
    (fun value was_seen ->
      if not was_seen then
        failwith (Printf.sprintf "%s missed value %d" label value))
    seen

let test_lockfree_many ~producers ~consumers ~pairs =
  log
    (Printf.sprintf "lockfree queue: %dp/%dc %d pairs"
       producers consumers pairs);
  let q = Q.create () in
  let producer_counts = operation_counts ~total:pairs ~workers:producers in
  let consumer_counts = operation_counts ~total:pairs ~workers:consumers in
  let seen = Array.make pairs false in
  let seen_mutex = Mutex.create () in
  let producer_domains =
    Array.mapi
      (fun producer_id count ->
        Domain.spawn (fun () ->
          for offset = 0 to count - 1 do
            Q.put q (producer_id + (offset * producers))
          done))
      producer_counts
  in
  let consumer_domains =
    Array.map
      (fun count ->
        Domain.spawn (fun () ->
          for _ = 1 to count do
            let value = Q.take q in
            if value < 0 || value >= pairs then
              failwith "lockfree queue returned an out-of-range value";
            Mutex.lock seen_mutex;
            if seen.(value) then
              failwith "lockfree queue returned a duplicate value";
            seen.(value) <- true;
            Mutex.unlock seen_mutex
          done))
      consumer_counts
  in
  Array.iter Domain.join producer_domains;
  Array.iter Domain.join consumer_domains;
  check_seen "lockfree queue" seen

let test_blocking_single_pair () =
  log "blocking queue: single pair";
  let q = Bq.create () in
  let producer =
    Domain.spawn (fun () -> Bq.put q 42)
  in
  let received = Bq.take q in
  Domain.join producer;
  if received <> 42 then
    failwith "lock_sync_dual_queue returned the wrong value"

let test_blocking_repeated_pairs count =
  log (Printf.sprintf "blocking queue: %d repeated pairs" count);
  let q = Bq.create () in
  let producer =
    Domain.spawn (fun () ->
      for i = 1 to count do
        Bq.put q i
      done)
  in
  for expected = 1 to count do
    let received = Bq.take q in
    if received <> expected then
      failwith "lock_sync_dual_queue returned values out of order"
  done;
  Domain.join producer

let test_blocking_many ~producers ~consumers ~pairs =
  log
    (Printf.sprintf "blocking queue: %dp/%dc %d pairs"
       producers consumers pairs);
  let q = Bq.create () in
  let producer_counts = operation_counts ~total:pairs ~workers:producers in
  let consumer_counts = operation_counts ~total:pairs ~workers:consumers in
  let seen = Array.make pairs false in
  let seen_mutex = Mutex.create () in
  let producer_domains =
    Array.mapi
      (fun producer_id count ->
        Domain.spawn (fun () ->
          for offset = 0 to count - 1 do
            Bq.put q (producer_id + (offset * producers))
          done))
      producer_counts
  in
  let consumer_domains =
    Array.map
      (fun count ->
        Domain.spawn (fun () ->
          for _ = 1 to count do
            let value = Bq.take q in
            if value < 0 || value >= pairs then
              failwith "blocking queue returned an out-of-range value";
            Mutex.lock seen_mutex;
            if seen.(value) then
              failwith "blocking queue returned a duplicate value";
            seen.(value) <- true;
            Mutex.unlock seen_mutex
          done))
      consumer_counts
  in
  Array.iter Domain.join producer_domains;
  Array.iter Domain.join consumer_domains;
  check_seen "blocking queue" seen

let test_exchanger () =
  log "exchanger: single pair";
  let ex = Ex.create () in
  let left = Domain.spawn (fun () -> Ex.exchange ex "left") in
  let right_value = Ex.exchange ex "right" in
  let left_value = Domain.join left in
  if left_value <> "right" || right_value <> "left" then
    failwith "lockfree_exchanger returned the wrong values"

let test_exchanger_multiple_pairs domains =
  log (Printf.sprintf "exchanger: %d domains" domains);
  if domains mod 2 <> 0 then
    invalid_arg "exchanger test needs an even number of domains";
  let ex = Ex.create () in
  let returned = Array.make domains None in
  let workers =
    Array.init domains (fun id ->
      Domain.spawn (fun () ->
        let received = Ex.exchange ex id in
        returned.(id) <- Some received))
  in
  Array.iter Domain.join workers;
  let seen_returns = Array.make domains false in
  Array.iteri
    (fun id result ->
      match result with
      | None -> failwith "lockfree_exchanger worker did not complete"
      | Some received ->
          if received < 0 || received >= domains then
            failwith "lockfree_exchanger returned an out-of-range value";
          if received = id then
            failwith "lockfree_exchanger returned a thread's own value";
          if seen_returns.(received) then
            failwith "lockfree_exchanger returned a duplicate partner value";
          seen_returns.(received) <- true)
    returned

let () =
  test_lockfree_single_pair ();
  test_lockfree_repeated_pairs 10;
  test_lockfree_repeated_pairs 100;
  test_lockfree_many ~producers:4 ~consumers:4 ~pairs:200; 
  test_blocking_single_pair ();
  test_blocking_repeated_pairs 10;
  test_blocking_repeated_pairs 100;
  test_blocking_many ~producers:4 ~consumers:4 ~pairs:200; 
  test_exchanger ();
  test_exchanger_multiple_pairs 4;
  test_exchanger_multiple_pairs 8;
  print_endline "manual tests passed"
