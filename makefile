#############################
# ----- CONFIGURATION ----- #
#############################

# Build directory
BUILD_DIR = build

#######################
# ----- TARGETS ----- #
#######################

# Default target
.PHONY: all
all: lint format

# Static analysis and format
.PHONY: lint format
lint:
	@echo "Running static analysis..."
	fusesoc run --no-export --target lint polito:len5:dummy-coproc
format:
	@echo "Running code formatting..."
	fusesoc run --no-export --target format polito:len5:dummy-coproc

# RTL simulation
.PHONY: sim build run
sim:
	@echo "Running RTL simulation..."
	fusesoc run --no-export --target sim polito:len5:dummy-coproc
build:
	@echo "Building the design..."
	fusesoc run --no-export --target sim --build polito:len5:dummy-coproc
run:
	@echo "Running RTL simulation..."
	fusesoc run --no-export --target sim --run polito:len5:dummy-coproc

# Show waveforms
.PHONY: waves
waves: $(BUILD_DIR)/sim-common/waves.fst
	gtkwave -a tb/waves.gtkw $<

# Utilities
# ---------
# Create missing directories
%/:
	mkdir -p $@

# Clean up
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -rf $(BUILD_DIR)
