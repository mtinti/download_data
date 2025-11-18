configfile: "config/config.yml"

include: "workflow/Snakefile"

rule all:
    input:
        report=str(CHECKSUM_REPORT)
