#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if a gateway name was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <gateway_name>"
  exit 1
fi

GATEWAY_NAME=$1
GATEWAY_DIR="./gateways/$GATEWAY_NAME"

# Check if the gateway directory exists
if [ ! -d "$GATEWAY_DIR" ]; then
  echo "Error: Gateway '$GATEWAY_NAME' not found at '$GATEWAY_DIR'."
  exit 1
fi

# Change to the gateway's directory
cd "$GATEWAY_DIR"

echo "Starting gateway: $GATEWAY_NAME..."
./run.sh > /dev/null 2>&1 &
GATEWAY_PID=$!

# Give the process a moment to start
sleep 1

# Check if the gateway process started successfully
if ! ps -p $GATEWAY_PID > /dev/null; then
    echo "Error: Failed to start gateway or gateway exited prematurely."
    exit 1
fi

echo "Gateway '$GATEWAY_NAME' started with PID $GATEWAY_PID."

# Define cleanup function to ensure processes are killed on exit
cleanup() {
  echo "\nCleaning up..."
  # Kill monitor process
  if ps -p $MONITOR_PID > /dev/null; then
    echo "Stopping monitoring (PID $MONITOR_PID)..."
    kill $MONITOR_PID
    echo "Monitoring stopped."
  fi
  # Kill gateway process
  if ps -p $GATEWAY_PID > /dev/null; then
    echo "Stopping gateway (PID $GATEWAY_PID)..."
    kill $GATEWAY_PID
    kill -9 $(lsof -t -i:4000)
    echo "Gateway stopped."
  fi
}

# Trap script exit, error or interrupt signals to run cleanup
trap cleanup EXIT ERR INT

echo "Starting monitoring (PID $GATEWAY_PID)..."
../../monitor.sh $GATEWAY_PID mem_cpu.csv > /dev/null 2>&1 &
MONITOR_PID=$!
echo "Monitoring started with PID $MONITOR_PID."

echo "Running k6 load test..."
k6 run -e SUMMARY_PATH=$(pwd) ../../k6.js
echo "k6 load test finished."

echo "Summary:"
cargo run -p toolkit report $(pwd)

echo "Test for gateway '$GATEWAY_NAME' completed successfully."
