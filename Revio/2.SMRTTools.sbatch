#!/usr/bin/env bash
#SBATCH --job-name=Revio_SMRTTools_motif_finding
#SBATCH --time 5-0                     
#SBATCH -p sched_mit_chisholm               # partition selection
#SBATCH -c 20                               
#SBATCH -N 1
#SBATCH --mem 250G
#SBATCH --array=2-16%3
#SBATCH -o logs/Motif-%a-%j.out
#SBATCH -e logs/Motif-%a-%j.err

# Purpose: to obtain motifs from PacBio Revio read files. 

echo "Current date and time: $(date)"

### Obtain data from sample.tsv file ### 
# Reference genome data (assembled from raw PacBio reads)
genome_name=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_Revio_input.tsv | cut -f1 | tr -d '\r')
genome_path=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_Revio_input.tsv | cut -f2 | tr -d '\r')
barcode=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_Revio_input.tsv | cut -f3 | tr -d '\r')

### Output dir for SMRT Tools Analysis ##
outdir=data/SMRTToolsOutput/${genome_name}

# remove dir if already exist 
if [ -d "$outdir" ]; then
    rm -rf ${outdir}  
fi

# remake output dir & change workdir 
mkdir -p ${outdir}
cd ${outdir}

### Add SMRT Tools to PATH ###
export PATH="/nfs/chisholmlab001/nvo/bin/smrtlink_13.1.0/smrtcmds/bin:$PATH"  # newer version of SMRTTools (13.1)

### Generate index for reference fasta file ###
echo
echo ------------------------------------------------------------------------------------------
echo Copying reference fasta from path: ${genome_path}
cp ${genome_path} ${genome_name}.fasta

echo Indexing Ref Fasta file: ${genome_name}.fasta
samtools --version | head
samtools faidx ${genome_name}.fasta

### Obtain path to kinetics bam ### 
# kinetics data already processed in step 2: 
kinetics_dir=/nfs/chisholmlab001/nvo/projects/24_allison_methylation/ObtainMethylationMotifsSMRTTools/Revio/data/KineticsBystrandifyOutput
kinetics_bam=${kinetics_dir}/${barcode}.ccs.kinetics.bam

### Align reads to assembled reference ###
echo
echo ------------------------------------------------------------------------------------------
echo Running pmn2 alignment ...

# Read alignment 
pbmm2 --version 
pbmm2 align \
    --sort \
    --preset HIFI \
    --log-level DEBUG \
    --num-threads ${SLURM_CPUS_PER_TASK} \
    ${genome_name}.fasta \
    ${kinetics_bam} \
    ${genome_name}.aligned.bam
    
# Index aligned reads 
echo indexing aligned bam file 
pbindex --version
pbindex ${genome_name}.aligned.bam --num-threads ${SLURM_CPUS_PER_TASK}

### Run ipd Summary to obtain motif gff file ###
echo
echo ------------------------------------------------------------------------------------------
echo Running ipdSummary to obtain motif.gff files ... 
ipdSummary --version
ipdSummary \
    ${genome_name}.aligned.bam \
    --log-level DEBUG \
    --reference ${genome_name}.fasta \
    --numWorkers ${SLURM_CPUS_PER_TASK} \
    --pvalue 0.05 \
    --identify m6A,m4C,m5C_TET \
    --gff ${genome_name}.modified.gff

### motifMaker to obtain motifs ### 
echo
echo ------------------------------------------------------------------------------------------
echo Running motifMaker to obtain motifs... 
motifMaker find -f ${genome_name}.fasta \
    -g ${genome_name}.modified.gff \
    -j ${SLURM_CPUS_PER_TASK}\
    -o ${genome_name}.motifs.csv

echo
echo ------------------------------------------------------------------------------------------
echo Completed motif finding for: ${genome_name}. 
echo Output files are located at: ${outdir}

echo "Current date and time: $(date)"