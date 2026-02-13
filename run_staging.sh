# Stage code and run job in a remote TPU VM

# ------------------------------------------------
# Copy all code files to staging
# ------------------------------------------------
now=`date '+%y%m%d%H%M%S'`
salt=`head /dev/urandom | tr -dc a-z0-9 | head -c6`
commitid=`git show -s --format=%h`  # latest commit id; may not be exactly the same as the commit
STAGEDIR=/kmh-nfs-ssd-us-mount/staging/$USER/dit_base/${now}_${salt}_${commitid}
sudo mkdir -p ${STAGEDIR}
sudo chmod 777 ${STAGEDIR}
export STAGEDIR=/kmh-nfs-ssd-us-mount/staging/$USER/dit_base/${now}_${salt}_${commitid}
echo 'Staging files...'
# Avoid preserving owner/group/perms/times on NFS to prevent chgrp/chown/utimes errors
sudo rsync -rlD --no-owner --no-group --no-perms --omit-dir-times . $STAGEDIR --exclude=tmp --exclude=.git --exclude=__pycache__
echo 'Done staging.'
sudo sh -c "echo always > /sys/kernel/mm/transparent_hugepage/enabled"
cd $STAGEDIR
echo 'Current dir: '`pwd`
# ------------------------------------------------

sleep 5
source run_remote.sh $1 $2 $3 $4