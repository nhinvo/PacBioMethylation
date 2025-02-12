#!/usr/bin/env bash
#SBATCH --job-name=SequellII_SMRTTools_motif_finding
#SBATCH --time 5-0                     
#SBATCH -p sched_mit_chisholm               # partition selection
#SBATCH -c 5                                # tasks (essentially threads)
#SBATCH -N 1
#SBATCH --mem 5G
#SBATCH --array=29,30%2
#SBATCH --exclude=node422,node295
#SBATCH -o logs/%a.%j.out
#SBATCH -e logs/%a.%j.err

# Purpose: to obtain motifs from PacBio Sequel II read files. 

echo "Current date and time: $(date)"

### Obtain data from sample.tsv file ### 
# Reference genome data (assembled from raw PacBio reads)
genome_name=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_SequelII_input.tsv | cut -f1 | tr -d '\r')
genome_path=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_SequelII_input.tsv | cut -f2 | tr -d '\r')

# Metadata about the files 
batch=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_SequelII_input.tsv | cut -f3 | tr -d '\r')
barcode=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_SequelII_input.tsv | cut -f4 | tr -d '\r')
genus=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_SequelII_input.tsv | cut -f5 | tr -d '\r')

# Raw read .xml paths 
read_filename=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_SequelII_input.tsv | cut -f6 | tr -d '\r')
subreadset_xml_fpath=$(sed "${SLURM_ARRAY_TASK_ID}q;d" data/SMRTTools_SequelII_input.tsv | cut -f7 | tr -d '\r')

### Output dir for SMRT Tools Analysis ##
outdir=data/SMRTToolsOutput/${batch}/${barcode}/${genus}

# remove dir if already exist 
if [ -d "$outdir" ]; then
    rm -rf ${outdir}  
fi

# remake output dir 
mkdir -p ${outdir}
cd ${outdir}

### Add SMRT Tools to PATH ###
export PATH="/home/kve/bin/smrtlink/smrtcmds/bin:$PATH"

### Generate index for reference fasta file ###
echo
echo ------------------------------------------------------------------------------------------
echo Copying reference fasta from path: ${genome_path}
cp ${genome_path} ${genome_name}.fasta

echo Indexing Ref Fasta file: ${genome_name}.fasta
samtools --version | head
samtools faidx ${genome_name}.fasta

### Obtain IPD Information ###
echo 
echo ------------------------------------------------------------------------------------------
echo Running ccs with --hifi-kinetics to obtain IPD for PacBio file: ${subreadset_xml_fpath}
ccs --version 
ccs --hifi-kinetics --num-threads ${SLURM_CPUS_PER_TASK} ${subreadset_xml_fpath} ${barcode}.consensusreadset.xml

### Add kinetics info ###
echo
echo ------------------------------------------------------------------------------------------
echo adding kinetics info to ccs...
ccs-kinetics-bystrandify --num-threads ${SLURM_CPUS_PER_TASK} ${barcode}.consensusreadset.xml ${barcode}.ccs.kinetics.bam

### Align reads to assembled reference ###
echo
echo ------------------------------------------------------------------------------------------
echo Running pmn2 alignment ...

# Read alignment 
pbmm2 --version 
pbmm2 align --sort --preset CCS \
    --num-threads ${SLURM_CPUS_PER_TASK} \
    ${genome_name}.fasta ${barcode}.ccs.kinetics.bystrand.bam ${barcode}.aligned.bam \
    
# Index aligned reads 
echo indexing aligned bam file 
pbindex ${barcode}.aligned.bam --num-threads ${SLURM_CPUS_PER_TASK}

### Run ipd Summary to obtain motif gff file ###
echo
echo ------------------------------------------------------------------------------------------
echo Running ipdSummary to obtain motif.gff files ... 
ipdSummary --version
ipdSummary ${barcode}.aligned.bam \
    --reference ${genome_name}.fasta \
    --numWorkers ${SLURM_CPUS_PER_TASK} \
    --pvalue 0.05 \
    --identify m6A,m4C,m5C_TET \
    --gff ${barcode}.modified.gff

### motifMaker to obtain motifs ### 
echo
echo ------------------------------------------------------------------------------------------
echo Running motifMaker to obtain motifs... 
motifMaker find -f ${genome_name}.fasta \
    -g ${barcode}.modified.gff \
    -j ${SLURM_CPUS_PER_TASK}\
    -o ${barcode}.motifs.csv

echo
echo ------------------------------------------------------------------------------------------
echo Completed motif finding for: ${read_filename}. 
echo Output files are located at: ${outdir}

echo "Current date and time: $(date)"