.PHONY: all build test test-manual test-qcheck benchmark clean help

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

clean:
	dune clean

help:
	@echo "Available targets:"
	@echo "  make build        - Build the project"
	@echo "  make test         - Run all tests (manual + qcheck)"
	@echo "  make test-manual  - Run manual rendezvous tests"
	@echo "  make test-qcheck  - Run QCheck linearizability tests"
	@echo "  make benchmark    - Run rendezvous throughput benchmark"
	@echo "  make clean        - Remove build artifacts"
