# Run job in a remote TPU VM

VM_NAME=$1
ZONE=$2

RUN_NAME=$3
MODEL_TYPE=$4

echo $VM_NAME $ZONE $RUN_NAME $MODEL_TYPE
 

CONFIG=imagenet_256_jit/cls_tok_32 #EDIT THIS TO CONFIG YOU WANT
CONFIGNAME=laion_t2i #EDIT THIS TO THE CHECKPOINT NAME U WANT

# Extract values from config file
# This loads the config and extracts specific values into shell variables
CONFIG_FILE="configs/${CONFIG}.py"
batch=1024
lr=0.0001
ep=1000
cls_tok=0 #TODO
 

WANDB_API_KEY=1 #TODO: add your own api key
WANDB_ENTITY='kaynelu921-massachusetts-institute-of-technology' #TODO: add your own entity
WANDB_PROJECT='klu_jit' #TODO: add your own project name

now=`date '+%Y%m%d_%H%M%S'`
#USE YOUR ORGANIZATION WITHOUT THE -org AT THE END
STAGEDIR=/kmh-nfs-ssd-us-mount/code/kristine/kristine-jit
export salt=`head /dev/urandom | tr -dc a-z0-9 | head -c6`
JOBNAME=dit_base/${now}_${salt}_${VM_NAME}_${CONFIGNAME}_${RUN_NAME}

CHECKPOINTDIR=/kmh-nfs-ssd-us-mount/logs/$USER/dit_base/checkpoints_${CONFIGNAME}/${RUN_NAME}
sudo mkdir -p ${CHECKPOINTDIR}
sudo chmod 777 ${CHECKPOINTDIR}

LOGDIR=/kmh-nfs-ssd-us-mount/logs/$USER/$JOBNAME
sudo mkdir -p ${LOGDIR}
sudo chmod 777 ${LOGDIR}

echo 'Log dir: '$LOGDIR

# Choose one random coordinator port ONCE so all workers share it.
COORD_IP=$(gcloud compute tpus tpu-vm describe "$VM_NAME" --zone "$ZONE" \
  --format='value(networkEndpoints[0].ipAddress)')
COORD_PORT=$(shuf -i 20000-65000 -n 1)
NUM_WORKERS=8

gcloud compute tpus tpu-vm ssh "$VM_NAME" --zone "$ZONE" --worker=all --command "
set -e
cd $STAGEDIR
cd /mnt/klum/data
echo 'LISTING DATA IN /mnt/klum/data'
ls -l
sudo sh -c 'echo always > /sys/kernel/mm/transparent_hugepage/enabled'
export JAX_PLATFORMS=tpu,cpu
export CUDA_VISIBLE_DEVICES=''
export TOKENIZERS_PARALLELISM='false'
export HF_HUB_ENABLE_HF_TRANSFER=1
python3 -m pip install gcsfs
export JAX_COORDINATOR_ADDRESS=${COORD_IP}:${COORD_PORT}
export JAX_PROCESS_COUNT=${NUM_WORKERS}
export TPU_MIN_LOG_LEVEL=2
export TF_CPP_MIN_LOG_LEVEL=2
export TPU_STDERR_LOG_LEVEL=2
sudo rm -f /tmp/libtpu_lockfile
pip uninstall -y protobuf
pip install 'protobuf>=5.28.0,<6.0.0'
pip install 'tensorflow==2.20.0'

# Per-worker index from hostname suffix (-0, -1, ...)
IDX=\$(hostname | sed -E 's/.*-([0-9]+)$/\1/')
if ! [[ \$IDX =~ ^[0-9]+$ ]]; then IDX=0; fi
export JAX_PROCESS_INDEX=\$IDX

# Verify (must print twice: same addr/count, different index)
echo \"[\$(hostname)] JAX_COORDINATOR_ADDRESS=\$JAX_COORDINATOR_ADDRESS\"
echo \"[\$(hostname)] JAX_PROCESS_COUNT=\$JAX_PROCESS_COUNT\"
echo \"[\$(hostname)] JAX_PROCESS_INDEX=\$JAX_PROCESS_INDEX\"

python3 -c 'import jax; print(jax.device_count())'
python3 -c 'import jaxlib; print(jaxlib.__version__)'


export CUDA_VISIBLE_DEVICES=""

# Ensure WANDB environment is set for the python process (expand locally, pass remotely)
# TMPDIR is already set above to a writable location
if [ -x ~/bin/mark_last_cmd.sh ]; then ~/bin/mark_last_cmd.sh \"remote_run: ${RUN_NAME} ${CONFIG}\"; fi
WANDB_API_KEY="${WANDB_API_KEY}" WANDB_ENTITY="${WANDB_ENTITY}" WANDB_PROJECT="${WANDB_PROJECT}" PYTHONUNBUFFERED=1 TMPDIR="\$TMPDIR" \

# command running job in remote TPU VM
python3 -u /kmh-nfs-ssd-us-mount/code/kristine/kristine-jit/main.py \
    --workdir=${LOGDIR} --config_file=/kmh-nfs-ssd-us-mount/code/kristine/kristine-jit/configs/${CONFIG}.py \
    --zone=${ZONE} \
    --checkpoint_dir=${CHECKPOINTDIR} \
    --mode=remote_run \
    --model_type=${MODEL_TYPE}

" 2>&1 | tee -a $LOGDIR/output.log
