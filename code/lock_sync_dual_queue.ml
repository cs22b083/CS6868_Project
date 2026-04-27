type 'a producer = {
  value : 'a;
  condition : Condition.t;
  mutable taken : bool;
}

type 'a consumer = {
  condition : Condition.t;
  mutable value : 'a option;
}

type 'a t = {
  mutex : Mutex.t;
  producers : 'a producer Queue.t;
  consumers : 'a consumer Queue.t;
}

let create () =
  {
    mutex = Mutex.create ();
    producers = Queue.create ();
    consumers = Queue.create ();
  }

let rec wait_until mutex condition predicate =
  if predicate () then
    ()
  else begin
    Condition.wait condition mutex;
    wait_until mutex condition predicate
  end

let put q value =
  Mutex.lock q.mutex;
  match Queue.take_opt q.consumers with
  | Some consumer ->
      (* A consumer is already waiting, so this put can complete immediately
         after publishing the value and waking that consumer. *)
      consumer.value <- Some value;
      Condition.signal consumer.condition;
      Mutex.unlock q.mutex
  | None ->
      (* No consumer is available.  Publish a producer reservation and block
         until a later take marks it as consumed. *)
      let producer =
        { value; condition = Condition.create (); taken = false }
      in
      Queue.add producer q.producers;
      wait_until q.mutex producer.condition (fun () -> producer.taken);
      Mutex.unlock q.mutex

let take q =
  Mutex.lock q.mutex;
  match Queue.take_opt q.producers with
  | Some producer ->
      (* A producer is already waiting.  Taking its value and setting [taken]
         completes the rendezvous for both sides. *)
      let value = producer.value in
      producer.taken <- true;
      Condition.signal producer.condition;
      Mutex.unlock q.mutex;
      value
  | None ->
      (* No producer is available.  Publish a consumer reservation and block
         until a later put stores a value. *)
      let consumer =
        { condition = Condition.create (); value = None }
      in
      Queue.add consumer q.consumers;
      wait_until q.mutex consumer.condition (fun () ->
        Option.is_some consumer.value);
      let value =
        match consumer.value with
        | Some value -> value
        | None -> assert false
      in
      Mutex.unlock q.mutex;
      value

let try_put q value =
  Mutex.lock q.mutex;
  match Queue.take_opt q.consumers with
  | Some consumer ->
      (* A consumer is waiting, complete immediately *)
      consumer.value <- Some value;
      Condition.signal consumer.condition;
      Mutex.unlock q.mutex;
      true
  | None ->
      (* No consumer available, don't block *)
      Mutex.unlock q.mutex;
      false

let try_take q =
  Mutex.lock q.mutex;
  match Queue.take_opt q.producers with
  | Some producer ->
      (* A producer is waiting, complete immediately *)
      let value = producer.value in
      producer.taken <- true;
      Condition.signal producer.condition;
      Mutex.unlock q.mutex;
      Some value
  | None ->
      (* No producer available, don't block *)
      Mutex.unlock q.mutex;
      None