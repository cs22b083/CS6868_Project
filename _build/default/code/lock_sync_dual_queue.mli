type 'a t
(** A blocking synchronous queue implemented with [Mutex] and [Condition].

    [put] and [take] rendezvous directly: neither operation completes until a
    complementary operation has matched it. *)

val create : unit -> 'a t
(** [create ()] returns an empty blocking synchronous queue. *)

val put : 'a t -> 'a -> unit
(** [put q v] waits until [v] is handed to one [take]. *)

val take : 'a t -> 'a
(** [take q] waits until it receives a value from one [put]. *)

val try_put : 'a t -> 'a -> bool
(** [try_put q v] attempts to hand [v] to a waiting [take].
    Returns [true] if successful, [false] if no consumer is waiting.
    Never blocks. *)

val try_take : 'a t -> 'a option
(** [try_take q] attempts to receive a value from a waiting [put].
    Returns [Some value] if successful, [None] if no producer is waiting.
    Never blocks. *)
