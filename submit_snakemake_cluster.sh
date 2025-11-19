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

# Number of cores for Snakemake to use (should match -pe smp above)
CORES=40

# Conda prefix for Snakemake environments (where conda envs will be stored)
# If empty, Snakemake will use default location (.snakemake/conda)
# Example: SNAKEMAKE_CONDA_PREFIX="${HOME}/.snakemake/conda"
SNAKEMAKE_CONDA_PREFIX=""

##############################################################################
# CONDA INITIALIZATION
##############################################################################

echo "Initializing conda..."

# Initialize conda for bash shell
# This allows Snakemake to create new conda environments for rules
if [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/miniconda3/etc/profile.d/conda.sh"
elif [ -f "${HOME}/anaconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/anaconda3/etc/profile.d/conda.sh"
elif [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    source "/opt/conda/etc/profile.d/conda.sh"
else
    echo "WARNING: Could not find conda installation"
    echo "Conda environments may not work properly"
fi

echo "Conda initialized"

##############################################################################
# SETUP - Copy project to TMPDIR and run from there
##############################################################################

echo "Job started at: $(date)"
echo "Job ID: $JOB_ID"
echo "Running on node: $(hostname)"
echo "TMPDIR: ${TMPDIR}"

# Save the original submission directory
SUBMIT_DIR=$(pwd)
echo "Submission directory: ${SUBMIT_DIR}"

# Create project directory in TMPDIR
PROJECT_NAME=$(basename "${SUBMIT_DIR}")
TMPDIR_PROJECT="${TMPDIR}/${PROJECT_NAME}"

echo "Copying project to TMPDIR..."
echo "Source: ${SUBMIT_DIR}"
echo "Destination: ${TMPDIR_PROJECT}"

# Copy entire project to TMPDIR (excluding hidden files like .git, .snakemake)
mkdir -p "${TMPDIR_PROJECT}"
rsync -av \
    --exclude='.git' \
    --exclude='.snakemake' \
    --exclude='Downloads' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    "${SUBMIT_DIR}/" "${TMPDIR_PROJECT}/"

echo "Project copied successfully"

# Change to TMPDIR project directory
cd "${TMPDIR_PROJECT}"
echo "Working directory: $(pwd)"

##############################################################################
# RUN SNAKEMAKE FROM TMPDIR
##############################################################################

echo "Starting Snakemake workflow at: $(date)"

# Build snakemake command with optional conda prefix
SNAKEMAKE_CMD="snakemake --cores ${CORES} --use-conda --rerun-incomplete --printshellcmds"

if [ -n "${SNAKEMAKE_CONDA_PREFIX}" ]; then
    echo "Using conda prefix: ${SNAKEMAKE_CONDA_PREFIX}"
    SNAKEMAKE_CMD="${SNAKEMAKE_CMD} --conda-prefix ${SNAKEMAKE_CONDA_PREFIX}"
fi

# Run Snakemake from TMPDIR (Downloads will be created here)
echo "Running: ${SNAKEMAKE_CMD}"
${SNAKEMAKE_CMD}

echo "Snakemake workflow completed at: $(date)"

##############################################################################
# COPY RESULTS BACK TO SUBMISSION DIRECTORY
##############################################################################

echo "Copying results from TMPDIR to submission directory..."
echo "Source: ${TMPDIR_PROJECT}/Downloads"
echo "Destination: ${SUBMIT_DIR}/Downloads"

# Create Downloads directory in submission directory if it doesn't exist
mkdir -p "${SUBMIT_DIR}/Downloads"

# Copy Downloads directory back to submission directory
if [ -d "${TMPDIR_PROJECT}/Downloads" ]; then
    rsync -av "${TMPDIR_PROJECT}/Downloads/" "${SUBMIT_DIR}/Downloads/"
    echo "Downloads copied successfully"
else
    echo "WARNING: No Downloads directory found in TMPDIR project"
fi

# Also copy back logs
echo "Copying logs back to submission directory..."
if [ -d "${TMPDIR_PROJECT}/logs" ]; then
    rsync -av "${TMPDIR_PROJECT}/logs/" "${SUBMIT_DIR}/logs/"
    echo "Logs copied successfully"
fi

echo "File copy completed at: $(date)"

# List final files
echo "Files in final download directory:"
ls -lh "${SUBMIT_DIR}/Downloads" || echo "Downloads directory is empty or doesn't exist"

# Return to submission directory
cd "${SUBMIT_DIR}"

echo "Job completed successfully at: $(date)"
