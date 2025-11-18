# S3 Download & Validation Pipeline

Snakemake pipeline that downloads data from an S3 bucket and validates file integrity using MD5 checksums in parallel.

## Quick Start

```bash
# 1. Setup configuration
cp config/config.yml.template config/config.yml
nano config/config.yml  # Add your AWS credentials

# 2. Run pipeline with parallel validation
snakemake --use-conda --cores 4
```

## Features

- **S3 Sync** - Downloads files from S3 bucket using AWS CLI
- **MD5 Validation** - Automatically validates all downloaded files against md5.txt checksums
- **Parallel Processing** - Validates multiple files simultaneously (configurable with `--cores`)
- **Comprehensive Reporting** - Generates detailed validation reports and logs

## Directory Structure

```
download_data/
├── Snakefile
├── config/config.yml
├── Downloads/                          # Output directory
│   ├── sync_complete.txt              # Sync completion marker
│   ├── md5_checkpoint.txt             # MD5 discovery info
│   ├── checksum_validation.txt        # Final validation report
│   └── <bucket_name>/                 # Downloaded bucket
│       ├── md5.txt                    # Source checksums
│       ├── <data_files>
│       └── validation/                # Validation metadata
│           ├── files_to_validate.txt  # List of files
│           └── *.validated            # Per-file validation markers
└── workflow/
    ├── Snakefile
    ├── rules/
    │   ├── sync.smk                   # S3 sync rule
    │   └── checksum.smk               # MD5 validation rules
    └── envs/
        └── sync.yml                   # Conda environment
```

## Configuration

### Option 1: Using Config File (Recommended for Development)

Edit `config/config.yml`:

```yaml
aws:
  bucket: "your-bucket-name"
  region: "us-east-1"
  access_key_id: "YOUR_ACCESS_KEY"
  secret_access_key: "YOUR_SECRET_KEY"
  sync_extra_args: []
download_dir: "Downloads"
validation:
  md5_filenames:
    - "md5.txt"
    - "md5sum_check.txt"
  validation_dir: "validation"
snakemake:
  sync_threads: 2
```

**⚠️ Security Note**: Never commit AWS credentials to git! Add `config/config.yml` to `.gitignore`.

### Option 2: Using Separate Config File (Recommended for Production)

Create a separate config file outside the repository:

```bash
# Create a config file with your credentials (not tracked by git)
cat > ~/my-aws-config.yml <<EOF
aws:
  bucket: "your-bucket-name"
  region: "us-east-1"
  access_key_id: "YOUR_ACCESS_KEY"
  secret_access_key: "YOUR_SECRET_KEY"
  sync_extra_args: []
download_dir: "Downloads"
validation:
  md5_filenames:
    - "md5.txt"
    - "md5sum_check.txt"
  validation_dir: "validation"
snakemake:
  sync_threads: 2
EOF

# Run pipeline with custom config
snakemake --use-conda --cores 4 --configfile ~/my-aws-config.yml
```

### Option 3: Using Environment Variables (Recommended for CI/CD)

Set AWS credentials as environment variables:

```bash
# Set environment variables
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"

# These will be automatically picked up by AWS CLI
snakemake --use-conda --cores 4
```

### Option 4: Using Command-Line Config Override

Override config values directly on the command line:

```bash
# Basic example - override individual values
snakemake --use-conda --cores 4 \
  --config download_dir="MyData"

# Full example - override AWS config (single line)
snakemake --use-conda --cores 4 --config aws="{bucket:'my-bucket-name',region:'us-east-1',access_key_id:'AKIAXXXXXXXXXXXXXXXX',secret_access_key:'your-secret-key-here'}"

# Readable multi-line version
snakemake --use-conda --cores 4 \
  --config \
    aws="{bucket:'my-bucket-name',region:'us-east-1',access_key_id:'AKIAXXXXXXXXXXXXXXXX',secret_access_key:'your-secret-key-here'}" \
    download_dir="MyData"

# Override just the bucket (keeps other config from config.yml)
snakemake --use-conda --cores 4 \
  --config aws="{bucket:'different-bucket'}"
```

**Note**: Command-line config overrides merge with `config.yml`. This is useful for:
- Quick testing with different buckets
- CI/CD pipelines with dynamic values
- Overriding specific values without editing files

### Configuration Methods Comparison

| Method | Use Case | Security | Example |
|--------|----------|----------|---------|
| **Config File** | Development | ⚠️ Can be committed by accident | `config/config.yml` |
| **Separate Config** | Production | ✅ Outside repo | `--configfile ~/aws.yml` |
| **Environment Vars** | CI/CD, Docker | ✅ No files needed | `export AWS_ACCESS_KEY_ID=...` |
| **Command Line** | Quick tests, overrides | ⚠️ Visible in shell history | `--config aws={bucket:'name'}` |

