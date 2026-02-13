# tpu_scripts

## GCP TPU scripts guide:


## IMPORTANT: only load bucket -> VM within the same region. (esp important for dev machines)
for this repo, all tools have the zone required in script to ensure.

**query_tpu_6_8_asia_2.sh** : query one tpu (adjust the paramemters, make sure bucket = service account name)
**query_tpus.sh** and **run_kill_tpu_queries.sh** : query x tpu's of a certain kind and amount in parallel (sets off parallel jobs, so to kill the query_tpus.sh command, run run_kill_tpu_queries.sh) ++ also uses notify for phone, can comment out if necessary
**run_init_remote.sh** initialize a new tpu with the mount + necessary packages for job -- can also replace hard-code inits with path to a requirements.txt file, need manual fix
**run_kill_remote.sh** kills all the processes on an existing TPU (note: may be slow for the one-to-one. Also, processes may exist for ~20 minutes after you kill them, best to check back in a bit)
**run_remote.sh, run_staging.sh** these should be run inside the mount SSH, adds your current codebase to a {yourname}/log folder so you have a snapshot of exact code used for this run(for reproducibility). most jobs should be kicked off with run_staging.sh *args

**run_warmup.sh** and **run_warmup_all_workers.sh**: this is for loading from a bucket to a TPU machine. use fallocate to rewrite data allocation metadata, load data onto a mount to a specific path, so don't deal with bucket -> VM bottleneck loading.

**run_example.sh** is just an example, for any task, using gcloud + all workers. for most tasks on remote tpu, can use a remote script based on run_example.



will update with further tooling as is built