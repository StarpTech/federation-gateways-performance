#!/bin/bash

# Check if a PID was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <PID>"
  exit 1
fi

PID=$1
OUTPUT_FILE="mem_cpu.csv"

echo "Timestamp,%CPU,Memory(KB)" > "$OUTPUT_FILE"
echo "Monitoring PID $PID. Logging to $OUTPUT_FILE. Press Ctrl+C to stop."

# Check if the process exists before starting the loop
if ! ps -p "$PID" > /dev/null; then
    echo "Error: Process with PID $PID not found."
    exit 1
fi

while ps -p "$PID" > /dev/null; do
  STATS=$(ps -o %cpu,rss -p "$PID" | tail -n 1)
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$TIMESTAMP,$STATS" | tr -s ' ' >> "$OUTPUT_FILE"
  sleep 1 # Sample every 1 second
done