**Recommendation**: Use separate config file or environment variables for production.

### Configuration Parameters

#### AWS Configuration
- `aws.bucket` – S3 bucket name or full `s3://` URI (e.g., `"my-bucket"` or `"s3://my-bucket"`)
- `aws.region` – AWS region (e.g., `"us-east-1"`, `"eu-central-1"`)
- `aws.access_key_id` – AWS access key ID
- `aws.secret_access_key` – AWS secret access key
- `aws.sync_extra_args` – Optional extra flags for `aws s3 sync` (list of strings, e.g., `["--exclude", "*.tmp"]`)

#### Download Configuration
- `download_dir` – Output directory (defaults to `"Downloads"`)

#### Validation Configuration
- `validation.md5_filenames` – List of MD5 checksum filename patterns to search for (defaults to `["md5.txt", "md5sum_check.txt"]`)
  - Pipeline searches for files in order of priority
  - Uses the first match found
  - Common patterns: `md5.txt`, `md5sum_check.txt`, `md5sum.txt`
- `validation.validation_dir` – Validation folder name (defaults to `"validation"`)

#### Snakemake Configuration
- `snakemake.sync_threads` – Number of cores for sync job (defaults to `1`)

## Security Best Practices

### Protecting AWS Credentials

**Never commit credentials to version control!**

Add this to your `.gitignore`:
```
# AWS credentials
config/config.yml
*-config.yml
*.credentials
```

Or use a template approach:
1. Create `config/config.yml.template` with placeholder values
2. Commit the template to git
3. Copy to `config/config.yml` and add real credentials (gitignored)

```bash
# Setup
cp config/config.yml.template config/config.yml
# Edit config/config.yml with your credentials
nano config/config.yml
```

## Usage

### Basic Run (Sequential Validation)
```bash
cd download_data
snakemake --use-conda --cores 1
```

### Parallel Validation (Recommended)
```bash
# Validate up to 4 files simultaneously
snakemake --use-conda --cores 4

# Validate up to 8 files simultaneously
snakemake --use-conda --cores 8
```

### Using Custom Config File
```bash
# Use config from different location
snakemake --use-conda --cores 4 --configfile /path/to/secure-config.yml

# Use environment variables (no config file needed for credentials)
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
snakemake --use-conda --cores 4

# Override config on command line
snakemake --use-conda --cores 4 \
  --config aws="{bucket:'my-bucket',region:'us-east-1',access_key_id:'AKIAXXXX',secret_access_key:'SECRET'}"
```

## Pipeline Workflow

1. **sync_bucket** - Downloads files from S3 bucket
2. **find_md5_files** (checkpoint) - Discovers and parses md5.txt file(s)
3. **validate_file_checksum** - Validates each file's MD5 checksum (parallel)
4. **aggregate_validation_results** - Creates summary validation report

## Output Files

### Downloads/sync_complete.txt
Contains sync completion info with timestamp and bucket details.

### Downloads/md5_checkpoint.txt
Shows which MD5 file was found and lists all files with their expected checksums.
- Displays the MD5 filename pattern used (e.g., `md5.txt` or `md5sum_check.txt`)
- Shows the exact file location
- Lists all files to be validated

### Downloads/checksum_validation.txt
Final validation report showing:
- Total files validated
- Number passed/failed
- Timestamp
- Overall success/failure status

### Downloads/<bucket_name>/validation/
Contains per-file validation markers and logs.

## Logs

- `logs/sync_bucket.log` - S3 sync output
- `logs/validation/<bucket_name>/*.log` - Individual file validation logs

## Re-running the Pipeline

To force a re-sync and re-validation:
```bash
# Delete marker files
rm Downloads/sync_complete.txt

# Run pipeline
snakemake --use-conda --cores 4
```

To re-validate without re-syncing:
```bash
# Delete validation report
rm Downloads/checksum_validation.txt

# Run pipeline
snakemake --use-conda --cores 4
```

## Error Handling

The pipeline will **fail** if:
- No MD5 checksum file is found in the downloaded bucket
  - Searches for: `md5.txt`, `md5sum_check.txt` (configurable)
  - Error message shows all patterns searched
- Any file fails MD5 checksum validation
- AWS credentials are invalid
- S3 bucket is inaccessible
- Multiple buckets detected (only single bucket supported currently)

Check the logs in `logs/` directory for detailed error messages.

## MD5 File Detection

The pipeline automatically detects MD5 checksum files by searching for multiple filename patterns:
1. Searches for each pattern in priority order (defined in `config.yml`)
2. Uses the first match found
3. Reports which filename was used in `md5_checkpoint.txt`

**Example**: If a bucket contains `md5sum_check.txt` instead of `md5.txt`, the pipeline will automatically find and use it.
