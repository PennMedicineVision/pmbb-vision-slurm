# pmbb-vision-slurm
Examples for using slurm on the Penn Cubic cluster to process PMBB data. 

## array jobs
In order to process a large number of datasets efficiently on Cubic, it is preferred to run array jobs with many tasks, as opposed to submitting a job for each dataset. However, it is important to note that array jobs are currently limited to 40k tasks per job, so for large datasets it is still necessary to run multiple jobs. Below are some examples illustrating how to run array jobs to process PMBB imaging data. These are just dummy jobs that check to see if the input directory exists, but they can be easily adapted to perform actual processing which will require adjusting the parameters (time,mem,etc) to fit the specific requirements.  These array job examples are adapted from [https://blog.ronin.cloud/slurm-job-arrays/](https://blog.ronin.cloud/slurm-job-arrays/). Here we provide small example index files that are similar in format to the files in /cbica/projects/pmbb-vision/info/

### array_job_explicit.sh 
This script illustrates using an index file that explicitly assigns a task ID to each study to be processed. In this case the index file would look something like [this](data/test_index_explicit.csv):
```
Index,PMBBID,StudyUID
     1,PMBBF9350031529,2.25.313991534711542874945730579142217377317
     2,PMBBG4238204654,2.25.30459592654112269811486289875194096760
     3,PMBBG4238204654,2.25.143372609676664291315904351266195943958
     4,PMBBH2865036253,2.25.42771372005469031302627988466531272381
     5,PMBBT8832540424,2.25.165055721769530451775508541750378476670
     6,PMBBU3864141996,2.25.177430724401240158340954912296521282074
     7,PMBBU3864141996,2.25.157665824130629768730053815252163641825
     8,PMBBK6630742998,2.25.273417152082507960260956514447237915174
     9,PMBBK6630742998,2.25.20523254586298670512652917426621401578
    10,PMBBK6630742998,2.25.331934967344314474390653110981139226657
```
This can be tested by submitting via:
```
sbatch --time=1 --partition=short --mem=10 array_job_explicit.sh
```

You could run a subset of the data in the index file via:
```
sbatch --array=5-10 --time=1 --partition=short --mem=10 array_job_explicit.sh
```

### array_job_implicit.sh 
This script illustrates using an index file where we use (unlisted) row numbers to associate with the task ID for each study to be processed. In this case the index file would look something like [this](data/test_index_implicit.csv):
```
PMBBID,StudyUID
PMBBF9350031529,2.25.313991534711542874945730579142217377317
PMBBG4238204654,2.25.30459592654112269811486289875194096760
PMBBG4238204654,2.25.143372609676664291315904351266195943958
PMBBH2865036253,2.25.42771372005469031302627988466531272381
PMBBT8832540424,2.25.165055721769530451775508541750378476670
PMBBU3864141996,2.25.177430724401240158340954912296521282074
PMBBU3864141996,2.25.157665824130629768730053815252163641825
PMBBK6630742998,2.25.273417152082507960260956514447237915174
PMBBK6630742998,2.25.20523254586298670512652917426621401578
PMBBK6630742998,2.25.331934967344314474390653110981139226657
```
This can be tested by submitting via:
```
sbatch --time=1 --partition=short --mem=10 array_job_implicit.sh
```
