#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: ./test.sh <gateway_name>
# Optional env:
#   GATEWAY_CPUSET="0-2"   # CPU cores for the gateway
#   LOAD_CPUSET="3"        # CPU cores for k6
#   WAIT_FOR_URL="http://127.0.0.1:4000/health"  # healthcheck URL
#   WARMUP_SECONDS=30
#   MEASURE_SECONDS=60

command -v realpath >/dev/null || { echo "realpath required"; exit 1; }
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

get_logical_cores() {
  if command -v nproc >/dev/null 2>&1; then
    nproc                    # respects cgroups/cpuset if applicable
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    sysctl -n hw.logicalcpu
  else
    grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1
  fi
}

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <gateway_name>"
  exit 1
fi

GATEWAY_NAME="$1"
GATEWAY_DIR="$SCRIPT_DIR/gateways/$GATEWAY_NAME"
[[ -d "$GATEWAY_DIR" ]] || { echo "Error: Gateway '$GATEWAY_NAME' not found at '$GATEWAY_DIR'."; exit 1; }
[[ -x "$GATEWAY_DIR/run.sh" ]] || { echo "Error: '$GATEWAY_DIR/run.sh' missing or not executable. It should 'exec' the binary."; exit 1; }

# Defaults
WARMUP_SECONDS="${WARMUP_SECONDS:-30}"
MEASURE_SECONDS="${MEASURE_SECONDS:-60}"

CORES="$(get_logical_cores)"
echo "Host logical CPU cores: $CORES"
[[ -n "${GATEWAY_CPUSET:-}" ]] && echo "Gateway pinned to CPU set: $GATEWAY_CPUSET"
[[ -n "${LOAD_CPUSET:-}"    ]] && echo "Load gen pinned to CPU set: $LOAD_CPUSET"

maybe_taskset() {
  local cpus="$1"; shift
  if [[ -n "${cpus:-}" ]] && command -v taskset >/dev/null; then
    taskset -c "$cpus" "$@"
  else
    [[ -n "${cpus:-}" ]] && echo "WARN: taskset not found; cannot pin to CPUs: $cpus" >&2
    "$@"
  fi
}

set_affinity_group() {
  local pgid="$1" cpus="$2"
  [[ -z "${cpus:-}" ]] && return 0
  command -v taskset >/dev/null || { echo "WARN: taskset not found; skipping gateway pinning" >&2; return 0; }
  local pids
  pids="$(pgrep -g "$pgid" || true)"
  [[ -z "$pids" ]] && return 0
  while read -r pid; do
    [[ -z "$pid" ]] && continue
    taskset -pc "$cpus" "$pid" >/dev/null 2>&1 || true
  done <<< "$pids"
}

cd "$GATEWAY_DIR"

echo "Starting gateway: $GATEWAY_NAME ..."
# New session/process group; run.sh must 'exec' the real binary
setsid taskset -c "${GATEWAY_CPUSET:-2}" ./run.sh >/dev/null 2>&1 &
GATEWAY_LEADER_PID=$!
sleep 0.3

# Get the process group ID (equals leader PID when setsid worked)
GATEWAY_PGID="$(ps -o pgid= -p "$GATEWAY_LEADER_PID" | tr -d ' ')"
[[ -n "$GATEWAY_PGID" ]] || { echo "Error: failed to determine PGID."; exit 1; }

# (Optional) pin gateway group to dedicated cores
set_affinity_group "$GATEWAY_PGID" "${GATEWAY_CPUSET:-}"

# Readiness check (optional)
if [[ -n "${WAIT_FOR_URL:-}" ]]; then
  echo "Waiting for readiness at $WAIT_FOR_URL ..."
  for _ in {1..60}; do
    if curl -fsS --max-time 1 "$WAIT_FOR_URL" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
fi

echo "Gateway PGID: $GATEWAY_PGID"

# Cleanup handler kills entire process group
cleanup() {
  echo ""
  echo "Cleaning up ..."
  if ps -o pgid= -p "$GATEWAY_LEADER_PID" >/dev/null 2>&1; then
    echo "Stopping gateway group (-$GATEWAY_PGID) ..."
    kill -TERM "-$GATEWAY_PGID" >/dev/null 2>&1 || true
    sleep 2
    kill -KILL "-$GATEWAY_PGID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${MONITOR_PID:-}" ]] && ps -p "$MONITOR_PID" >/dev/null 2>&1; then
    echo "Stopping monitor (PID $MONITOR_PID) ..."
    kill "$MONITOR_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

# Start monitor for the whole PGID, pass cores so it writes metadata into CSV
echo "Starting monitoring for PGID $GATEWAY_PGID ..."
"$SCRIPT_DIR/monitor.sh" -g "$GATEWAY_PGID" -o mem_cpu.csv -i 1 >/dev/null 2>&1 &
MONITOR_PID=$!
echo "Monitoring started (PID $MONITOR_PID)."

# Warmup
echo "Warmup ($WARMUP_SECONDS s) ..."
maybe_taskset "${LOAD_CPUSET:-}" k6 run -e SUMMARY_PATH="$(pwd)" \
  -e PHASE="warmup" -e DURATION="$WARMUP_SECONDS" "$SCRIPT_DIR/k6.js" >/dev/null

# Measure
echo "Load test ($MEASURE_SECONDS s) ..."
maybe_taskset "${LOAD_CPUSET:-}" k6 run -e SUMMARY_PATH="$(pwd)" \
  -e PHASE="measure" -e DURATION="$MEASURE_SECONDS" "$SCRIPT_DIR/k6.js"

echo "Summary:"
cargo run -p toolkit report "$(pwd)"

echo "Test for gateway '$GATEWAY_NAME' completed successfully."
