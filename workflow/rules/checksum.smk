import os
from pathlib import Path
from snakemake.exceptions import WorkflowError


validation_cfg = config.get("validation", {})

# Support both old (single) and new (list) config formats
md5_filenames_config = validation_cfg.get("md5_filenames", None)
if md5_filenames_config is None:
    # Backward compatibility: check for old singular format
    md5_filenames_config = [validation_cfg.get("md5_filename", "md5.txt")]
elif not isinstance(md5_filenames_config, list):
    md5_filenames_config = [md5_filenames_config]

MD5_FILENAMES = md5_filenames_config
VALIDATION_DIR = DOWNLOAD_DIR / validation_cfg.get("validation_dir", "validation")
MD5_CHECKPOINT = DOWNLOAD_DIR / "md5_checkpoint.txt"
CHECKSUM_REPORT = DOWNLOAD_DIR / "checksum_validation.txt"


def parse_md5_file(md5_file_path):
    """Parse md5.txt file and return list of (hash, filepath) tuples."""
    entries = []
    with open(md5_file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(None, 1)  # Split on first whitespace
            if len(parts) == 2:
                md5_hash, filepath = parts
                entries.append((md5_hash, filepath))
    return entries


checkpoint find_md5_files:
    """Find and parse MD5 checksum file(s) after sync completes."""
    input:
        sync_marker=str(SYNC_MARKER)
    output:
        checkpoint_marker=str(MD5_CHECKPOINT)
    run:
        from pathlib import Path
        import hashlib

        # Search for MD5 files using all configured patterns
        md5_files = []
        pattern_used = None

        for pattern in MD5_FILENAMES:
            found_files = list(Path(str(DOWNLOAD_DIR)).rglob(pattern))
            if found_files:
                md5_files = found_files
                pattern_used = pattern
                break  # Use first matching pattern

        if not md5_files:
            searched_patterns = ", ".join(MD5_FILENAMES)
            raise WorkflowError(f"No MD5 file found in {DOWNLOAD_DIR}. Searched for: {searched_patterns}")

        # For now, assume single bucket (can be extended for multiple)
        if len(md5_files) > 1:
            raise WorkflowError(f"Multiple {pattern_used} files found. This pipeline currently supports a single bucket.")

        md5_file = md5_files[0]
        bucket_dir = md5_file.parent
        validation_dir = bucket_dir / validation_cfg.get("validation_dir", "validation")

        # Parse all md5 files and store information
        all_entries = []
        entries = parse_md5_file(md5_file)
        for md5_hash, filepath in entries:
            full_path = bucket_dir / filepath
            all_entries.append((str(full_path), md5_hash))

        # Write checkpoint info to Downloads directory
        Path(output.checkpoint_marker).parent.mkdir(parents=True, exist_ok=True)
        with open(output.checkpoint_marker, 'w') as f:
            f.write(f"MD5 filename pattern used: {pattern_used}\n")
            f.write(f"MD5 file location: {md5_file}\n")
            f.write(f"Bucket directory: {bucket_dir}\n")
            f.write(f"Validation directory: {validation_dir}\n")
            f.write(f"Total files to validate: {len(all_entries)}\n")
            f.write(f"\n")
            for filepath, md5_hash in all_entries:
                f.write(f"{md5_hash}  {filepath}\n")

        # Write file list with unique IDs to bucket's validation folder
        validation_dir.mkdir(parents=True, exist_ok=True)
        file_list_path = validation_dir / "files_to_validate.txt"
        with open(file_list_path, 'w') as f:
            for idx, (filepath, md5_hash) in enumerate(all_entries):
                # Use index as unique ID
                f.write(f"{idx}\t{md5_hash}\t{filepath}\n")


def get_bucket_validation_dir():
    """Get the bucket's validation directory from checkpoint."""
    checkpoint_file = str(MD5_CHECKPOINT)
    with open(checkpoint_file, 'r') as f:
        for line in f:
            if line.startswith("Validation directory:"):
                return Path(line.split(":", 1)[1].strip())
    raise WorkflowError("Could not find validation directory in checkpoint file")


def get_file_list_path(wildcards):
    """Get the file list path from checkpoint."""
    checkpoint_output = checkpoints.find_md5_files.get(**wildcards)
    validation_dir = get_bucket_validation_dir()
    return str(validation_dir / "files_to_validate.txt")


def get_files_to_validate(wildcards):
    """Return list of files to validate from checkpoint."""
    checkpoint_output = checkpoints.find_md5_files.get(**wildcards)

    # Get bucket directory and validation directory from checkpoint
    checkpoint_file = str(MD5_CHECKPOINT)
    bucket_dir = None
    with open(checkpoint_file, 'r') as f:
        for line in f:
            if line.startswith("Bucket directory:"):
                bucket_dir = Path(line.split(":", 1)[1].strip())
                break

    if not bucket_dir:
        raise WorkflowError("Could not find bucket directory in checkpoint file")

    # Get bucket name relative to DOWNLOAD_DIR
    bucket_name = bucket_dir.relative_to(DOWNLOAD_DIR)

    validation_dir = bucket_dir / validation_cfg.get("validation_dir", "validation")
    file_list_path = validation_dir / "files_to_validate.txt"

    validation_markers = []
    with open(file_list_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split('\t')
            if len(parts) == 3:
                idx, md5_hash, filepath = parts
                # Use the wildcard pattern with bucket_dir
                marker_path = str(DOWNLOAD_DIR / bucket_name / "validation" / f"{idx}.validated")
                validation_markers.append(marker_path)

    return validation_markers


rule validate_file_checksum:
    """Validate MD5 checksum for a single file."""
    input:
        file_list=get_file_list_path
    output:
        validation_marker=str(DOWNLOAD_DIR) + "/{bucket_dir}/validation/{file_id}.validated"
    log:
        "logs/validation/{bucket_dir}/{file_id}.log"
    conda:
        "../envs/sync.yml"
    shell:
        """
        set -e

        # Read the file info from the file list
        FILE_INFO=$(grep "^{wildcards.file_id}\t" {input.file_list})

        if [ -z "$FILE_INFO" ]; then
            echo "ERROR: No entry found for file ID {wildcards.file_id}" > {log}
            exit 1
        fi

        # Parse the line: ID, hash, filepath
        EXPECTED_HASH=$(echo "$FILE_INFO" | cut -f2)
        FILE_PATH=$(echo "$FILE_INFO" | cut -f3)

        # Create log directory
        mkdir -p $(dirname {log})

        # Compute actual hash
        echo "Validating: $FILE_PATH" > {log}
        echo "Expected MD5: $EXPECTED_HASH" >> {log}

        if [ ! -f "$FILE_PATH" ]; then
            echo "ERROR: File not found: $FILE_PATH" >> {log}
            exit 1
        fi

        ACTUAL_HASH=$(md5sum "$FILE_PATH" | awk '{{print $1}}')
        echo "Actual MD5: $ACTUAL_HASH" >> {log}

        # Compare hashes
        if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
            echo "SUCCESS: Checksum matches" >> {log}
            mkdir -p $(dirname {output.validation_marker})
            echo "MD5 validation passed" > {output.validation_marker}
            echo "File: $FILE_PATH" >> {output.validation_marker}
            echo "Hash: $ACTUAL_HASH" >> {output.validation_marker}
        else
            echo "ERROR: Checksum mismatch!" >> {log}
            echo "Expected: $EXPECTED_HASH" >> {log}
            echo "Got: $ACTUAL_HASH" >> {log}
            exit 1
        fi
        """


rule aggregate_validation_results:
    """Aggregate all validation results into a summary report."""
    input:
        checkpoint_marker=str(MD5_CHECKPOINT),
        validation_markers=get_files_to_validate
    output:
        report=str(CHECKSUM_REPORT)
    run:
        from datetime import datetime
        from pathlib import Path

        total_files = len(input.validation_markers)
        passed = 0
        failed = 0

        # Count successful validations
        for marker in input.validation_markers:
            if Path(marker).exists():
                passed += 1
            else:
                failed += 1

        # Write summary report
        with open(output.report, 'w') as f:
            f.write("=" * 60 + "\n")
            f.write("MD5 CHECKSUM VALIDATION REPORT\n")
            f.write("=" * 60 + "\n\n")
            f.write(f"Total files validated: {total_files}\n")
            f.write(f"Passed: {passed}\n")
            f.write(f"Failed: {failed}\n")
            f.write(f"Timestamp: {datetime.now().isoformat()}\n\n")

            if failed > 0:
                f.write("ERROR: Some files failed validation!\n")
                raise WorkflowError(f"{failed} file(s) failed MD5 validation")
            else:
                f.write("SUCCESS: All files validated successfully!\n")
