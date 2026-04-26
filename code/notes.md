- Project 23: Synchronous Dual Queue

Based on **Project 23: Synchronous Dual Queue**, the full roadmap is:

**1. Lock-Free Synchronous Dual Queue**
Implement the main data structure.

Files:

```text
code/lockfree_sync_dual_queue.mli
code/lockfree_sync_dual_queue.ml
```

Required behavior:

- Queue has `DATA` nodes for waiting producers.
- Queue has `REQUEST` nodes for waiting consumers.
- `put q v` should not return until some `take q` receives `v`.
- `take q` should not return until some `put q v` provides a value.
- If the queue has same-type waiters, append a reservation node.
- If the queue has opposite-type waiters, fulfill the oldest reservation using CAS.
- Explain linearization points clearly in comments/report.

Current status: initial version exists.

**2. Simple Lock-Free Exchanger Baseline**
Implement the simpler baseline using one atomic slot.

Files:

```text
code/lockfree_exchanger.mli
code/lockfree_exchanger.ml
```

Required behavior:

- Two threads meet at one slot.
- First thread waits.
- Second thread completes exchange.
- Used as a simpler comparison point.

Current status: initial version exists.

**3. Mutex + Condition Variable Baseline**
Implement the blocking baseline.

Files to complete:

```text
code/lock_sync_dual_queue.mli
code/lock_sync_dual_queue.ml
```

Required behavior:

- Use `Mutex` and `Condition`.
- Producers wait until consumers arrive.
- Consumers wait until producers arrive.
- This is the main blocking comparison against the lock-free queue.

**4. Manual Tests**
Basic sanity tests for all implementations.

File:

```text
code/test_manual.ml
```

Should test:

- one producer, one consumer
- consumer arrives first
- producer arrives first
- multiple producers/consumers
- exchanger pair exchange
- blocking queue pair exchange

**5. QCheck-Lin Correctness Tests**
Project specifically asks for QCheck-Lin.

File:

```text
code/qcheck_lin.ml
```

Goal:

- Model synchronous queue behavior.
- Test whether concurrent `put`/`take` histories are linearizable.
- At minimum test the lock-free queue.
- Ideally also test the blocking baseline.

This is important for grading because project 23 explicitly lists QCheck-Lin.

**6. TSAN Run**
Run ThreadSanitizer on the lock-free implementation.

Need to document:

- exact command used
- whether TSAN passed
- any races found
- if TSAN cannot be run locally, explain why honestly in the report

**7. Benchmark**
Create benchmark file.

Likely file:

```text
code/benchmark.ml
```

Compare:

- lock-free synchronous dual queue
- mutex/condition synchronous queue
- simple exchanger baseline

Measure:

```text
matched pairs / second
```

Thread/domain counts:

```text
2, 4, 6, 8
```

Workloads required by project 23:

```text
balanced        equal producers and consumers
enqueue-heavy   more producers than consumers
dequeue-heavy   more consumers than producers
```

**8. Producer-Consumer Pipeline**
Project asks to apply the queue to a simple pipeline.

Use existing folder:

```text
code/producer_consumer_pipeline/
```

Implement something simple:

- producers generate integers/tasks
- consumers process them
- handoff happens through the synchronous dual queue
- no buffering

**9. Dune + Makefile**
Current files:

```text
dune-project
code/dune
code/Makefile
```

Need final targets:

```text
make build
make test
make benchmark
make clean
```

Later `code/dune` must include all executables:

```text
test_manual
qcheck_lin
benchmark
pipeline demo
```

**10. Report**
Use:

```text
report-template/main.tex
report-template/references.bib
```

Required sections:

- Goals
- Background
- Tasks Undertaken
- Evaluation
- Reflection on LLM Use
- Conclusions
- Contributions

Report must answer the research question:

```text
How does the lock-free dual queue's rendezvous throughput compare against a
mutex/condition-based synchronous queue, and does the overhead of reservation
nodes pay off at higher thread counts?
```

**11. Presentation**
Exactly 10 minutes.

Suggested structure:

```text
1 min  problem and motivation
2 min  synchronous queue and dual queue idea
2 min  lock-free algorithm
1 min  baselines
2 min  testing and TSAN
1.5 min benchmark results
0.5 min conclusion
```

**Best Next Steps**

Do this order:

1. Finish `lock_sync_dual_queue.ml` and `.mli`.
2. Expand `test_manual.ml` to test all three implementations.
3. Run `make build` and `make test`.
4. Add `qcheck_lin.ml`.
5. Add `benchmark.ml`.
6. Add pipeline demo.
7. Collect results.
8. Write report.
9. Record video.
10. Final README cleanup.