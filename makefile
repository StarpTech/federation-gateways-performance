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
	@if ! [ -f ./gateway.pid ]; then \
		echo "Error: Gateway is not running"; \
		exit 1; \
	fi
	@PID=`cat ./gateway.pid`; \
	echo "Starting monitoring (PID $$PID)..."; \
	./monitor.sh $$PID & \
	MONITOR_PID=$$!; \
	echo "Monitoring started with PID $$MONITOR_PID."; \
	\
	echo "Running k6 load test..."; \
	k6 run k6.js; \
	echo "k6 load test finished."; \
	\
	echo "Stopping monitoring (PID $$MONITOR_PID)..."; \
	kill $$MONITOR_PID; \
	echo "Monitoring stopped."; \
	kill $$PID

define RUN_GATEWAY
run-$(1):
	(cd ./gateways/$(1) && ./run.sh)
endef

$(foreach gateway,$(GATEWAY_IDS),$(eval $(call RUN_GATEWAY,$(gateway))))
