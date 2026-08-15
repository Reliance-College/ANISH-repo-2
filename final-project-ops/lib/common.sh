#!/bin/bash

load_config() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Configuration file not found: $file"
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$file"
}

log() {
    local level="$1"
    shift

    local message="$*"
    local timestamp

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message"

    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

notify() {
    local message="$1"

    if [[ -z "${WEBHOOK_URL:-}" ]]; then
        return 0
    fi

    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"$message\"}" \
        "$WEBHOOK_URL" >/dev/null 2>&1
}

run_on() {
    local target="$1"
    shift

    if [[ "$target" == "localhost" || "$target" == "127.0.0.1" ]]; then
        "$@"
    else
        ssh -o ConnectTimeout=5 "$target" "$@"
    fi
}

retry() {
    local attempts="${RETRY_COUNT:-3}"
    local delay="${RETRY_DELAY:-2}"
    local count=1

    while (( count <= attempts )); do
        "$@" && return 0

        log "WARN" "Attempt $count failed."

        if (( count < attempts )); then
            sleep "$delay"
        fi

        ((count++))
    done

    return 1
}

check_port() {
    local host="$1"
    local port="$2"

    timeout 5 bash -c \
        "</dev/tcp/$host/$port" \
        >/dev/null 2>&1
}

check_http() {
    local url="$1"

    curl -fsS \
        --max-time "${HTTP_TIMEOUT:-5}" \
        "$url" >/dev/null 2>&1
}

acquire_lock() {
    local lock_file="$1"

    if [[ -e "$lock_file" ]]; then
        log "ERROR" "Another monitoring process is running."
        exit 1
    fi

    echo "$$" > "$lock_file"
}

release_lock() {
    local lock_file="$1"

    rm -f "$lock_file"
}
