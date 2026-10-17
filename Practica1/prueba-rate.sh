#!/usr/bin/env bash

cantidad="${1:-30}"
pausa="${2:-0}"

for ((i=1; i<=cantidad; i++)); do
    codigo=$(curl -k -sS -o /dev/null -w '%{http_code}' \
        --resolve patchesmerch.local:443:127.0.0.1 \
        https://patchesmerch.local/)

    printf '%02d %s\n' "$i" "$codigo"

    if [[ "$pausa" != "0" && "$i" -lt "$cantidad" ]]; then
        sleep "$pausa"
    fi
done
