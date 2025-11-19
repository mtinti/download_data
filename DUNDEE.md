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

# 5. Clone the repository (this step is done only once)
git clone https://github.com/mtinti/download_data.git

# 6. Create and activate conda environment (this step is done only once)
conda create -n snakemake snakemake
# 6b. (This step is every time)
conda activate snakemake

# 7. Navigate to the repository
cd download_data
# 7b. git pull (this step is every time)

# 8. Configure the pipeline
vim config/config.yml.template  # Add your AWS credentials and bucket info to the file, save it as config/config.yml
# For this step, either use vim directly
# or open it from your shared folder (use a Mac or Linux machine; Windows might cause problems)


# 9. Run the pipeline
snakemake --use-conda --cores 10
```
## Expected outputs

Downloads/bucket_name
Downloads/checksum_validation.txt # output for md5 check
Downloads/md5_checkpoint.txt # flag md5 was succesfull
Downloads/sync_complete.txt # flag sync was successful

## Quick Vim Guide for Editing Config

When you run `vim config/config.yml.template`, follow these steps:

1. **Press `i`** - Enter INSERT mode (you'll see `-- INSERT --` at the bottom)

2. **Navigate and edit:**
   - Use arrow keys to move the cursor to the line you want to change
   - Delete the placeholder text (use Backspace or Delete)
   - Copy-paste (or type) the correct values

3. **Press `Esc`** - Exit INSERT mode (back to NORMAL mode)

4. **Save the file with a new name:**
   - Type `:w config/config.yml` and press Enter
   - This saves your edited version as `config/config.yml` (keeps the template unchanged)

5. **Quit vim:**
   - Type `:q!` and press Enter
   - This quits vim without making any changes to the template file

**Alternative workflow (if you want to save and quit in one step):**
- After step 3, type `:wq config/config.yml` and press Enter (saves as config.yml and quits)

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

