#!/bin/bash
#SBATCH --job-name=synthseg_pmbb

#SBATCH --output=/cbica/projects/pmbb-vision/logs/processing/synthseg/array_job_explicit_synthseg_%A_%a.out
#SBATCH --error=/cbica/projects/pmbb-vision/logs/processing/synthseg/array_job_explicit_synthseg_%A_%a.err
#SBATCH --array=1-10

logger () {
  d=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$d array_job_explicit_synthseg $1 $2 - SLURM=${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
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
logger "INFO" "Prepping for synthseg"

# CSV file with images to process
index=/cbica/projects/pmbb-vision/info/pmbbvision_brain_mr_images.csv

if [ ! -e "$index" ]; then
    logger "ERROR" "Index file not found at: $index"
    exit 1
fi

# here we assume static base directories for input and output
# we could use additional columns to identify in/out directories if they vary across subjects
ibase=/cbica/projects/pmbb-vision/subjects
obase=/cbica/projects/pmbb-vision/processing/synthseg

offset=$SLURM_ARRAY_TASK_ID
#echo "Found offset of ${SLURM_ARRAY_TASK_ID_OFFSET}"
if [ -n "${SLURM_ARRAY_TASK_ID_OFFSET}" ]; then
  #echo "Using offset of ${SLURM_ARRAY_TASK_ID_OFFSET}"
  offset=$((${SLURM_ARRAY_TASK_ID}+${SLURM_ARRAY_TASK_ID_OFFSET}))
fi 

cat="cat $index"
if [ "$index" == "*.parquet" ]; then
  cat="parquet-tools csv $index"
fi

img=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $2}')
img_name=`basename $img .nii.gz`
img_dir=`dirname $img`

out_dir=${img_dir/${ibase}/${obase}}
out_img="${out_dir}/${img_name}_synthseg.nii.gz"
out_vol="${out_dir}/${img_name}_synthseg_vol.csv"
out_qc="${out_dir}/${img_name}_synthseg_qc.csv"
out_rs="${out_dir}/${img_name}_resampled.nii.gz"
out_stats="${out_dir}/${img_name}_synthseg_idp.csv"

logger "INFO" "Attempt synthseg for image ID: ${img}"

# Does input image exist
if [ ! -e ${img} ]; then
    logger "INFO" "${img} does not exist. Exiting"
        exit 0
fi

mkdir -p $out_dir
source /cbica/projects/pmbb-vision/env/pmbbvision-sythseg/bin/activate


# do stuff

logger "INFO" "Running synthseg for: $img"

if [ ! -e ${out_rs} ]; then
  cmd="/cbica/projects/pmbb-vision/env/pmbbvision-synthseg/bin/python /cbica/projects/pmbb-vision/pkg/SynthSeg/scripts/commands/SynthSeg_predict.py --i ${img} --o ${out_img} --robust --parc --vol ${out_vol} --qc ${out_qc} --resample ${out_rs}"
  logger "RUN" "$cmd"
  $cmd
else
  logger "WARNING" "Output already exists. Remove to rerun: ${out_img}"
fi
  
if [ ! -e "${out_stats}" ]; then
  source /cbica/projects/pmbb-vision/env/pmbbvision-totalseg/bin/activate
  idp_cmd="/cbica/projects/pmbb-vision/env/pmbbvision-totalseg/bin/python /cbica/projects/pmbb-vision/scripts/pmbb-vision-utilities/ss_stats_simple.py -i ${img} -q ${out_qc}  -r ${out_rs} -s ${out_img} -o ${out_stats}"
  logger "RUN" "$idp_cmd"
  $idp_cmd
  rm ${out_rs}
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
logger "INFO" "End $study_info"
logger "--" "--"

exit 0
