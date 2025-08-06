GATEWAYS_DIR := $(wildcard ./gateways/*)
GATEWAY_IDS := $(notdir $(GATEWAYS_DIR))

# Install all dependencies of the project and the gateways
install:
	@for dir in ./gateways/*; do \
		if [ -d $$dir ]; then \
			echo "Installing $$dir"; \
			(cd $$dir && ./install.sh); \
			echo "\n"; \
		fi; \
	done

# Build and run the subgraphs
run-subgraphs:
	cargo build --release && ./target/release/subgraphs

run-loadtest:
    k6 run k6.js

define RUN_GATEWAY
run-$(1):
	(cd ./gateways/$(1) && ./run.sh)
endef

$(foreach gateway,$(GATEWAY_IDS),$(eval $(call RUN_GATEWAY,$(gateway))))
