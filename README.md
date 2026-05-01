## Project 23: Synchronous Dual Queue

**Difficulty: ★★★★☆** — Reservation nodes and rendezvous coordination on top of the Michael-Scott queue structure require complex CAS logic.

### Background

The standard concurrent queue from Lecture 08 is **asynchronous**: an enqueuer
always succeeds immediately, even if no dequeuer is waiting. A **synchronous
queue** requires that an enqueuer and a dequeuer rendezvous — neither completes
until matched with a partner. This is useful for handoff-style coordination
(e.g., Go channels, Java's `SynchronousQueue`). Scherer, Lea, and Scott (2009)
designed a **dual queue** that unifies both modes: if the queue is empty or
contains only waiters of the same type, an arriving thread enqueues a
**reservation** (a node representing an unfulfilled request); when a complementary
thread arrives, it fulfils the reservation and both proceed. The dual queue is
lock-free and linearizable, built on the Michael-Scott queue structure from
Lecture 08 with reservation nodes.

### Tasks

1. Implement a **lock-free synchronous dual queue** in OCaml 5. The queue holds
   nodes of two types: DATA (an enqueuer waiting for a dequeuer) and REQUEST (a
   dequeuer waiting for an enqueuer). An arriving thread checks the tail: if the
   queue is empty or contains nodes of its own type, it enqueues a reservation
   and spins/parks until fulfilled; otherwise, it fulfils the head reservation
   using CAS.
2. Implement a **simple synchronous exchanger** (pair up two threads using a
   single `Atomic` slot with CAS, as in the elimination array from Lecture 08)
   as a simpler baseline.
3. Implement a **mutex + condition variable synchronous queue** as a blocking
   baseline: the enqueuer waits on a condition variable until a dequeuer arrives,
   and vice versa.
4. Verify correctness using **QCheck-Lin**: model as a sequential synchronous
   queue where `enqueue(v)` blocks until matched with a `dequeue()` that
   returns `v`. The linearization point is the moment of rendezvous.
5. Run **TSAN** on the lock-free implementation.
6. Benchmark rendezvous throughput (matched pairs/sec) across 2–8 threads under:
   (a) balanced (equal enqueuers and dequeuers), (b) enqueue-heavy, and
   (c) dequeue-heavy configurations.
7. Apply the synchronous dual queue to implement a simple **producer-consumer
   pipeline** (e.g., a parallel map where producers generate work items and
   consumers process them with direct handoff, no buffering).

### Research Question

How does the lock-free dual queue's rendezvous throughput compare against a
mutex/condition-based synchronous queue, and does the overhead of reservation
nodes pay off at higher thread counts?

### References

- W. N. Scherer III, D. Lea, M. L. Scott, "Scalable Synchronous Queues," *CACM*, 2009
- AoMPP Chapter 10, Section 10.6.1 (A Naïve Synchronous Queue)
- Java `SynchronousQueue` source code

## Repository Layout

- `code/lockfree_sync_dual_queue.ml` — lock-free synchronous dual queue
- `code/lock_sync_dual_queue.ml` — mutex + condition-variable baseline
- `code/lockfree_exchanger.ml` — single-slot exchanger baseline
- `code/test_manual.ml` — direct concurrent sanity tests
- `code/benchmark.ml` — rendezvous throughput benchmark
- `code/producer_consumer_pipeline/pipeline_demo.ml` — producer-consumer direct handoff demo
- `report-template/` — report sources

## Build and Run

Run all commands from `code/`.

Build:

```sh
make build
```

Manual tests:

```sh
make test-manual
```

QCheck-Lin executable:

```sh
make test-qcheck
```

All tests currently wired in the Makefile:

```sh
make test
```

Benchmark:

```sh
make benchmark
```

This writes CSV output to `code/results/benchmark.csv`.

For a smaller benchmark run:

```sh
dune exec ./benchmark.exe -- 1000 results/benchmark-debug.csv
```

Pipeline demo:

```sh
make pipeline
```

## TSAN

Use the TSAN-enabled OCaml switch, then run from `code/`:

```sh
dune exec ./test_manual.exe
```

If you want to capture the TSAN output:

```sh
mkdir -p results
dune exec ./test_manual.exe 2>&1 | tee results/tsan-test-manual.txt
```

## Video

Presentation link: (https://drive.google.com/file/d/1aIuSQzYdGzsPMEeV5cVNROHXHKKhm8lk/view?usp=sharing)
