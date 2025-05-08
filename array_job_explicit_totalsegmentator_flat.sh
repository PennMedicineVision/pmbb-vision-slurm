#!/bin/bash
#SBATCH --job-name=totalseg_ct_ab

#SBATCH --output=/cbica/projects/pmbb-vision/logs/processing/totalsegmentator/array_job_explicit_totalsegmentator_flat_%A_%a.out
#SBATCH --error=/cbica/projects/pmbb-vision/logs/processing/totalsegmentator/array_job_explicit_totalsegmentator_flat_%A_%a.err
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

ibase=""
obase=""
index=0
runppe=0
env=""
while getopts d:i:o:p:e:qh flag
do
  case "${flag}" in
     q) query=1;;
     h) usage;;
     i) index=$OPTARG;;
     d) ibase=$OPTARG;;
     e) env=$OPTARG;;
     o) obase=$OPTARG;;
     p) runppe=$OPTARG;;
  esac
done

start_date=$(date '+%Y-%m-%d %H:%M:%S')
start_time=$(date +%s)

#echo "SLURM_JOB_ID: $SLURM_JOB_ID"
logger "INFO" "Prepping for totalsegmentator"

if [ ! -e "$index" ]; then
    logger "ERROR" "Index file not found at: $index"
    exit 1
fi

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

name=$($cat | awk -F ',' -v TaskID=$SLURM_ARRAY_TASK_ID '$1==TaskID {print $2}')

in_dir="${ibase}/${name}"
out_dir="${obase}/${name}"

# Does input directory exist
if [ ! -d ${in_dir} ]; then
    logger "INFO" "${in_dir} does not exist. Exiting"
    exit 0
fi

source ${env}/bin/activate

for s in `ls -d ${in_dir}/*`; do 
  sname=`basename $s`
  logger "INFO" "Attempt totalsegmentator CT for: ${name} Series: ${sname}"

  series_out_dir="${out_dir}/${sname}"
  mkdir -p ${series_out_dir}

  files=$(ls ${s}/*.nii.gz)
  for f in $files; do
    logger "INFO" "Running totalsegmentator for: $f"

    base=`basename $f .nii.gz`
    outfile="${series_out_dir}/${base}_ts_total_ct.nii.gz"
    outphase="${series_out_dir}/${base}_contrast_phase.json"
    outidp="${series_out_dir}/${base}_ts_total_ct_idp.csv"
    outppe="${series_out_dir}/${base}_ts_ppe.nii.gz"

    if [ ! -e ${outphase} ]; then
      phase_cmd="${env}/bin/totalseg_get_phase -i $f -o $outphase"
      logger "RUN" "$phase_cmd"
      $phase_cmd
    else
      logger "WARNING" "Output already exists. Remove to rerun: ${outphase}"
    fi
    
    if [ ! -e ${outfile} ]; then 
      seg_cmd="${env}/bin/TotalSegmentator -i $f -o $outfile -ta total --ml"
      logger "RUN" "$seg_cmd"
      $seg_cmd
    else
      logger "WARNING" "Output already exists. Remove to rerun: ${outfile}"
    fi

    if [ "$runppe" -eq 1 ]; then
      if [ ! -e ${outppe} ]; then
        ppe_cmd="${env}/bin/TotalSegmentator -i $f -o $outppe -ta pleural_pericard_effusion --ml"
        logger "RUN" "$ppe_cmd"
        $ppe_cmd
      else
        logger "WARNING" "Output already exists. Remove to rerun: ${outppe}"
      fi
    fi

    if [ ! -e ${outidp} ]; then 
      idp_cmd="${env}/bin/python /cbica/projects/pmbb-vision/scripts/pmbb-vision-utilities/ts_stats_simple.py -i $f -s $outfile -o $outidp"
      if [ -e "${outppe}" ]; then
        idp_cmd="${idp_cmd} -e ${outppe}"
      fi
      logger "RUN" "$idp_cmd"
      $idp_cmd
    else 
      logger "WARNING" "Output already exists. Remove to rerun: ${outidp}"
    fi

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
