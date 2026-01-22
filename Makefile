CC := gcc
CFLAGS := -Wall -Wextra -O2 -std=c99
LDFLAGS := -lm -lpthread

# Target executables
TARGETS := progA progB

# Source files
SOURCES := MT25081_Part_A_Program_A.c MT25081_Part_A_Program_B.c MT25081_Part_B_workers.c
HEADERS := MT25081_Part_B_workers.h
OBJECTS := $(SOURCES:.c=.o)

# Default target
.PHONY: all
all: $(TARGETS)

# Build progA (process-based)
progA: MT25081_Part_A_Program_A.o MT25081_Part_B_workers.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

# Build progB (thread-based)
progB: MT25081_Part_A_Program_B.o MT25081_Part_B_workers.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

# Compile object files
%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

# Clean build artifacts
.PHONY: clean
clean:
	rm -f $(OBJECTS) $(TARGETS)
	rm -f /tmp/io_worker_temp_file.txt

# Phony target to rebuild
.PHONY: rebuild
rebuild: clean all

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all      - Build all programs (progA and progB)"
	@echo "  progA    - Build progA (process-based)"
	@echo "  progB    - Build progB (thread-based)"
	@echo "  clean    - Remove object files and executables"
	@echo "  rebuild  - Clean and build all"
	@echo "  help     - Display this help message"
