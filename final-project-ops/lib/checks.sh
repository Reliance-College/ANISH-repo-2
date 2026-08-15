#!/bin/bash

check_disk() {
    local target="$1"

    local usage

    usage=$(run_on "$target" \
        bash -c "df -P / | awk 'NR==2 {gsub(/%/,\"\",\$5); print \$5}'")

    if [[ -z "$usage" ]]; then
        echo "UNKNOWN"
        return 1
    fi

    if (( usage >= DISK_THRESHOLD )); then
        echo "WARNING: Disk usage ${usage}%"
        return 1
    fi

    echo "OK: Disk usage ${usage}%"
    return 0
}

check_memory() {
    local target="$1"

    local usage

    usage=$(run_on "$target" \
        bash -c "free | awk '/Mem:/ {printf \"%.0f\", \$3/\$2*100}'")

    if [[ -z "$usage" ]]; then
        echo "UNKNOWN"
        return 1
    fi

    if (( usage >= MEMORY_THRESHOLD )); then
        echo "WARNING: Memory usage ${usage}%"
        return 1
    fi

    echo "OK: Memory usage ${usage}%"
    return 0
}

check_load() {
    local target="$1"

    local load

    load=$(run_on "$target" \
        bash -c "awk '{print \$1}' /proc/loadavg")

    if [[ -z "$load" ]]; then
        echo "UNKNOWN"
        return 1
    fi

    local warning

    warning=$(awk -v l="$load" -v t="$LOAD_THRESHOLD" \
        'BEGIN { if (l >= t) print 1; else print 0 }')

    if [[ "$warning" == "1" ]]; then
        echo "WARNING: Load ${load}"
        return 1
    fi

    echo "OK: Load ${load}"
    return 0
}

check_service() {
    local target="$1"
    local service="$2"

    if run_on "$target" systemctl is-active --quiet "$service"; then
        echo "OK: $service is running"
        return 0
    fi

    echo "WARNING: $service is not running"
    return 1
}

check_reachability() {
    local target="$1"

    if [[ "$target" == "localhost" || "$target" == "127.0.0.1" ]]; then
        echo "OK: Local host reachable"
        return 0
    fi

    if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
        echo "OK: Host reachable"
        return 0
    fi

    echo "WARNING: Host unreachable"
    return 1
}

check_endpoint() {
    local endpoint="$1"

    if check_http "$endpoint"; then
        echo "OK: HTTP $endpoint"
        return 0
    fi

    echo "WARNING: HTTP failed $endpoint"
    return 1
}
