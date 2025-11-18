# Cluster Submission Instructions

## Overview

The `submit_snakemake_cluster.sh` script runs the Snakemake workflow on the cluster using TMPDIR for downloads, then copies results back to the final `Downloads` directory.

## Before Submitting

### 1. Adjust Resource Requirements

Edit `submit_snakemake_cluster.sh` and modify these SGE directives based on your workflow needs:

```bash
#$ -adds l_hard local_free 200G    # Adjust local disk space needed
#$ -mods l_hard m_mem_free 20G     # Adjust memory per core
#$ -pe smp 40                       # Adjust number of cores
#$ -N snakemake_download            # Change job name if desired
#$ -o snakemake_download_errors_$JOB_ID  # Change error log filename
```

**Important**:
- Set `local_free` based on expected download size (default: 200G)
- Set `m_mem_free` based on memory requirements (default: 20G per core)
- Set `smp` to number of parallel downloads/cores (default: 40)
- Update the `CORES` variable in the script to match `-pe smp`

### 2. Update Configuration Variables

In the script, update these variables if needed:

```bash
DOWNLOAD_DIR="Downloads"   # Final destination directory
CORES=40                   # Should match -pe smp value
```

## Submitting the Job

### Basic Submission

From the workflow directory:

```bash
qsub submit_snakemake_cluster.sh
```

### Check Job Status

```bash
qstat                      # View all your jobs
qstat -j <job_id>         # View detailed info for specific job
```

### Monitor Progress

```bash
# Watch the error/output log (filename shown when job is submitted)
tail -f snakemake_download_errors_<JOB_ID>
```

## How It Works

1. **TMPDIR Setup**: Creates temporary download directory in `$TMPDIR` (fast local disk on compute node)

2. **Snakemake Override**: Runs Snakemake with `--config download_dir="${TMP_DOWNLOAD_DIR}"` to redirect downloads to TMPDIR

3. **Copy Back**: After successful completion, copies all files from TMPDIR to final `Downloads` directory

4. **User Visibility**: The user still sees `:Downloads` bucket in the directory as expected

## Troubleshooting

### Job Fails Before Copy

If the job fails during Snakemake execution, files remain in TMPDIR and are lost. Check logs to identify the issue.

### Insufficient TMPDIR Space

If downloads exceed `local_free` allocation:
- Increase `#$ -adds l_hard local_free` value
- Monitor with `df -h $TMPDIR` during job execution

### Memory Issues

If job is killed due to memory:
- Increase `#$ -mods l_hard m_mem_free` value
- Reduce `#$ -pe smp` cores and `CORES` variable

## Advanced Usage

### Using a Config File

Uncomment the alternative snakemake command in the script:

```bash
snakemake \
    --cores ${CORES} \
    --configfile ${CONFIG_FILE} \
    --config download_dir="${TMP_DOWNLOAD_DIR}" \
    --rerun-incomplete \
    --printshellcmds
```

### Adding Additional Snakemake Options

Add any snakemake flags you need to the snakemake command, for example:

```bash
snakemake \
    --cores ${CORES} \
    --config download_dir="${TMP_DOWNLOAD_DIR}" \
    --rerun-incomplete \
    --printshellcmds \
    --use-conda \
    --conda-prefix /path/to/conda/envs
```
