#!/usr/bin/env bash
set -Eeuo pipefail

# Samples CPU, RSS, and PSS for an entire process group.
# Usage: ./memory.sh -g <pgid> [-o mem_cpu.csv] [-i 1]
#   -g PGID        Process group id to monitor (required)
#   -o OUTPUT      CSV file (default: mem_cpu.csv)
#   -i INTERVAL    Seconds between samples (default: 1)

PGID=""
OUTPUT_FILE="mem_cpu.csv"
INTERVAL="1"

while getopts ":g:o:i:" opt; do
  case "$opt" in
    g) PGID="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    i) INTERVAL="$OPTARG" ;;
    *) echo "Usage: $0 -g <pgid> [-o output.csv] [-i interval]"; exit 1 ;;
  esac
done

if [[ -z "$PGID" ]]; then
  echo "Usage: $0 -g <pgid> [-o output.csv] [-i interval]"
  exit 1
fi

echo "Timestamp,Total_CPU,Total_RSS_KB,Total_PSS_KB" > "$OUTPUT_FILE"
echo "Monitoring PGID $PGID. Writing to $OUTPUT_FILE. Ctrl+C to stop."

# Helper: list all PIDs in the process group
pids_in_group() {
  # pgrep -g lists processes in the group; may include the leader
  pgrep -g "$PGID" || true
}

sum_cpu_rss() {
  local pids="$1"
  # ps: sum %CPU and RSS across PIDs
  ps -o %cpu=,rss= -p "$(echo "$pids" | tr ' ' ',')" 2>/dev/null | awk '
    { cpu+=$1; rss+=$2 } END { printf("%.2f,%d\n", cpu, rss) }
  '
}

sum_pss_kb() {
  local total=0
  local pid
  while read -r pid; do
    [[ -z "$pid" ]] && continue
    # smaps_rollup provides aggregated Pss for the process in KB
    if [[ -r "/proc/$pid/smaps_rollup" ]]; then
      # shellcheck disable=SC2002
      val=$(awk '/^Pss:/{s+=$2} END{print s+0}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo 0)
      total=$(( total + ${val:-0} ))
    fi
  done <<< "$1"
  echo "$total"
}

while true; do
  PIDS="$(pids_in_group)"
  if [[ -z "$PIDS" ]]; then
    echo "Process group $PGID is empty. Stopping monitoring."
    break
  fi

  # CPU & RSS
  CPU_RSS="$(sum_cpu_rss "$PIDS" || echo "0,0")"
  CPU="$(echo "$CPU_RSS" | cut -d, -f1)"
  RSS_KB="$(echo "$CPU_RSS" | cut -d, -f2)"

  # PSS
  PSS_KB="$(sum_pss_kb "$PIDS")"

  TS="$(date +"%Y-%m-%d %H:%M:%S")"
  echo "$TS,$CPU,$RSS_KB,$PSS_KB" >> "$OUTPUT_FILE"

  sleep "$INTERVAL"
done
