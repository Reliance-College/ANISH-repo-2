#!/usr/bin/env bash
# ==============================================================================
# Module: lib/monitor.sh
# Purpose: Real-time system resource monitoring, interval logging, & threshold alerts
# ==============================================================================

set -euo pipefail

# SCRIPT_DIR setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || pwd)"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  # Fallback logger/die functions if run standalone
  log_info() { printf "[INFO] %s\n" "$*"; }
  log_warn() { printf "[WARN] %s\n" "$*" >&2; }
  log_error() { printf "[ERROR] %s\n" "$*" >&2; }
  die() { log_error "$*"; exit 1; }
  require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }
fi

# Configurable defaults
CPU_WARN_PCT="${CPU_WARN_PCT:-80}"
MEM_WARN_PCT="${MEM_WARN_PCT:-80}"
DISK_WARN_PCT="${DISK_WARN_PCT:-80}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-5}" # Refresh interval in seconds
MONITOR_LOG="${MONITOR_LOG:-${SCRIPT_DIR}/system_monitor.log}"

# ------------------------------------------------------------------------------
# Metric Gathering Functions
# ------------------------------------------------------------------------------

get_cpu_usage() {
  require_cmd "top"
  # Extracts idle CPU percentage across platforms and subtracts from 100
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    local idle
    idle="$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print int($1)}')"
    echo "$(( 100 - idle ))"
  else
    echo "0"
  fi
}

get_mem_usage() {
  require_cmd "free"
  require_cmd "awk"
  free | awk '/Mem:/ {printf "%d", $3/$2 * 100}'
}

get_max_disk_usage() {
  require_cmd "df"
  require_cmd "awk"
  df -hP | awk 'NR>1 {print $5}' | tr -d '%' | sort -n | tail -1
}

# ------------------------------------------------------------------------------
# Monitoring Modes
# ------------------------------------------------------------------------------

monitor_snapshot() {
  local cpu mem disk
  cpu="$(get_cpu_usage)"
  mem="$(get_mem_usage)"
  disk="$(get_max_disk_usage)"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  # Format output
  printf "\n==================================================\n"
  printf "               SYSTEM MONITOR SNAPSHOT            \n"
  printf "               [%s]               \n" "$timestamp"
  printf "==================================================\n"
  printf " CPU Usage     : %3d%% (Threshold: %d%%)\n" "$cpu" "$CPU_WARN_PCT"
  printf " Memory Usage  : %3d%% (Threshold: %d%%)\n" "$mem" "$MEM_WARN_PCT"
  printf " Max Disk Usage: %3d%% (Threshold: %d%%)\n" "$disk" "$DISK_WARN_PCT"
  printf "--------------------------------------------------\n"

  # Alert checks
  (( cpu >= CPU_WARN_PCT )) && log_warn "HIGH CPU ALERT: ${cpu}% utilization!"
  (( mem >= MEM_WARN_PCT )) && log_warn "HIGH MEMORY ALERT: ${mem}% utilization!"
  (( disk >= DISK_WARN_PCT )) && log_warn "HIGH DISK ALERT: ${disk}% capacity!"

  # Append snapshot metrics to persistent log
  printf "[%s] CPU:%d%% MEM:%d%% DISK:%d%%\n" "$timestamp" "$cpu" "$mem" "$disk" >> "$MONITOR_LOG"
}

monitor_continuous() {
  local interval="${1:-$MONITOR_INTERVAL}"
  log_info "Starting live system monitoring (Interval: ${interval}s, Log: $MONITOR_LOG)..."
  log_info "Press [CTRL+C] to stop."

  trap 'log_info "Monitoring stopped by user."; exit 0' SIGINT SIGTERM

  while true; do
    clear 2>/dev/null || true
    monitor_snapshot
    sleep "$interval"
  done
}

# ------------------------------------------------------------------------------
# Entrypoint / CLI Dispatcher
# ------------------------------------------------------------------------------

show_monitor_usage() {
  cat << EOF
System Resource Monitor
Usage: ${0##*/} [OPTIONS] [COMMAND]

Options:
  -c <pct>  CPU threshold percentage (default: 80)
  -m <pct>  Memory threshold percentage (default: 80)
  -d <pct>  Disk threshold percentage (default: 80)
  -i <sec>  Continuous monitoring interval in seconds (default: 5)
  -h        Display this help message

Commands:
  once      Run a single system metric snapshot (default)
  watch     Run continuous live monitoring mode
EOF
}

monitor_main() {
  while getopts ":c:m:d:i:h" opt; do
    case "$opt" in
      c) CPU_WARN_PCT="$OPTARG" ;;
      m) MEM_WARN_PCT="$OPTARG" ;;
      d) DISK_WARN_PCT="$OPTARG" ;;
      i) MONITOR_INTERVAL="$OPTARG" ;;
      h) show_monitor_usage; exit 0 ;;
      \?) die "Invalid option: -$OPTARG" ;;
      :) die "Option -$OPTARG requires an argument." ;;
    esac
  done
  shift $((OPTIND - 1))

  local cmd="${1:-once}"
  case "$cmd" in
    once)
      monitor_snapshot
      ;;
    watch)
      monitor_continuous "$MONITOR_INTERVAL"
      ;;
    *)
      log_error "Unknown command: $cmd"
      show_monitor_usage
      exit 1
      ;;
  esac
}

# Execute if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  monitor_main "$@"
fi
EOF
