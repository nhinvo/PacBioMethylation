#!/usr/bin/env bash
#SBATCH --job-name=KineticsBystrandify_Revio_SMRTTools
#SBATCH --time 5-0                     
#SBATCH -p sched_mit_chisholm               # partition selection
#SBATCH -c 20                               
#SBATCH -N 1
#SBATCH --mem 250G
#SBATCH --array=2-4%3  # 3 raw .bam files 
#SBATCH -o logs/KineticsBystrandify-%a-%j.out
#SBATCH -e logs/KineticsBystrandify-%a-%j.err

# Purpose: to run ccs-kinetics-bystrandify on the raw .bam files 

echo "Current date and time: $(date)"

### Obtain data from bam_sample.tsv file ### 
barcode=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_Revio_raw_bam.tsv | cut -f1 | tr -d '\r')
hifi_bam_path=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_Revio_raw_bam.tsv | cut -f2 | tr -d '\r')

### Output dir for SMRT Tools Analysis ##
outdir=data/KineticsBystrandifyOutput
mkdir -p ${outdir}

### Add SMRT Tools to PATH ###
export PATH="/nfs/chisholmlab001/nvo/bin/smrtlink_13.1.0/smrtcmds/bin:$PATH"  # newer version of SMRTTools (13.1)

### Add kinetics info ###
echo
echo ------------------------------------------------------------------------------------------
echo adding kinetics info to ccs...
ccs-kinetics-bystrandify --version
ccs-kinetics-bystrandify \
    --num-threads ${SLURM_CPUS_PER_TASK} \
    --log-level DEBUG \
    ${hifi_bam_path} \
    ${outdir}/${barcode}.ccs.kinetics.bam