#!/usr/bin/env bash
# comfyui-batch-setup.sh
# Run AFTER filling the ComfyUI queue in the browser.
# Stops GDM to free the AMD card, waits for the queue to drain, restarts GDM.
# Safe on this host: loginctl Linger=yes, so the --user comfyui service
# survives GDM/session teardown and keeps processing headless.

set -euo pipefail

API="http://127.0.0.1:8188"

# Query queue_remaining. Echoes an integer on success, or "ERR" on any
# curl/HTTP/JSON failure — the two are kept strictly distinct so a probe
# failure can never be misread as "queue empty".
queue_remaining() {
    local body
    if ! body=$(curl -sf --max-time 10 "$API/prompt" 2>/dev/null); then
        echo "ERR"; return
    fi
    printf '%s' "$body" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(int(d["exec_info"]["queue_remaining"]))
except Exception:
    print("ERR")
' 2>/dev/null || echo "ERR"
}

# --- Preflight: is the server reachable and does it have work? ---
pending=$(queue_remaining)

case "$pending" in
    ERR)
        echo "ERROR: could not read the ComfyUI queue at $API."
        echo "Is the service up? Try: systemctl --user status comfyui.service"
        echo "Aborting WITHOUT touching GDM."
        exit 1
        ;;
    0)
        echo "Queue is empty (0 remaining). Fill the ComfyUI queue first, then rerun."
        echo "Aborting WITHOUT touching GDM."
        exit 1
        ;;
    *)
        echo "Queue has work ($pending remaining). Stopping GDM in 5s — Ctrl-C to cancel."
        sleep 5
        ;;
esac

# --- Tear down the desktop to free the card ---
sudo systemctl stop gdm
echo "GDM stopped. Draining queue (ComfyUI continues headless)..."

# --- Wait for drain. On a transient probe error mid-run, DO NOT assume done;
#     keep waiting and report, so we never restart GDM early or loop forever silently. ---
stall=0
while true; do
    sleep 30
    remaining=$(queue_remaining)
    if [[ "$remaining" == "ERR" ]]; then
        stall=$((stall + 1))
        echo "  (warning: queue probe failed, attempt $stall — still waiting, GDM stays down)"
        # After ~10 min of continuous probe failure, surface it but keep GDM down
        # rather than guessing the batch finished.
        if (( stall >= 20 )); then
            echo "  Probe has failed for ~10 min. Leaving GDM stopped and exiting the waiter."
            echo "  Check the service manually, then run: sudo systemctl start gdm"
            exit 2
        fi
        continue
    fi
    stall=0
    echo "  remaining: $remaining"
    [[ "$remaining" == "0" ]] && break
done

echo "Queue drained. Restarting GDM."
sudo systemctl start gdm
echo "Done. Desktop restored."