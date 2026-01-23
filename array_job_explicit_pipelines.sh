#!/bin/bash
#SBATCH --job-name=pmbb_pipes

# Pass in array at command line due to limits on numbers of tasks per job
#module load dcmtk 2> /dev/null
#module load c3d 2> /dev/null
#dcmtk=/cbica/projects/pmbb-vision/pkg/dcmtk-3.6.8-linux-x86_64-static/bin

logger () {
  d=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$d array_job_explicit_pipelines SLURM=${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID} $1 $2"
}

usage() { echo "Usage: $0 [-q -h]"; exit 1; }


ibase=""
obase=""
index=0
runppe=0
env=""
force=0

while getopts d:i:o:p:e:f:qh flag
do
  case "${flag}" in
     q) query=1;;
     h) usage;;
     i) index=$OPTARG;;
     e) env=$OPTARG;;
     f) force=$OPTARG;;
  esac
done

#index=$1
#env=$2


start_date=$(date '+%Y-%m-%d %H:%M:%S')
start_time=$(date +%s)

#echo "SLURM_JOB_ID: $SLURM_JOB_ID"
logger "INFO" "Prepping for pmbb pipelines"

if [ ! -e "$index" ]; then
    logger "ERROR" "Index file not found: $index"
    exit 1
fi

# Need to use offset to allow for index with more than 30k lines (job submit limit)
offset=$SLURM_ARRAY_TASK_ID
#echo "Found offset of ${SLURM_ARRAY_TASK_ID_OFFSET}"
if [ -n "${SLURM_ARRAY_TASK_ID_OFFSET}" ]; then
  #echo "Using offset of ${SLURM_ARRAY_TASK_ID_OFFSET}"
  offset=$((${SLURM_ARRAY_TASK_ID}+${SLURM_ARRAY_TASK_ID_OFFSET}))
fi 

# Index file should look like
# Index,Input,Output,Package,Module,Parameters
# 1,/full/path/to/input_image1.nii.gz,/full/path/to/output_file.ext,package,module,--ml --fast
# 2,/full/path/to/input_image2.nii.gz,/full/path/to/output_file2.ext,package,module,--ml --fast
#
#

cat="cat $index"
if [ "$index" == "*.parquet" ]; then
  cat="parquet-tools csv $index"
fi



# Get the relevant entries from the index file
infile=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $2}')
outfile=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $3}')
package=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $4}')
module=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $5}')
opts=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $6}')

if [ "${opts}" == "NA" ]; then
  opts=""
fi

# Does input exist
if [ ! -e ${infile} ]; then
  logger "INFO" "${infile} does not exist. Exiting"
  exit 1
fi

if [ -e "${outfile}" ]; then
  if [ "${force}" -ne 1 ]; then
    logger "ERROR" "Output already exists, remove or run with -f 1"
    exit 2
  fi
fi

logger "ENV" "${env}"
source ${env}/bin/activate

cmd=""
stats=""

if [ "$package" == "totalsegmentator" ]; then

  # Create output directory if it does not exist
  outdir=`dirname $outfile`
  if [ ! -d "${outdir}" ]; then
    mkdir -p ${outdir}
  fi

  cmd="${env}/bin/TotalSegmentator -i $infile -o $outfile -ta $module $opts"
  srcdir="${BASH_SOURCE[0]}"
  odir=`dirname $outfile`
  oname=`basename $outfile .nii.gz`
  outstats="${odir}/${oname}_stats.csv"

  if [[ "$opts" != *--ml* ]]; then
    outstats="${odir}/${oname}/pmbb_vision_stats.csv"
  fi


  stats="${env}/bin/python  ${PMBB_VISION_SLURM}/ts_stats_simple.py -i $infile -s $outfile -o ${outstats}"  
  #echo $0
  #echo $srcdir
  
  if [ "$module" == "get_phase" ]; then
    cmd="${env}/bin/totalseg_get_phase -i $infile -o $outfile"
  fi
fi 

# Run the pipeline
logger "CMD" "$cmd"
$cmd
if [ "${stats}" != "" ]; then
  logger "CMD" "$stats"
  $stats
fi


end_time=$(date +%s)
run_seconds=$((end_time - start_time))
runtime_hours=$(echo "scale=2; $run_seconds / 3600" | bc)

readonly SECONDS_PER_HOUR=3600
readonly SECONDS_PER_MINUTE=60

hours=$((${run_seconds} / ${SECONDS_PER_HOUR}))
seconds=$((${run_seconds} % ${SECONDS_PER_HOUR}))
minutes=$((${run_seconds} / ${SECONDS_PER_MINUTE}))
seconds=$((${seconds} % ${SECONDS_PER_MINUTE}))

run_time=$(printf "%02d:%02d:%02d" ${hours} ${minutes} ${seconds})
logger "INFO" "Run time: $run_time"
logger "--" "--"

exit 0
