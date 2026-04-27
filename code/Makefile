.PHONY: all build test test-manual test-qcheck benchmark pipeline clean help

all: build

build:
	dune build

test: test-manual test-qcheck

test-manual:
	@echo "=== Running manual rendezvous tests ==="
	dune exec ./test_manual.exe

test-qcheck:
	@echo "=== Running QCheck linearizability tests ==="
	dune exec ./qcheck_lin.exe
# 	timeout 30 dune exec ./qcheck_lin.exe

benchmark:
	@echo "=== Running rendezvous throughput benchmark ==="
	dune exec ./benchmark.exe -- 100000 results/benchmark.csv

pipeline:
	@echo "=== Running producer-consumer pipeline demo ==="
	dune exec ./producer_consumer_pipeline/pipeline_demo.exe

clean:
	dune clean

help:
	@echo "Available targets:"
	@echo "  make build        - Build the project"
	@echo "  make test         - Run all tests (manual + qcheck)"
	@echo "  make test-manual  - Run manual rendezvous tests"
	@echo "  make test-qcheck  - Run QCheck linearizability tests"
	@echo "  make benchmark    - Run rendezvous throughput benchmark"
	@echo "  make pipeline     - Run producer-consumer pipeline demo"
	@echo "  make clean        - Remove build artifacts"
