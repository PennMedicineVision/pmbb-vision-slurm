#!/bin/bash
#SBATCH --job-name=totalseg_ct_ab

#SBATCH --output=/cbica/projects/pmbb-vision/logs/processing/totalsegmentator/array_job_explicit_totalsegmentator_%A_%a.out
#SBATCH --error=/cbica/projects/pmbb-vision/logs/processing/totalsegmentator/array_job_explicit_totalsegmentator_%A_%a.err
#SBATCH --array=1-10

# Pass in array at command line due to limits on numbers of tasks per job
#module load dcmtk 2> /dev/null
#module load c3d 2> /dev/null
#dcmtk=/cbica/projects/pmbb-vision/pkg/dcmtk-3.6.8-linux-x86_64-static/bin

logger () {
  d=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$d array_job_explicit_totalsegmentator $1 $2 - SLURM=${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
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
logger "INFO" "Prepping for totalsegmentator"

# CSV file with series level info
index=/cbica/projects/pmbb-vision/info/pmbbid_dicom_series_ct_imgs.csv

if [ ! -e "$index" ]; then
    logger "ERROR" "Index file not found at: $index"
    exit 1
fi

# here we assume static base directories for input and output
# we could use additional columns to identify in/out directories if they vary across subjects
ibase=/cbica/projects/pmbb-vision/subjects
obase=/cbica/projects/pmbb-vision/processing/totalsegmentator

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

pmbbid=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $2}')
study_uid=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $3}')
acc=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $4}')
stamp=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $5}')
series_num=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $6}')
series_desc=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $7}')
body_part_examined=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $8}')
body_part=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $9}')
modality=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $10}')
procedure=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $11}')
ninstances=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $12}')
size=$($cat | awk -F ',' -v TaskID=$offset '$1==TaskID {print $13}')

# get rid of decimals in time stamp
stamp=$(echo $stamp | cut -d '.' -f1)

# dcm2niix replaces dash with underscore
series_desc=$(echo "$series_desc" | sed -r 's/-/_/g')

d1=${pmbbid:4:4} 
d2=${pmbbid:8:4}

series_dir="${pmbbid}_${acc}_${stamp}_${series_num}_${series_desc}"
in_dir="${ibase}/${d1}/${d2}/${pmbbid}/${acc}/${study_uid}/${series_dir}"
out_dir="${obase}/${d1}/${d2}/${pmbbid}/${acc}/${study_uid}/${series_dir}"

logger "INFO" "Attempt totalsegmentator CT for ID: ${pmbbid} Study: ${study_uid} Accession: ${acc} SeriesNumber: ${series_num}"

# Does input directory exist
if [ ! -d ${in_dir} ]; then
    logger "INFO" "${in_dir} does not exist. Exiting"
    #ls "${ibase}/${d1}/${d2}/${pmbbid}/${acc}/${study_uid}"
    exit 0
fi

mkdir -p $out_dir
source /cbica/projects/pmbb-vision/env/pmbbvision-totalseg/bin/activate


# do stuff
files=$(ls ${in_dir}/*.nii.gz)
for f in $files; do
  logger "INFO" "Running totalsegmentator for: $f"

  run_ct_ab=0
  if [ "$modality" = "CT" ]; then
    #if [ "$body_part" = "ABDOMEN" ]; then
    #  run_ct_ab=1
    #fi
    #if [ "$body_part" = "CHEST" ]; then
    #  run_ct_ab=1
    #fi   
    run_ct_ab=1
  fi

  if (( $run_ct_ab == 1 )); then
    logger "INFO" "Running totalsegmentator total for $f"
    base=`basename $f .nii.gz`
    outfile="${out_dir}/${base}_ts_total_ct.nii.gz"
    outphase="${out_dir}/${base}_contrast_phase.json"
    outidp="${out_dir}/${base}_ts_total_ct_idp.csv"
    outppe="${out_dir}/${base}_ts_ppe.nii.gz"

    if [ ! -e ${outphase} ]; then
      phase_cmd="/cbica/projects/pmbb-vision/env/pmbbvision-totalseg/bin/totalseg_get_phase -i $f -o $outphase"
      logger "RUN" "$phase_cmd"
      $phase_cmd
    else
      logger "WARNING" "Output already exists. Remove to rerun: ${outphase}"
    fi
    
    if [ ! -e ${outfile} ]; then 
      seg_cmd="/cbica/projects/pmbb-vision/env/pmbbvision-totalseg/bin/TotalSegmentator -i $f -o $outfile -ta total --ml"
      logger "RUN" "$seg_cmd"
      $seg_cmd
    else
      logger "WARNING" "Output already exists. Remove to rerun: ${outfile}"
    fi

    if [ ! -e ${outppe} ]; then
      ppe_cmd="/cbica/projects/pmbb-vision/env/pmbbvision-totalseg/bin/TotalSegmentator -i $f -o $outppe -ta pleural_pericard_effusion --ml"
      logger "RUN" "$ppe_cmd"
      $ppe_cmd
    else
      logger "WARNING" "Output already exists. Remove to rerun: ${outppe}"
    fi

    #if [ ! -e ${outidp} ]; then
      idp_cmd="/cbica/projects/pmbb-vision/env/pmbbvision-totalseg/bin/python /cbica/projects/pmbb-vision/scripts/pmbb-vision-utilities/ts_stats_simple.py -i $f -s $outfile -e ${outppe} -o $outidp"
      logger "RUN" "$idp_cmd"
      $idp_cmd
    #fi
  fi

done

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
#end_date=$(date)
#printf "End (%d %s %s %s %s): %s\n" ${SLURM_ARRAY_TASK_ID} ${pmbbid} ${acc} ${datetime} ${study_uid} "${end_date}"
logger "INFO" "End $study_info"
logger "--" "--"

exit 0
