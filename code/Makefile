.PHONY: all build test test-manual benchmark clean help

all: build

build:
	dune build

test: test-manual

test-manual:
	@echo "=== Running manual rendezvous tests ==="
	dune exec ./test_manual.exe

benchmark:
	@echo "=== Running rendezvous throughput benchmark ==="
	dune exec ./benchmark.exe -- 100000 results/benchmark.csv

clean:
	dune clean

help:
	@echo "Available targets:"
	@echo "  make build        - Build the project"
	@echo "  make test         - Run available tests"
	@echo "  make test-manual  - Run manual rendezvous tests"
	@echo "  make benchmark    - Run rendezvous throughput benchmark"
	@echo "  make clean        - Remove build artifacts"
