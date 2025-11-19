# Running on Dundee Cluster

This guide provides step-by-step instructions for running the S3 download pipeline on the Dundee compute cluster.

## Setup and Execution

```bash
# 1. Connect to the cluster
ssh compute.dundee.ac.uk

# 2. Start a screen session (protects against connection loss)
screen -S snakemake_job

# If connection drops, reconnect with:
# ssh compute.dundee.ac.uk
# screen -r snakemake_job

# 3. Request an interactive session with 10 cores
qrsh -pe smp 10

# 4. Navigate to your lab folder
cd /cluster/majf_lab/mtinti  # Replace with your lab folder path

# 5. Clone the repository (this is done only once
git clone https://github.com/mtinti/download_data.git

# 6. Create and activate conda environment
conda create -n snakemake snakemake
conda activate snakemake

# 7. Navigate to the repository
cd download_data
# 7b. git pull (THis is done ot fetch any updates from the git repo)

# 8. Configure the pipeline
nano config/config.yml  # Add your AWS credentials and bucket info

# 9. Run the pipeline
snakemake --use-conda --cores 10
```

## Important Notes

### Screen Session Management

Using `screen` protects your work if your SSH connection drops. Key commands:

**Inside a screen session:**
- `Ctrl+A, D` - Detach from screen (keeps it running in background)
- `Ctrl+A, K` - Kill the current screen session

**From the login node:**
```bash
screen -ls                      # List all your screen sessions
screen -r snakemake_job         # Reconnect to your named session
screen -X -S snakemake_job quit # Kill a specific session
```

### Core Allocation
Set `--cores` to be less than or equal to:
- The number of cores requested via `qrsh` (e.g., 10 in the example above)
- The total number of files to download (for optimal parallel validation)
- **Maximum recommended: 56 cores**

### Examples

## Configuration

Make sure to edit `config/config.yml` with your AWS credentials before running the pipeline. See the main [README.md](README.md) for detailed configuration options.

