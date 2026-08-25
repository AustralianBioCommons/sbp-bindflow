process BINDCRAFT {
    label 'process_long'

    input:
        tuple val(meta), path (target_file)
        path (pdb)
        path (filters)
        path (advanced_settings)
    
    output:
        tuple val(meta), path("*_final_design_stats.csv"), emit: stats
        tuple val(meta), path("*_output/Accepted/Ranked"), emit: accepted_ranked
        tuple val(meta), path("*_output/Accepted/*pdb"), emit: accepted,  optional: true
        tuple val(meta), path("*_output"), emit: output_dir
        tuple val(meta), path("*_output/failure_csv.csv") , emit: failure_csv
        tuple val(meta), path("*_output/final_design_stats.csv"), emit: final_design_stats
        tuple val(meta), path("*_output/mpnn_design_stats.csv"), emit: mpnn_design_stats
        tuple val(meta), path("*_output/trajectory_stats.csv"), emit: trajectory_stats
        path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def version = "1.2.0"
    def args = task.ext.args ?: ''
    
    """
    python -u /work/FreeBindCraft/bindcraft.py \\
        --settings ${target_file} \\
        --filters ${filters} \\
        --advanced ${advanced_settings} \\
        $args \\
    
    cp *_output/final_design_stats.csv ${meta.id}_${meta.batch}_final_design_stats.csv 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bindcraft: $version
    END_VERSIONS
    """

    stub:
    def version = "1.2.0"
    """
    mkdir -p s1_1_output/Accepted/Ranked
    touch s1_1_output/Accepted/accepted1.pdb
    touch s1_1_output/Accepted/Ranked/ranked1.pdb
    touch s1_1_final_design_stats.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bindcraft: $version
    END_VERSIONS
    """
}
