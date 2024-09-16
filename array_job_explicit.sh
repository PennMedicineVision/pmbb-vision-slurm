#!/bin/bash
#SBATCH --job-name=myarrayjob
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --output=/cbica/projects/pmbb-vision/logs/array_job_explicit_%j.out
#SBATCH --error=/cbica/projects/pmbb-vision/logs/array_job_explicit_%j.err
#SBATCH --array=1-10

# CSV file with: index,subject_id,study_id
index=/cbica/projects/pmbb-vision/pkg/pmbb-vision-slurm/data/test_index_explicit.csv
if [ ! -e "$index" ]; then
    echo "Index file not found at: $index" 1>&2
    exit 1
fi

# here we assume static base directories for input and output
# we could use additional columns to identify in/out directories if they vary across subjects
ibase=/cbica/projects/pmbb-vision/dicom
obase=/cbica/projects/pmbb-vision/subjects

# get subject and study info
cat="cat $index"
if [ "$index" == "*.parquet" ]; then
  cat="parquet-tools csv $index"
fi
 
pmbbid=$($cat | awk -F ',' -v TaskID=$SLURM_ARRAY_TASK_ID '$1==TaskID {print $2}')
study_uid=$($cat | awk -F ',' -v TaskID=$SLURM_ARRAY_TASK_ID '$1==TaskID {print $3}')

# if additional params are needed, they can be included as columns and extracted here

if [ "$pmbbid" == "" ]; then
  echo "No subject found for TaskID=${SLURM_ARRAY_TASK_ID}" 1>&2
  exit 2
fi

d1=${pmbbid:4:4} 
d2=${pmbbid:8:4}

in_dir="${ibase}/${d1}/${d2}/${pmbbid}/${study_uid}"
out_dir="${obase}/${d1}/${d2}/${pmbbid}/${study_uid}"


# Does input directory exist
if [ ! -e ${in_dir} ]; then
    echo "${in_dir} does not exist" 1>&2
    exit 3
fi

# Ideally index only has unprocessed data, but...
if [ -e ${out_dir} ]; then
    echo "${out_dir} already exists. Remove to rerun" 1>&2
    exit 4
fi

# do stuff
echo "Task: ${SLURM_ARRAY_TASK_ID}   Subject: ${pmbbid}   Study: ${study_uid}"

exit 0
