(* A synchronous dual queue contains two kinds of real nodes:

   Data:
     a producer is waiting for a consumer to take its value.
   Request:
     a consumer is waiting for a producer to provide a value.

   The queue is "dual" because both producers and consumers may enqueue
   reservations.  A complementary operation either fulfils the first waiting
   reservation or appends its own reservation and spins until fulfilled. *)
type kind =
  | Sentinel
  | Data
  | Request

(* [item] carries both the payload and the fulfilment state:

   Data node:
     [Some v] means the producer is still waiting.
     [None] means a consumer has taken [v].

   Request node:
     [None] means the consumer is still waiting.
     [Some v] means a producer has supplied [v]. *)
type 'a node = {
  kind : kind;
  item : 'a option Atomic.t;
  next : 'a node option Atomic.t;
}

type 'a t = {
  head : 'a node Atomic.t;
  tail : 'a node Atomic.t;
}

let create () =
  let sentinel =
    { kind = Sentinel; item = Atomic.make_contended None; next = Atomic.make None }
  in
  { head = Atomic.make_contended sentinel; tail = Atomic.make_contended sentinel }

(* Just check if the node got the opposite node. *)
let is_fulfilled node =
  match node.kind, Atomic.get node.item with
  | Sentinel, _ -> true
  | Data, None -> true
  | Request, Some _ -> true
  | Data, Some _ | Request, None -> false

(* Completed nodes may remain at the front briefly.  Any operation can help move
   [head] past fulfilled nodes, following the same helping style as the
   Michael-Scott queue. *)
let rec help_advance_head q =
  let first = Atomic.get q.head in
  match Atomic.get first.next with
  | Some next when is_fulfilled next ->
      ignore (Atomic.compare_and_set q.head first next);
      help_advance_head q
  | _ -> ()

type append_result =
  | Appended
  | Retry

(* Append only if the queue is still empty or still contains waiters of the same
   kind as [node] at the CAS point.  If an opposite-kind waiter appears, the
   caller must retry from the top and try to fulfil that waiter instead. *)
let try_append_node q node =
  let first = Atomic.get q.head in
  let last = Atomic.get q.tail in
  let next = Atomic.get last.next in
  if last != Atomic.get q.tail then (* someone changed the tail *)
    Retry
  else
    match next with
    | Some next -> (* move tail *)
        ignore (Atomic.compare_and_set q.tail last next);
        Retry
    | None ->
        if last == first || last.kind = node.kind then (* empty queue *)
          if Atomic.compare_and_set last.next None (Some node) then begin
            ignore (Atomic.compare_and_set q.tail last node);
            Appended
          end else
            Retry
        else
          Retry

let wait_until_fulfilled node =
  let rec loop () =
    if is_fulfilled node then
      ()
    else begin
      Domain.cpu_relax ();
      loop ()
    end
  in
  loop ()

let rec try_put q value =
  help_advance_head q;
  let first = Atomic.get q.head in
  match Atomic.get first.next with
  | Some ({ kind = Request; item; _ } as request) ->
      (* Non-blocking fast path: complete only when a waiting request exists. *)
      if Atomic.compare_and_set item None (Some value) then begin
        ignore (Atomic.compare_and_set q.head first request);
        true
      end else
        try_put q value
  | _ -> false

let rec try_take q =
  help_advance_head q;
  let first = Atomic.get q.head in
  match Atomic.get first.next with
  | Some ({ kind = Data; item; _ } as data) -> begin
      match Atomic.get item with
      | Some value as current ->
          (* Non-blocking fast path: complete only when a waiting data node exists. *)
          if Atomic.compare_and_set item current None then begin
            ignore (Atomic.compare_and_set q.head first data);
            Some value
          end else
            try_take q
      | None ->
          ignore (Atomic.compare_and_set q.head first data);
          try_take q
    end
  | _ -> None



let rec put q value =
  help_advance_head q;
  let first = Atomic.get q.head in
  match Atomic.get first.next with
  | Some ({ kind = Request; item; _ } as request) ->
      (* A consumer is already waiting.  Supplying [Some value] fulfils the
         request and is the rendezvous linearization point. *)
      if Atomic.compare_and_set item None (Some value) then
        ignore (Atomic.compare_and_set q.head first request)
      else
        put q value
  | _ ->
      let last = Atomic.get q.tail in        
      if last.kind = Data || last == Atomic.get q.head then begin
        (* No visible request is available, so publish a data reservation and
           wait until a consumer changes [item] from [Some value] to [None]. *)
        let node =
          { kind = Data; item = Atomic.make_contended (Some value); next = Atomic.make None }
        in
        match try_append_node q node with
        | Appended -> wait_until_fulfilled node
        | Retry -> put q value
      end else
        put q value

let rec take q =
  help_advance_head q;
  let first = Atomic.get q.head in
  match Atomic.get first.next with
  | Some ({ kind = Data; item; _ } as data) -> begin
      match Atomic.get item with
      | Some value as current ->
          (* A producer is already waiting.  Changing [Some value] to [None]
             fulfils the data node and is the rendezvous linearization point. *)
          if Atomic.compare_and_set item current None then begin
            ignore (Atomic.compare_and_set q.head first data);
            value
          end else
            take q
      | None -> (*impossible since there is help_advance_head before start*)
          ignore (Atomic.compare_and_set q.head first data);
          take q
    end
  | _ ->
      let last = Atomic.get q.tail in
      if last.kind = Request || last == Atomic.get q.head then begin
        (* No visible data node is available, so publish a request reservation
           and wait until a producer stores [Some value]. *)
        let node =
          { kind = Request; item = Atomic.make_contended None; next = Atomic.make None }
        in
        match try_append_node q node with
        | Appended ->
            let rec wait () =
              match Atomic.get node.item with
              | Some value -> value
              | None ->
                  Domain.cpu_relax ();
                  wait ()
            in
            wait ()
        | Retry -> take q
      end else
        take q
