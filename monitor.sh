#!/bin/bash

# Check if a PID was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <PID> [output_file]"
  exit 1
fi

PID=$1
OUTPUT_FILE=${2:-"mem_cpu.csv"}

echo "Timestamp,Total_CPU,Total_Memory_KB" > "$OUTPUT_FILE"
echo "Monitoring PID $PID and its children. Logging to $OUTPUT_FILE. Press Ctrl+C to stop."

# Check if the main process exists before starting the loop
if ! ps -p "$PID" > /dev/null; then
    echo "Error: Process with PID $PID not found."
    exit 1
fi

while ps -p "$PID" > /dev/null; do
  # Find all child PIDs of the main process
  CHILD_PIDS=$(pgrep -P "$PID")

  # Combine the main PID and all child PIDs into a comma-separated list
  ALL_PIDS="$PID"
  if [ -n "$CHILD_PIDS" ]; then
    # pgrep output can be multi-line, so we convert it to a comma-separated list
    ALL_PIDS="$PID,$(echo $CHILD_PIDS | tr ' ' ',')"
  fi

  # Get stats for all PIDs and sum them up
  # ps output has a header, so we use tail -n +2 to skip it before summing
  SUMMED_STATS=$(ps -o %cpu,rss -p "$ALL_PIDS" --no-headers | awk '
    {
      cpu_sum += $1;
      mem_sum += $2
    }
    END {
      print cpu_sum "," mem_sum
    }
  ')

  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

  echo "$TIMESTAMP,$SUMMED_STATS" >> "$OUTPUT_FILE"

  sleep 1 # Sample every 1 second
done

echo "Main process with PID $PID has finished. Stopping monitoring."
