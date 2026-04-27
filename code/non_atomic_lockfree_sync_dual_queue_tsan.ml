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
  item : 'a option ref;
  next : 'a node option ref;
}

type 'a t = {
  head : 'a node ref;
  tail : 'a node ref;
}

let create () =
  let sentinel =
    { kind = Sentinel; item = ref None; next = ref None }
  in
  { head = ref sentinel; tail = ref sentinel }

(* Just check if the node got the opposite node. *)
let is_fulfilled node =
  match node.kind, !(node.item) with
  | Sentinel, _ -> true
  | Data, None -> true
  | Request, Some _ -> true
  | Data, Some _ | Request, None -> false

(* Completed nodes may remain at the front briefly.  Any operation can help move
   [head] past fulfilled nodes, following the same helping style as the
   Michael-Scott queue. *)
let rec help_advance_head (q : 'a t) =
  let first : 'a node = !(q.head) in
  let next_ref = first.next in
  match !next_ref with
  | Some next when is_fulfilled next ->
      if !(q.head) = first then q.head := next;
      help_advance_head q
  | _ -> ()

type append_result =
  | Appended
  | Retry

(* Append only if the queue is still empty or still contains waiters of the same
   kind as [node] at the CAS point.  If an opposite-kind waiter appears, the
   caller must retry from the top and try to fulfil that waiter instead. *)
let try_append_node q node =
  let first = !(q.head) in
  let last = !(q.tail) in
  let last_next_ref = last.next in
  let next = !last_next_ref in
  if last != !(q.tail) then (* someone changed the tail *)
    Retry
  else
    match next with
    | Some next -> (* move tail *)
        if !(q.tail) = last then q.tail := next;
        Retry
    | None ->
        if last == first || last.kind = node.kind then (* empty queue *)
          if !last_next_ref = None then begin
            last.next := Some node;
            if !(q.tail) = last then q.tail := node;
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



let rec put q value =
  help_advance_head q;
  let first = !(q.head) in
  let first_next_ref = first.next in
  match !first_next_ref with
  | Some ({ kind = Request; item; _ } as request) ->
      (* A consumer is already waiting.  Supplying [Some value] fulfils the
         request and is the rendezvous linearization point. *)
      if !item = None then begin
        item := Some value;
        if !(q.head) = first then q.head := request
      end else
        put q value
  | _ ->
      let last = !(q.tail) in        
      if last.kind = Data || last == !(q.head) then begin
        (* No visible request is available, so publish a data reservation and
           wait until a consumer changes [item] from [Some value] to [None]. *)
        let node =
          { kind = Data; item = ref (Some value); next = ref None }
        in
        match try_append_node q node with
        | Appended -> wait_until_fulfilled node
        | Retry -> put q value
      end else
        put q value

let rec take q =
  help_advance_head q;
  let first = !(q.head) in
  let first_next_ref = first.next in
  match !first_next_ref with
  | Some ({ kind = Data; item; _ } as data) -> begin
      let item_ref = item in
      match !item_ref with
      | Some value as current ->
          (* A producer is already waiting.  Changing [Some value] to [None]
             fulfils the data node and is the rendezvous linearization point. *)
          if !item_ref = current then begin
            item := None;
            if !(q.head) = first then q.head := data;
            value
          end else
            take q
      | None ->
          if !(q.head) = first then q.head := data;
          take q
    end
  | _ ->
      let last = !(q.tail) in
      if last.kind = Request || last == !(q.head) then begin
        (* No visible data node is available, so publish a request reservation
           and wait until a producer stores [Some value]. *)
        let node =
          { kind = Request; item = ref None; next = ref None }
        in
        match try_append_node q node with
        | Appended ->
            let rec wait () =
              match !(node.item) with
              | Some value -> value
              | None ->
                  Domain.cpu_relax ();
                  wait ()
            in
            wait ()
        | Retry -> take q
      end else
        take q
