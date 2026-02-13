#!/bin/bash

echo "Searching for running TPU query processes with 'kristine'..."

# Find all gcloud TPU creation processes that contain 'kristine'
echo ""
echo "Found these processes (with 'kristine'):"
ps aux | grep -E "gcloud.*compute tpus tpu-vm create|create_tpu_in_zone|query_tpu" | grep -i kristine | grep -v grep

echo ""
echo "Killing gcloud TPU creation processes with 'kristine'..."
pkill -9 -f "gcloud.*compute tpus tpu-vm create.*kristine"

echo ""
echo "Killing any background create_tpu_in_zone processes with 'kristine'..."
pkill -9 -f "create_tpu_in_zone.*kristine"

# Also kill any bash processes running query_tpu.sh (these should have kristine in the command line)
echo ""
echo "Killing any query_tpu.sh processes (should have kristine)..."
# Get PIDs of processes matching query_tpu that also have kristine in their full command line
ps aux | grep -E "query_tpu|bash.*query_tpu" | grep -i kristine | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

echo ""
echo "Done! All TPU query processes with 'kristine' should be killed."
echo ""
echo "Verifying (should show nothing):"
ps aux | grep -E "gcloud.*compute tpus tpu-vm create|query_tpu" | grep -i kristine | grep -v grep || echo "✓ All kristine processes killed successfully"
