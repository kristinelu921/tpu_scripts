# query 1 tpu (make sure zone matches service-account)


until gcloud compute tpus tpu-vm create kmh-tpuvm-v6e-8-spot-kristine1 \
--zone=asia-northeast1-b \
--accelerator-type=v6e-8 \
--version=v2-alpha-tpuv6e \
--spot \
--scopes='https://www.googleapis.com/auth/cloud-platform' \
--service-account=bucket-asia@he-vision-group.iam.gserviceaccount.com \
--project=he-vision-group

do
echo "TPU VM creation failed; retrying in 60s..." 1>&2
#sleep 30; date '+%Y-%m-%d %H:%M:%S %Z'
sleep 10; date '+%Y-%m-%d %H:%M:%S %Z'

done

gcloud compute tpus tpu-vm ssh kmh-tpuvm-v6e-8-spot-kristine1 \
--zone=asia-northeast1-b \
--worker=all \
--command="mkdir -p ~/.ssh && echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCyZcxuyIci22S6FDwH9XaoEM/IMZKKJKV6I9snkQaz57dZ1aweFQPyce2MOSN6wFdMDm2CtmYpdyPG+E/zt9mdj2WdDDOloq2n0fKWhoSOURaqS9W6zevtnlv+pP/dojSk6l7qzQ7sLA4j+zlrG0WksK/im8FpdA+IDFYGsQoLdM5psroTVcYi9bLU5/cdoSrSPAz3WHF+I8sgHeoOoXKQFbl/GYWaiYpaH5yUT1/MaqTkbas2YFD6XkqgM3zYy5VNAlBOo0Jtsgo5WpQLPtxDPLPe+do4EmPm0A+KhBAREKxRX+MCMthevzrWxVjX0qjoqnCtOrRNRTRx/iSiwH4ACLJB0lJfEBavEbdbUvHK4YaDj0zY1Veq2eJfAkcFH6UtWfaPB9BMM0PMletou9TdaPdGjZUojSV5n52b75/+GYCNA1yXTPZ8LUI52oiY8UoGHAwopFiK0DzTyT+YdVaJM2g/oLHsZ1t35SB/3ZjoSDxpENGytRpAusFn14q73m8= kristinelu@dhcp-10-29-156-131.dyn.mit.edu' >> ~/.ssh/authorized_keys"


#TODO: can comment out if no notify connected
curl -d "TPU kmh-tpuvm-v6e-8-spot-kristine1 asia ready" https://ntfy.sh/KMH-TPU-QUERIES

