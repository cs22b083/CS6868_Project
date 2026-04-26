(* A single exchanger is represented by one atomic slot.

   Empty:
     no thread is waiting.
   Waiting v:
     one thread has published [v] and is spinning for a partner.
   Busy v:
     a partner has arrived, stored its value [v], and committed the exchange.

   The successful CAS from [Waiting _] to [Busy _] is the linearization point for
   both participating exchange operations. *)
type 'a state =
  | Empty
  | Waiting of 'a
  | Busy of 'a

type 'a t = 'a state Atomic.t

let create () = Atomic.make_contended Empty

let exchange slot my_item =
  (* We have installed a unique [Waiting my_item] value.  The value is unique
     because it is freshly allocated, so physical equality can tell whether the
     slot still contains our own offer. *)
  let rec wait_for_partner my_offer =
    match Atomic.get slot with
    | current when current == my_offer ->
        Domain.cpu_relax ();
        wait_for_partner my_offer
    | Busy their_item ->
        Atomic.set slot Empty;
        Some their_item
    | Empty | Waiting _ ->
        (* Our offer was displaced (e.g. spurious CAS failure on another thread,
           or the slot was reset). Restart the whole attempt. *)
        None
  in
  let rec loop () =
    match Atomic.get slot with
    | Empty as current ->
        (* First arrival: publish our item and wait for a complementary thread. *)
        let my_offer = Waiting my_item in
        if Atomic.compare_and_set slot current my_offer then
          match wait_for_partner my_offer with
          | Some item -> item
          | None -> loop ()
        else
          loop ()
    | Waiting their_item as current ->
        (* Second arrival: commit the exchange by replacing the waiting offer
           with our item. *)
        if Atomic.compare_and_set slot current (Busy my_item) then
          their_item
        else
          loop ()
    | Busy _ ->
        Domain.cpu_relax ();
        loop ()
  in
  loop ()
