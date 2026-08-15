#!/bin/bash

run_report() {
    local hosts_file="$1"

    if [[ ! -f "$hosts_file" ]]; then
        log "ERROR" "Hosts file not found: $hosts_file"
        return 1
    fi

    log "INFO" "Starting monitoring report."

    while IFS='|' read -r name target services endpoints; do

        [[ -z "$name" ]] && continue
        [[ "$name" == \#* ]] && continue

        echo
        echo "======================================"
        echo "Host: $name"
        echo "Target: $target"
        echo "======================================"

        local failed=0

        echo
        echo "[Reachability]"
        if ! check_reachability "$target"; then
            failed=1
        fi

        echo
        echo "[Disk]"
        if ! check_disk "$target"; then
            failed=1
        fi

        echo
        echo "[Memory]"
        if ! check_memory "$target"; then
            failed=1
        fi

        echo
        echo "[Load]"
        if ! check_load "$target"; then
            failed=1
        fi

        if [[ -n "$services" ]]; then
            echo
            echo "[Services]"

            IFS=',' read -ra service_list <<< "$services"

            for service in "${service_list[@]}"; do
                if ! check_service "$target" "$service"; then
                    failed=1
                fi
            done
        fi

        if [[ -n "$endpoints" ]]; then
            echo
            echo "[HTTP Endpoints]"

            IFS=',' read -ra endpoint_list <<< "$endpoints"

            for endpoint in "${endpoint_list[@]}"; do
                if ! check_endpoint "$endpoint"; then
                    failed=1
                fi
            done
        fi

        if (( failed == 0 )); then
            log "INFO" "$name: All checks passed."
        else
            log "WARN" "$name: One or more checks failed."
            notify "Monitoring alert: $name has one or more failed checks."
        fi

    done < "$hosts_file"

    log "INFO" "Monitoring report completed."
}
