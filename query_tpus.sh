#!/bin/bash
# source query_tpus.sh v6e 16 2 (type, amount, number of tpus) (example)
# warning: edit all the TODOs in the script with your own local paths.

type=$1
amount=$2
ZONES=("us-east5-b" "us-central1-b" "asia-northeast1-b" "us-central2-b" "us-central1-a") # edit if need to constrain to certain zones

# Get region from zone
get_region() {
    echo "$1" | sed 's/-[a-z]$//'
}

# Get bucket service account for zone
get_bucket() {
    local zone=$1
    local region=$(get_region "$zone")

    # getting the correct bucket service account for read/write access
    case "$region" in
        "us-east5")
            echo "bucket-us-east5@he-vision-group.iam.gserviceaccount.com"
            ;;
        "asia-northeast1")
            echo "bucket-asia@he-vision-group.iam.gserviceaccount.com"
            ;;
        "us-central1")
            if [ "$zone" == "us-central1-a" ]; then
                echo "bucket-us-central1@he-vision-group.iam.gserviceaccount.com"
            else
                echo "bucket-us-central1@he-vision-group.iam.gserviceaccount.com"
            fi
            ;;
        "us-central2")
            echo "bucket-us-central2@he-vision-group.iam.gserviceaccount.com"
            ;;
        "us-west4")
            echo "bucket-us-west4@he-vision-group.iam.gserviceaccount.com"
            ;;
        *)
            echo "bucket-us-east5@he-vision-group.iam.gserviceaccount.com"
            ;;
    esac
}

# get TPU version for type
get_version() {
    case "$1" in
        "v5p")
            echo "v2-alpha-tpuv5"
            ;;
        "v6e")
            echo "v2-alpha-tpuv6e"
            ;;
        "v4")
            echo "tpu-ubuntu2204-base"
            ;;
    esac
}

# check if type is valid, amount is power of 2
if [ "$type" != "v5p" ] && [ "$type" != "v6e" ] && [ "$type" != "v4" ]; then
    echo "Type must be v5p, v6e, or v4"
    exit 1
fi

if [ "$amount" != "8" ] && [ "$amount" != "16" ] && [ "$amount" != "32" ] && [ "$amount" != "64" ] && [ "$amount" != "128" ]; then
    echo "Amount must be 8, 16, 32, 64, or 128"
    exit 1
fi

# function to create TPU in a zone
create_tpu_in_zone() {
    local zone=$1
    local type=$2
    local amount=$3
    local counter_dir=$4
    local max_tpus=$5

    local bucket=$(get_bucket "$zone")
    local version=$(get_version "$type")

    echo "Starting TPU creation in zone: $zone"

    while true; do
        # Check if we've hit the limit
        local count=$(ls "$counter_dir"/*.success 2>/dev/null | wc -l)
        if [ "$count" -ge "$max_tpus" ]; then
            echo "[$zone] Target of $max_tpus TPUs reached, stopping"
            exit 0
        fi

        local TIME=$(date +%d-%H-%M-%S-%N)
        local NAME="kmh-tpuvm-$type-$amount-spot-kristine-$TIME-$zone" # TODO: edit name 

        if gcloud compute tpus tpu-vm create "$NAME" \
            --zone="$zone" \
            --accelerator-type="$type-$amount" \
            --version="$version" \
            --spot \
            --service-account="$bucket" \
            --project=he-vision-group \
            --scopes='https://www.googleapis.com/auth/cloud-platform'
        then
            # success! Mark it
            local success_file="$counter_dir/$zone-$TIME.success"
            echo "$zone:$NAME" > "$success_file"

            local new_count=$(ls "$counter_dir"/*.success 2>/dev/null | wc -l)
            echo "[$zone] TPU $NAME created successfully! (Total: $new_count/$max_tpus)"

            # run remote initialization
            echo "[$zone] Running remote initialization on $NAME..."
            bash /Users/kristinelu/gcp_tooling/run_init_remote.sh "$NAME" "$zone" #TODO: edit path to your own remote init script.
            echo "[$zone] Remote initialization started in background"
            sleep 240 

            # Run mounting of data
            echo "[$zone] Running mounting of data on $NAME..." #IF MOUNTING DATA (1x bucket load, if enough space in TPU storage.)
            
            # Set FROM variable based on zone
            if [[ "$zone" == "asia-northeast1-b" ]]; then
                FROM="gs://kmh-gcp-asia-northeast1-b/laion_tar_jpg/"
                bash /Users/kristinelu/gcp_tooling/run_warmup_all_workers.sh "$NAME" "$zone" "$FROM" /mnt/klum/data &
                echo "[$zone] Remote mounting started in background"
            elif [[ "$zone" == "us-east5-b" ]]; then
                FROM="gs://kmh-gcp-us-east5/laion_tar_jpg/"
                bash /Users/kristinelu/gcp_tooling/run_warmup_all_workers.sh "$NAME" "$zone" "$FROM" /mnt/klum/data &
                echo "[$zone] Remote mounting started in background"
            else
                FROM=""
            fi



            # send notification
            curl -s -d "TPU $NAME in $zone ready ($new_count/$max_tpus total)" https://ntfy.sh/KMH-TPU-QUERIES #TODO: can comment out if no notify connected

            # check if we've reached the target
            if [ "$new_count" -ge "$max_tpus" ]; then
                echo "[$zone] Target of $max_tpus TPUs reached!"
                exit 0
            fi
        else
            # failed, retry
            echo "[$zone] TPU VM creation failed; retrying in 10s..." 1>&2
            sleep 10
        fi
    done
}

# Export function so it's available to subshells
export -f create_tpu_in_zone
export -f get_bucket
export -f get_region
export -f get_version

# Maximum number of TPUs to create (default 6)
MAX_TPUS=${3:-6}

# Create a temporary directory to track successes
COUNTER_DIR=$(mktemp -d)
trap "rm -rf $COUNTER_DIR" EXIT

echo "Target: Create $MAX_TPUS TPUs total"
echo "Launching TPU creation in ${#ZONES[@]} zones in parallel..."

# Launch TPU creation in all zones in parallel
for zone in "${ZONES[@]}"; do
    create_tpu_in_zone "$zone" "$type" "$amount" "$COUNTER_DIR" "$MAX_TPUS" &
done

# Wait for all background jobs to complete
echo "Waiting until $MAX_TPUS TPUs are created..."
wait

# Show final results
FINAL_COUNT=$(ls "$COUNTER_DIR"/*.success 2>/dev/null | wc -l)
echo ""
echo "============================================"
echo "SUCCESS: Created $FINAL_COUNT TPUs"
echo "============================================"
echo ""
echo "TPUs created:"
for success_file in "$COUNTER_DIR"/*.success; do
    if [ -f "$success_file" ]; then
        cat "$success_file"
    fi
done
