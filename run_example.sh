VM_NAME=$1
ZONE=$2
CHECKPOINT_DIR=$3
MODEL_TYPE=$4

gcloud compute tpus tpu-vm ssh "$VM_NAME" --zone "$ZONE" --worker=all --command "
if [ -x ~/bin/mark_last_cmd.sh ]; then ~/bin/mark_last_cmd.sh \"sample_eval: ${CHECKPOINT_DIR} ${MODEL_TYPE}\"; fi
python3 -u /kmh-nfs-ssd-us-mount/code/kristine/kristine-jit/sample_debug.py \
    --checkpoint_dir=${CHECKPOINT_DIR} \
    --zone=${ZONE} \
    --model_type=${MODEL_TYPE}
"
