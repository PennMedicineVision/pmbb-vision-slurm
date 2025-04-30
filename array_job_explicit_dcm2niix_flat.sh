#!/bin/bash
#SBATCH --job-name=array_job_explicit_dcm2niix

#SBATCH --cpus-per-task=1
#SBATCH --output=/cbica/projects/pmbb-vision/logs/array_job_explicit_dcm2niix_%A_%a.out
#SBATCH --error=/cbica/projects/pmbb-vision/logs/array_job_explicit_dcm2niix_%A_%a.err
#SBATCH --array=1-10

# Pass in array at command line due to limits on numbers of tasks per job
module load dcmtk 2> /dev/null
module load c3d 2> /dev/null
#dcmtk=/cbica/projects/pmbb-vision/pkg/dcmtk-3.6.8-linux-x86_64-static/bin

logger () {
  d=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$d array_job_explicit_dcm2niix_flat $1 $2 - SLURM=${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
}

usage() { echo "Usage: $0 [-q -h]"; exit 1; }

query=0
while getopts qh flag
do
  case "${flag}" in
     q) query=1;;
     h) usage;;
  esac
done

start_date=$(date '+%Y-%m-%d %H:%M:%S')
start_time=$(date +%s)

#echo "SLURM_JOB_ID: $SLURM_JOB_ID"
logger "INFO" "Initializing reconstruction"

# CSV file with index,directory_name
index="$1"

if [ ! -e "$index" ]; then
    logger "ERROR" "Index file not found at: $index"
    exit 1
fi

# here we assume static base directories for input and output
# we could use additional columns to identify in/out directories if they vary across subjects
ibase="$2"
obase="$3"


# add one due to header line in csv file
offset=$((SLURM_ARRAY_TASK_ID + 1))

cat="cat $index"
if [ "$index" == "*.parquet" ]; then
  cat="parquet-tools csv $index"
fi

name=$($cat | awk -F ',' -v TaskID=$SLURM_ARRAY_TASK_ID '$1==TaskID {print $2}')

# if additional params are needed, they can be included as columns and extracted here

in_dir="${ibase}/${name}"
out_dir="${obase}/${name}"

logger "INFO" "Attempt reconstruction for: ${name}"

# Does input directory exist
if [ ! -e ${in_dir} ]; then
    logger "ERROR" "${in_dir} does not exist"
    exit 3
fi

# Ideally index only has unprocessed data listed, but...
if [ -e ${out_dir} ]; then
    logger "ERROR" "Output directory already exists. Remove to rerun: ${out_dir}"
    exit 4
fi

mkdir -p $out_dir

# do stuff

# get subject id
file=$(find ${in_dir} -name *.dcm | head -n 1)
datetime="NA"
if [ -e "$file" ]; then 
  date=`dcmdump --search 0008,0020 --search-first $file | awk -F [ '{print $2}' | awk -F ] '{print $1}'`
  time=`dcmdump --search 0008,0030 --search-first $file | awk -F [ '{print $2}' | awk -F ] '{print $1}' | cut -d '.' -f1`
  datetime=($echo "${date}${time}")
fi

study_info=$(printf "[%s,%s,%s,%s]" ${name} ${datetime})
logger "INFO" "Start $study_info"

source $4

if [ -e "$file" ]; then
  sh ${DICOMTREEPATH}/scripts/dicom_to_nii.sh -i ${in_dir} -o ${out_dir} -m 20 -a ${name}_${datetime}
else
  logger "WARNING" "No images found $study_info"
fi

# grab all meta data from dicom headers
python ${DICOMTREEPATH}/dicom_tree/dicom_tree.py -p ${in_dir} -r 2 -c -o ${out_dir}/${name}_${datetime}_study_tree.json

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
logger "INFO" "End $study_info"

exit 0
