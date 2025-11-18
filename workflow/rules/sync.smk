import os
from pathlib import Path

from snakemake.exceptions import WorkflowError


rule sync_bucket:
    """Mirror the configured S3 bucket into the local working directory."""
    output:
        marker=str(SYNC_MARKER)
    log:
        "logs/sync_bucket.log"
    threads:
        snakemake_cfg.get("sync_threads", 1)
    conda:
        "../envs/sync.yml"
    params:
        bucket=bucket_uri,
        download_dir=str(DOWNLOAD_DIR),
        region=aws_cfg.get("region", ""),
        access_key=aws_cfg.get("access_key_id", ""),
        secret_key=aws_cfg.get("secret_access_key", ""),
        extra_args=" ".join(str(arg) for arg in aws_cfg.get("sync_extra_args", [])),
    shell:
        """
        set -e

        # Create directories
        mkdir -p {params.download_dir}
        mkdir -p $(dirname {log})

        # Export AWS credentials
        export AWS_DEFAULT_REGION="{params.region}"
        export AWS_ACCESS_KEY_ID="{params.access_key}"
        export AWS_SECRET_ACCESS_KEY="{params.secret_key}"

        # Run aws s3 sync
        aws s3 sync {params.bucket} {params.download_dir} --no-progress {params.extra_args} > {log} 2>&1

        # Create marker file with metadata
        mkdir -p $(dirname {output.marker})
        cat > {output.marker} <<EOF
S3 bucket sync completed successfully
Bucket: {params.bucket}
Download directory: {params.download_dir}
Timestamp: $(date -Iseconds)
EOF
        """
