.PHONY: help build program clean sim upload benchmark test all

# Default target
.DEFAULT_GOAL := help

# Project configuration
PROJECT := fpga_image_processor
VIVADO := vivado
PYTHON := python3

help: ## Show this help message
	@echo "FPGA Image Processor - Available Commands"
	@echo "=========================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build bitstream (synthesis + implementation)
	@echo "Building FPGA bitstream..."
	$(VIVADO) -mode batch -source scripts/build.tcl
	@echo "✓ Build complete: build/fpga_image_processor.bit"

program: ## Program FPGA with bitstream
	@echo "Programming FPGA..."
	bash scripts/program_fpga.sh

clean: ## Clean all build artifacts
	@echo "Cleaning project..."
	rm -rf vivado_project/
	rm -rf build/*
	rm -rf .Xil/
	find . -name "*.log" -delete
	find . -name "*.jou" -delete
	@echo "✓ Clean complete"

sim: ## Run simulation testbench
	@echo "Running simulation..."
	cd sim && $(VIVADO) -mode batch -source run_sim.tcl
	@echo "✓ Simulation complete"

upload: ## Upload test image to FPGA
	@echo "Uploading image..."
	$(PYTHON) python/upload_image.py --port /dev/ttyUSB0 --image test.jpg --preview

benchmark: ## Run performance benchmarks
	@echo "Running benchmarks..."
	$(PYTHON) python/benchmark.py --plot --output results/benchmarks/benchmark_results.md
	@echo "✓ Benchmark complete"

test: ## Run Python unit tests
	@echo "Running tests..."
	$(PYTHON) -m pytest tests/ -v
	@echo "✓ Tests complete"

all: clean build ## Clean and rebuild everything
	@echo "✓ Full build complete"

install-deps: ## Install Python dependencies
	$(PYTHON) -m pip install -r python/requirements.txt
	@echo "✓ Dependencies installed"

docs: ## Generate documentation
	@echo "Documentation available in docs/ directory"
	@ls -lh docs/

stats: ## Show project statistics
	@echo "Project Statistics:"
	@echo "  Verilog files:     $$(find rtl -name '*.v' | wc -l)"
	@echo "  Lines of Verilog:  $$(cat rtl/*.v | wc -l)"
	@echo "  Python files:      $$(find python -name '*.py' | wc -l)"
	@echo "  Lines of Python:   $$(cat python/*.py | wc -l)"
	@echo "  Documentation:     $$(find docs -name '*.md' | wc -l) files"

verify: ## Verify all source files exist
	@echo "Verifying project structure..."
	@test -f rtl/top.v && echo "✓ RTL sources found"
	@test -f constraints/basys3.xdc && echo "✓ Constraints found"
	@test -f python/upload_image.py && echo "✓ Python tools found"
	@test -f scripts/build.tcl && echo "✓ Build scripts found"
	@echo "✓ Project structure verified"
