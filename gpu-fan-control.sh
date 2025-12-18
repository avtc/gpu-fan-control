#!/bin/bash

# Setup X authority
XAUTH_FILE=$(ps aux | grep -m1 "X.*-auth" | sed -n 's/.*-auth \([^ ]*\).*/\1/p')
if [ -z "$XAUTH_FILE" ]; then
    echo "ERROR: Could not find X authority file." >&2
    exit 1
fi
export DISPLAY=:0
export XAUTHORITY="$XAUTH_FILE"

# --- Step 1: Build GPU → fan mapping using --verbose output ---
declare -A gpu_to_fans

current_gpu=""
while IFS= read -r line; do
    if [[ "$line" =~ \[gpu:([0-9]+)\] ]]; then
        current_gpu="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \[fan:([0-9]+)\] ]]; then
        fan="${BASH_REMATCH[1]}"
        if [[ -n "$current_gpu" ]]; then
            gpu_to_fans["$current_gpu"]+="$fan "
        fi
    fi
done < <(nvidia-settings -c :0 -q gpus --verbose)

# --- Step 2: Enable manual fan control ---
for gpu in "${!gpu_to_fans[@]}"; do
    nvidia-settings -a "[gpu:$gpu]/GPUFanControlState=1" > /dev/null
done

# --- Step 3: Fan curve loop ---
declare -A last_speed

while true; do
    for gpu in "${!gpu_to_fans[@]}"; do
        temp=$(nvidia-settings -q "[gpu:$gpu]/GPUCoreTemp" -t)

        # Fan curve
        if (( temp < 35 )); then
            speed=20
        elif (( temp < 40 )); then
            speed=30
        elif (( temp < 50 )); then
            speed=40
        elif (( temp < 60 )); then
            speed=50
        elif (( temp < 65 )); then
            speed=60
        elif (( temp < 70 )); then
            speed=70
        elif (( temp < 80 )); then
            speed=75
        elif (( temp < 90 )); then
            speed=80
        else
            speed=90
        fi

        if [[ "${last_speed[$gpu]}" == "$speed" ]]; then
            continue
        fi

        # Set fan speed for all associated fans
        for fan in ${gpu_to_fans[$gpu]}; do
            nvidia-settings -a "[fan:$fan]/GPUTargetFanSpeed=$speed" > /dev/null
        done

        last_speed[$gpu]=$speed
    done

    sleep 5
done
