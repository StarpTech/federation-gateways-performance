install:
	@for dir in ./gateways/*; do \
		if [ -d $$dir ]; then \
			echo "Installing $$dir"; \
			(cd $$dir && ./install.sh); \
			(cd $$dir && touch k6_summary.json && touch k6_summary.txt); \
			echo "\n"; \
		fi; \
	done

# Build and run the subgraphs
run-subgraphs:
	cargo build --release && ./target/release/subgraphs

test:
	@if [ -z "$(gateway)" ]; then \
		echo "Usage: make test gateway=<gateway_name>"; \
		exit 1; \
	fi
	@./test.sh $(gateway)

test-all:
	@for gateway in $(shell ls ./gateways); do \
		if [ -d ./gateways/$$gateway ]; then \
			echo "Testing $$gateway"; \
			make test gateway=$$gateway; \
			echo "\n"; \
		fi; \
	done
	cargo run -p toolkit summary
