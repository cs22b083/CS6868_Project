type 'a t
(** A single-slot lock-free exchanger. *)

val create : unit -> 'a t
(** [create ()] returns an empty exchanger. *)

val exchange : 'a t -> 'a -> 'a
(** [exchange t v] waits for one partner and atomically swaps [v] with the
    partner's value. *)
