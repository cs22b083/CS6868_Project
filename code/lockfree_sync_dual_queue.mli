type 'a t
(** A lock-free synchronous dual queue.

    [put] and [take] rendezvous directly: neither operation completes until a
    complementary operation has matched it. *)

val create : unit -> 'a t
(** [create ()] returns an empty synchronous dual queue. *)

val put : 'a t -> 'a -> unit
(** [put q v] waits until [v] is handed to one [take]. *)

val take : 'a t -> 'a
(** [take q] waits until it receives a value from one [put]. *)

val try_put : 'a t -> 'a -> bool
(** [try_put q v] is non-blocking.
    Returns [true] if [v] is handed to a waiting [take], [false] otherwise. *)

val try_take : 'a t -> 'a option
(** [try_take q] is non-blocking.
    Returns [Some v] if a waiting [put] is matched, [None] otherwise. *)

