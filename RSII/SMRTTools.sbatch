#!/usr/bin/env bash
#SBATCH --job-name=RSII_SMRTTools_motif_finding
#SBATCH --time 11:00:00                         # wall clock limit
#SBATCH -p sched_mit_chisholm               # partition selection
#SBATCH -c 20                                # tasks (essentially threads)
#SBATCH -N 1
#SBATCH --mem 250G
#SBATCH --array=11
#SBATCH -o logs/%a.%j.out
#SBATCH -e logs/%a.%j.err

# Purpose: to obtain motifs from PacBio RSII read files. 

echo Batch job ID: ${SLURM_JOB_ID}
echo "Current date and time: $(date)"

### Obtain input paths from sample.tsv file ### 
# Reference genome data (assembled from raw PacBio reads or from IMG)
genome_name=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_RSII_input.tsv | cut -f1 | tr -d '\r')
genome_path=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_RSII_input.tsv | cut -f2 | tr -d '\r')

# Metadata about the files 
barcode=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_RSII_input.tsv | cut -f3 | tr -d '\r')
genus=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_RSII_input.tsv | cut -f4 | tr -d '\r')

# Raw read bas.h5 paths 
read_filename=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_RSII_input.tsv | cut -f5 | tr -d '\r')
bas_h5_fpath=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_RSII_input.tsv | cut -f6 | tr -d '\r')



# output path
outdir=data/SMRTToolsOutput/${barcode}/${genus}
mkdir -p ${outdir}
cd ${outdir}



### Output dir for SMRT Tools Analysis ##
export PATH="/nfs/chisholmlab001/nvo/bin/smrtlink_7.0.1/install/smrtlink-release_7.0.1.66975/bundles/smrttools/install/smrttools-release_7.0.1.66768/smrtcmds/bin:$PATH"



### Generate index for reference fasta file ###
echo Copying reference fasta from path: ${genome_path}...
cp ${genome_path} ${genome_name}.fasta

echo Indexing Ref Fasta file: ${genome_name}.fasta...
samtools --version | head
samtools faidx ${genome_name}.fasta



### Convert bas.h5 input file into .bam ###
echo Converting bas.h5 file ${read_filename} into subreads.bam...
bax2bam --version
bax2bam -o bas_h5 ${bas_h5_fpath}



### Align reads to reference ###
echo Aligning and Idexing ${read_filename} reads to reference genome ${genome_name}.fasta... 
pbalign --version

pbalign \
    --concordant \
    --hitPolicy=randombest \
    --minAccuracy 70 \
    --nproc ${SLURM_CPUS_PER_TASK} \
    bas_h5.subreads.bam \
    ${genome_name}.fasta \
    aligned_subreads.bam

pbindex aligned_subreads.bam

# 4. analyze aligned sequences for base modifications
echo Obtaining IPD Summary ... 
ipdSummary \
    aligned_subreads.bam \
    --reference ${genome_name}.fasta \
    --gff basemods.gff \
    --csv basemods.csv \
    --pvalue 0.005 \
    --numWorkers ${SLURM_CPUS_PER_TASK} \
    --identify m4C,m6A

# 5. identify consensus motifs 
echo Running motif finding ... 
motifMaker find -f ${genome_name}.fasta -g basemods.gff -o motifs.csv

# # 6. generate a GFF file of all modifications that are part of motifs (commented out - not needed currently)
# motifMaker reprocess -f reference.fasta -g basemods.gff -m motifs.csv -o motifs.gff

echo "Current date and time: $(date)"
