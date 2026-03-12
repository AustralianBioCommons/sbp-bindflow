process GENERATE_REPORT {
    tag "${meta.id}"
    label 'process_single'
    conda "bioconda::multiqc=1.25"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/24/241f0746484727a3633f544c3747bfb77932e1c8c252e769640bd163232d9112/data' :
        'community.wave.seqera.io/library/biopython_matplotlib_pip_plotly:35975fa0fc54b2d3' }"

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
