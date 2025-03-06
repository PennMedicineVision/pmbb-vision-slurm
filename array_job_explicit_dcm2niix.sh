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
  echo "$d array_job_explicit_dcm2niix $1 $2 - SLURM=${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
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

# CSV file with: subject_id,study_id
#index=/cbica/projects/pmbb-vision/info/pmbbid_uid_acc_ordered.csv
index=/cbica/projects/pmbb-vision/info/pmbbid_uid_acc_ordered_004.csv

if [ ! -e "$index" ]; then
    logger "ERROR" "Index file not found at: $index"
    exit 1
fi

# here we assume static base directories for input and output
# we could use additional columns to identify in/out directories if they vary across subjects
ibase=/cbica/projects/pmbb-vision/dicom
obase=/cbica/projects/pmbb-vision/subjects

# add one due to header line in csv file
offset=$((SLURM_ARRAY_TASK_ID + 1))

cat="cat $index"
if [ "$index" == "*.parquet" ]; then
  cat="parquet-tools csv $index"
fi

pmbbid=$($cat | awk -F ',' -v TaskID=$SLURM_ARRAY_TASK_ID '$1==TaskID {print $2}')
study_uid=$($cat | awk -F ',' -v TaskID=$SLURM_ARRAY_TASK_ID '$1==TaskID {print $3}')
acc=$($cat | awk -F ',' -v TaskID=$SLURM_ARRAY_TASK_ID '$1==TaskID {print $4}')

# if additional params are needed, they can be included as columns and extracted here

d1=${pmbbid:4:4} 
d2=${pmbbid:8:4}

in_dir="${ibase}/${d1}/${d2}/${pmbbid}/${study_uid}"
out_dir="${obase}/${d1}/${d2}/${pmbbid}/${acc}/${study_uid}"

logger "INFO" "Attempt reconstruction for ID: ${pmbbid} Study: ${study_uid} Accession: ${acc}"

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
id=$(echo ${in_dir} | xargs dirname | xargs basename)
file=$(find ${in_dir} -name *.dcm | head -n 1)
datetime="NA"
if [ -e "$file" ]; then 
  date=`dcmdump --search 0008,0020 --search-first $file | awk -F [ '{print $2}' | awk -F ] '{print $1}'`
  time=`dcmdump --search 0008,0030 --search-first $file | awk -F [ '{print $2}' | awk -F ] '{print $1}' | cut -d '.' -f1`
  datetime=($echo "${date}${time}")
fi

study_info=$(printf "[%s,%s,%s,%s]" ${pmbbid} ${acc} ${datetime} ${study_uid})
logger "INFO" "Start $study_info"

# report total size of study dicom directory
#srun -n1 -l du -h -d 0 ${in_dir} | cut -f1 &

source /cbica/projects/pmbb-vision/env/pmbbvision-dicom/bin/activate

# Convert files in each series directory into a nifti volume
image_dirs=$(ls -d ${in_dir}/[0-9]*)
#for i in $image_dirs; do
  # srun -n1 -l dcm2niix -a y -z y -q n -v n -f PMBB%i_%g_%f -o $out_dir ${i} &
  # srun -n1 -l sh ${DICOMTREEPATH}/scripts/dicom_to_nii.sh 
  #sh ${DICOMTREEPATH}/scripts/dicom_to_nii.sh -i ${in_dir} -o ${out_dir} -m 20 -s  
  #echo "FIXME dicom_to_nii.sh"
#done

if [ -e "$file" ]; then
  sh ${DICOMTREEPATH}/scripts/dicom_to_nii.sh -i ${in_dir} -o ${out_dir} -m 20 -a ${pmbbid}_${acc}_${datetime}
else
  logger "WARNING" "No images found $study_info"
fi

SAVEIFS=$IFS
IFS=$(echo -en "\b\n")

# Extract some meta info from report files
reports=$(ls ${in_dir}/Diagnostic*Report/*.dcm 2> /dev/null)
nr=0

logger "INFO" "Extract Diagnostic Reports"

find ${in_dir}/Diagnostic* -type f | while read r; do
#for r in `ls ${in_dir}/Diagnostic*Report/*.dcm`; do

    logger "INFO" "$SLURM_ARRAY_TASK_ID Dicom report $nr: $r"
    #acc=`dcmdump --search 0008,0050 --search-first $r | awk -F [ '{print $2}' | awk -F ] '{print $1}'`
    r_json=$(printf "${out_dir}/${pmbbid}_${acc}_${datetime}_report%03d.json" "$rn")
    r_text=$(printf "${out_dir}/${pmbbid}_${acc}_${datetime}_report%03d.txt" "$rn")

    # run the conversion/s
    #srun -n1 -l /cbica/projects/pmbb-vision/pkg/pmbb-vision-slurm/extract_report.sh $r $r_json $r_text &
    sh /cbica/projects/pmbb-vision/pkg/pmbb-vision-slurm/extract_report.sh "$r" $r_json $r_text 
    nr=$((nr+1))
done

IFS=$SAVEIFS

# grab all meta data from dicom headers
#source /cbica/projects/pmbb-vision/env/pmbbvision-dicom/bin/activate
#srun -n1 -l python /cbica/projects/pmbb-vision/pkg/dicom_tree/dicom_tree/dicom_tree.py -p ${in_dir} -r 2 -c -o ${out_dir}/${id}_${acc}_study_tree.json &
python /cbica/projects/pmbb-vision/pkg/dicom_tree/dicom_tree/dicom_tree.py -p ${in_dir} -r 2 -c -o ${out_dir}/${pmbbid}_${acc}_${datetime}_study_tree.json

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

exit 0
