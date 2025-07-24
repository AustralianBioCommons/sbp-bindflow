process GENERATE_REPORT {
    tag "${meta.id}"
    label 'process_single'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.21--pyhdfd78af_0' :
        'biocontainers/multiqc:1.21--pyhdfd78af_0' }"
    conda "bioconda::multiqc=1.21"

    input:
    tuple val(meta), val(info)
    
    output:
    tuple val(meta), path ("*report.html"), emit: report
    
    when:
    task.ext.when == null || task.ext.when
    script:
    def args = task.ext.args ?: ''
    
    """
    echo "${info}" > ${meta.id}_report.html
    """
}
