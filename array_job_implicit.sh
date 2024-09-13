#!/bin/bash
#SBATCH --job-name=array_job_implicit
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --output=/cbica/projects/pmbb-vision/logs/array_job_implicit_%j.out
#SBATCH --error=/cbica/projects/pmbb-vision/logs/array_job_implicit_%j.err
#SBATCH --array=1-10

# Pass in array at command line due to limits on numbers of tasks per job

# CSV file with: subject_id,study_id
index=/cbica/projects/pmbb-vision/pkg/pmbb-vision-slurm/data/test_index_implicit.csv
if [ ! -e "$index" ]; then
    echo "Index file not found at: $index" 1>&2
    exit 1
fi

# here we assume static base directories for input and output
# we could use additional columns to identify in/out directories if they vary across subjects
ibase=/cbica/projects/pmbb-vision/dicom
obase=/cbica/projects/pmbb-vision/subjects-dev

# add one due to header line in csv file
offset=$((SLURM_ARRAY_TASK_ID + 1))

max_offset=$(cat $index | wc | xargs | cut -d " " -f1)
if (( offset > max_offset )); then
    echo "TaskID exceeds array size" 1>&2
    exit 2
fi

sub_line=$(head -n $offset $index | tail -n 1)

# get info for study
pmbbid=$(echo $sub_line | cut -d "," -f1)
study_uid=$(echo $sub_line | cut -d "," -f2)

# if additional params are needed, they can be included as columns and extracted here


d1=${pmbbid:4:4} 
d2=${pmbbid:8:4}

in_dir="${ibase}/${d1}/${d2}/${pmbbid}/${study_uid}"
out_dir="${obase}/${d1}/${d2}/${pmbbid}/${study_uid}"

# Does input directory exist
if [ ! -e ${in_dir} ]; then
    echo "${in_dir} does not exist" 1>&2
    exit 3
fi

# Ideally index only has unprocessed data listed, but...
if [ -e ${out_dir} ]; then
    echo "  - Output directory already exists. Remove to rerun" 1>&2
    exit 3
fi

# do stuff
echo "Task: ${SLURM_ARRAY_TASK_ID}   Subject: ${pmbbid}   Study: ${study_uid}"

exit 0