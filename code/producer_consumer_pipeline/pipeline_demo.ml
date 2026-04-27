(* A small producer-consumer pipeline built on the lock-free synchronous dual
   queue.

   Producers generate integer jobs and hand them directly to consumers through
   [Sync_queue.put], so there is no intermediate buffer: every handoff is a
   rendezvous.  Consumers repeatedly [take] work, process it, and stop only
   after receiving an explicit [Stop] message once all producers have finished.

   Step-by-step:

   1. Each producer creates a sequence of [Job] values and calls [put] for each
      one.  Every [put] blocks until some consumer is ready to take that job.
   2. Each consumer loops on [take].  When it receives [Job value], it performs
      the demo "work" for that value and updates its local counters.
   3. The main thread waits for every producer domain to finish publishing all
      jobs.
   4. After producers are done, the main thread sends one [Stop] message per
      consumer, again via synchronous [put].
   5. Each consumer exits when it receives [Stop], prints a short summary, and
      then the main thread joins all consumer domains and prints the final
      pipeline summary. *)
module Sync_queue = Project_lockfree_sync_dual_queue.Lockfree_sync_dual_queue

type work_item =
  | Job of int
  | Stop

let producer_count = 4
let consumer_count = 8
let jobs_per_producer = 10

let producer queue producer_id =
  for job_id = 0 to jobs_per_producer - 1 do
    let job = Job ((producer_id * 1000) + job_id) in
    Sync_queue.put queue job
  done

let consumer queue consumer_id =
  let rec loop processed checksum =
    match Sync_queue.take queue with
    | Stop ->
        Printf.printf "consumer %d processed=%d checksum=%d\n%!"
          consumer_id processed checksum
    | Job value ->
        let result = value * value in
        loop (processed + 1) (checksum + result)
  in
  loop 0 0

let () =
  let queue = Sync_queue.create () in
  let consumers =
    Array.init consumer_count (fun consumer_id ->
      Domain.spawn (fun () -> consumer queue consumer_id))
  in
  let producers =
    Array.init producer_count (fun producer_id ->
      Domain.spawn (fun () -> producer queue producer_id))
  in
  Array.iter Domain.join producers;
  for _ = 1 to consumer_count do
    Sync_queue.put queue Stop
  done;
  Array.iter Domain.join consumers;
  Printf.printf "pipeline complete: producers=%d consumers=%d jobs=%d\n%!"
    producer_count
    consumer_count
    (producer_count * jobs_per_producer)
