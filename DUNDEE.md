# Running on Dundee Cluster

This guide provides step-by-step instructions for running the S3 download pipeline on the Dundee compute cluster.

## Setup and Execution

```bash
# 1. Connect to the cluster
ssh compute.dundee.ac.uk

# 2. Request an interactive session with 10 cores
qrsh -pe smp 10

# 3. Navigate to your lab folder
cd /cluster/majf_lab/mtinti  # Replace with your lab folder path

# 4. Clone the repository
git clone https://github.com/mtinti/download_data.git

# 5. Create and activate conda environment
conda create -n snakemake snakemake
conda activate snakemake

# 6. Navigate to the repository
cd download_data

# 7. Configure the pipeline
nano config/config.yml  # Add your AWS credentials and bucket info

# 8. Run the pipeline
snakemake --use-conda --cores 10
```

## Important Notes

### Core Allocation
Set `--cores` to be less than or equal to:
- The number of cores requested via `qrsh` (e.g., 10 in the example above)
- The total number of files to download (for optimal parallel validation)
- **Maximum recommended: 56 cores**

### Examples

## Configuration

Make sure to edit `config/config.yml` with your AWS credentials before running the pipeline. See the main [README.md](README.md) for detailed configuration options.

