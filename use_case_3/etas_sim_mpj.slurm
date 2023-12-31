#!/bin/bash

#SBATCH -t 3:00:00
#SBATCH --nodes 14
#SBATCH -n 1792
#SBATCH --mem=249325M
#SBATCH --partition compute
#SBATCH --account=ddp408

######################
## INPUT PARAMETERS ##
######################

# the above '#SBATCH' lines are requred, and are supposed to start with a '#'. They must be at the beginning of the file
# the '-t hh:mm:ss' argument is the wall clock time of the job
# the '-N 18' argument specifies the number of nodes required, in this case 18
# the '--cpus-per-task=20' argument specifies that we need access to all 20 cores on each node
# the 'p scec' argument specifies the queue, this line can be removed if you want the default queue (e.g., on discovery instead of endeavour)
# the '--mem 0' argument specifies that we want access to all available memory on the compute nodes

## ETAS PARAMETERS ##

# path to the JSON configuration file
ETAS_CONF_JSON="${ETAS_SIM_DIR}/scenario_3/config.json"

## JAVA/MPJ PARAMETERS ##

# maxmimum memory in gigabytes. should be close to, but not over, total memory available
MEM_GIGS=200

# number of etas threads. should be approximately MEM_GIGS/5, and no more than the total number of threads available
THREADS=20

# MPJ_HOME directory. on USC CARC, it's fine to just use mine
# you can also fetch this directory via Git by cloning https://github.com/kevinmilner/mpj-express.git
MPJ_HOME=/expanse/lustre/projects/ddp408/flsilva/mpj-express

# path to the opensha-ucerf3 jar file
JAR_FILE=${ETAS_LAUNCHER}/opensha/opensha-all.jar

# simulations are sent out in batches to each compute node. these paramters control the size of those batches
# smaller max size will allow for better checking of progress with watch_logparse.sh, but more wasted time at the end of batches waiting on a single calculation to finish
MIN_DISPATCH=$THREADS
MAX_DISPATCH=100

# this allows for catalogs to be written locally on each compute node in a temporary directory, then only copied back onto shared storage after they complete. this reduces I/O load, but makes it harder to track progress of individual simulations. comment this out to disable this option
TEMP_OPTION="--temp-dir $TMPDIR"

# this allows for catalogs to be written to temporary scratch storage and symbolically linked back. only final consolidated binary files will be written to the primary output directory
#SCRATCH_OPTION="--scratch-dir /scratch2/$USER/etas_scratch"

# this automatically deletes subdirectories of the results directory once a catalog has been sucessfully written to the master binary file. comment out to disable
CLEAN_OPTION="--clean"

##########################
## END INPUT PARAMETERS ##
##   DO NOT EDIT BELOW  ##
##########################

NEW_JAR="`dirname ${ETAS_CONF_JSON}`/`basename $JAR_FILE`"
cp $JAR_FILE $NEW_JAR
if [[ -e $NEW_JAR ]];then
	JAR_FILE=$NEW_JAR
fi

PBS_NODEFILE="/tmp/${USER}-hostfile-${SLURM_JOBID}"
echo "creating PBS_NODEFILE: $PBS_NODEFILE"
scontrol show hostnames $SLURM_NODELIST > $PBS_NODEFILE

export MPJ_HOME=$MPJ_HOME
export PATH=$PATH:$MPJ_HOME/bin

date
echo "RUNNING MPJ"
mpjrun_errdetect_wrapper.sh $PBS_NODEFILE -dev hybdev -Djava.library.path=$MPJ_HOME/lib -Xmx${MEM_GIGS}G -cp $JAR_FILE scratch.UCERF3.erf.ETAS.launcher.MPJ_ETAS_Launcher --min-dispatch $MIN_DISPATCH --max-dispatch $MAX_DISPATCH --threads $THREADS $TEMP_OPTION $SCRATCH_OPTION $CLEAN_OPTION --end-time `scontrol show job $SLURM_JOB_ID | egrep --only-matching 'EndTime=[^ ]+' | cut -c 9-` $ETAS_CONF_JSON
ret=$?
date

java -Djava.awt.headless=true -Xmx${MEM_GIGS}G -cp $JAR_FILE scratch.UCERF3.erf.ETAS.analysis.SimulationMarkdownGenerator --threads $THREADS $NO_MAPS_OPTION $FORCE_UPDATE_OPTION $COMCAT_OPTION $ETAS_CONF_JSON

exit $ret
