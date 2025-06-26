.PHONY: test test-watch compile clean deps docs

# Default target
all: deps compile test

# Install dependencies
deps:
	gleam deps download

# Compile the project
compile:
	gleam build

# Compile Elixir test helpers first, then run tests
test: compile-elixir
	gleam test

# Compile Elixir test modules
compile-elixir:
	@echo "Compiling Elixir test helpers..."
	@mkdir -p _build/test/lib/glixir/ebin
	@if [ -f test/support/test_genserver.ex ]; then \
		elixirc -o _build/test/lib/glixir/ebin test/support/*.ex; \
	fi

# Watch mode for development
test-watch:
	gleam test --watch

# Clean build artifacts
clean:
	rm -rf _build
	rm -rf _gleam

# Generate documentation
docs:
	gleam docs build
	@echo "Documentation generated in build/docs/"

# Format code
format:
