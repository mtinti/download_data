#!/bin/bash
#$ -adds l_hard local_free 200G
#$ -mods l_hard m_mem_free 20G
#$ -adds l_hard avx 1
#$ -cwd
#$ -V
#$ -j y
#$ -N snakemake_download
#$ -o snakemake_download_errors_$JOB_ID
#$ -pe smp 40

# Exit on error and undefined variables
set -e
set -u

##############################################################################
# CONFIGURATION - UPDATE THESE VARIABLES AS NEEDED
##############################################################################

# Original download directory (where files should end up)
DOWNLOAD_DIR="Downloads"

# Snakemake configuration file (if using)
# CONFIG_FILE="config.yaml"

# Number of cores for Snakemake to use (should match -pe smp above)
CORES=40

##############################################################################
# TMPDIR SETUP - Automatic handling of temporary directory
##############################################################################

echo "Job started at: $(date)"
echo "Job ID: $JOB_ID"
echo "Running on node: $(hostname)"
echo "TMPDIR: ${TMPDIR}"

# Create temporary download directory in TMPDIR
TMP_DOWNLOAD_DIR="${TMPDIR}/Downloads"
mkdir -p "${TMP_DOWNLOAD_DIR}"

echo "Created temporary download directory: ${TMP_DOWNLOAD_DIR}"

# Create the actual download directory if it doesn't exist
mkdir -p "${DOWNLOAD_DIR}"

##############################################################################
# RUN SNAKEMAKE WITH TMPDIR OVERRIDE
##############################################################################

echo "Starting Snakemake workflow at: $(date)"

# Run Snakemake with download directory override
# The --config flag overrides the download_dir parameter
snakemake \
    --cores ${CORES} \
    --config download_dir="${TMP_DOWNLOAD_DIR}" \
    --rerun-incomplete \
    --printshellcmds

# Alternative if using a config file:
# snakemake \
#     --cores ${CORES} \
#     --configfile ${CONFIG_FILE} \
#     --config download_dir="${TMP_DOWNLOAD_DIR}" \
#     --rerun-incomplete \
#     --printshellcmds

echo "Snakemake workflow completed at: $(date)"

##############################################################################
# COPY FILES BACK FROM TMPDIR TO FINAL LOCATION
##############################################################################

echo "Copying files from TMPDIR to final location..."
echo "Source: ${TMP_DOWNLOAD_DIR}"
echo "Destination: ${DOWNLOAD_DIR}"

# Copy all files from temporary directory to final directory
# Using -a to preserve attributes and -v for verbose output
cp -av "${TMP_DOWNLOAD_DIR}"/* "${DOWNLOAD_DIR}"/

echo "File copy completed at: $(date)"

# List final files
echo "Files in final download directory:"
ls -lh "${DOWNLOAD_DIR}"

echo "Job completed successfully at: $(date)"
