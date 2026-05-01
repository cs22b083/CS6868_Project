(** QCheck-Lin Linearizability Test for LockFreeSyncDualQueue

    Uses non-blocking [try_put]/[try_take] to avoid deadlocks in the
    linearizability checker while still exercising lock-free rendezvous logic.
*)

module LQ = Project_lockfree_sync_dual_queue.Lockfree_sync_dual_queue

module LQSig = struct
  type t = int LQ.t

  let init () = LQ.create ()

  let cleanup _ = ()

  open Lin

  let int_small = nat_small

  let api =
    [
      val_ "try_put" LQ.try_put (t @-> int_small @-> returning bool);
      val_ "try_take" LQ.try_take (t @-> returning (option int));
    ]
end

module LQ_domain = Lin_domain.Make (LQSig)

let () =
  QCheck_base_runner.run_tests_main
    [ LQ_domain.lin_test ~count:500 ~name:"LockFreeSyncDualQueue linearizability" ]
