process GENERATE_REPORT {
    tag "all-run"
    label 'process_single'
    container 'ghcr.io/australian-protein-design-initiative/containers/nf-binder-design-utils:0.1.5'

    input:
    // Stage all batch result directories under ./batches/{n}/
    // Note the {n} in this case is a list index and may not match the batch_id
    // For the purposes of generating aggregate stats, the batch_id is not important
    path ('batches/*')
    path('failure_csv.csv')
    path('final_design_stats.csv')
    path('mpnn_design_stats.csv')
    path('trajectory_stats.csv')
    path (qmd_template)

    output:
    path('bindcraft_report.html'), emit: report

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    export XDG_CACHE_HOME="./.cache"
    export XDG_DATA_HOME="./.local/share"
    export JUPYTER_RUNTIME_DIR="./.jupyter"
    export XDG_RUNTIME_DIR="/tmp"

    quarto render ${qmd_template} \\
    --execute-dir \${PWD} \\
    --output - > bindcraft_report.html
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quarto: \$(quarto --version)
    END_VERSIONS
    """

    stub:
    """
    
    touch bindcraft_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quarto: \$(quarto --version)
    END_VERSIONS
    """
}
