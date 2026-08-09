process JSONMANAGER {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    path samplesheet
    val batches

    output:
    path "target_json/*.json"  , emit: json
    path "advanced_json/*.json", emit: advanced_json
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def quote_char = task.ext.args2 ?: "\""
    def default_advanced = params.settings_advanced ?: "${projectDir}/assets/bindcraft/default_4stage_multimer.json"
    """
    #!/usr/bin/env python3
    import csv
    import json
    import os, sys
    import math

    sample_dir = os.path.dirname(os.path.abspath("${samplesheet}"))
    os.makedirs("target_json", exist_ok=True)
    os.makedirs("advanced_json", exist_ok=True)

    def resolve_path(raw_path):
        if not raw_path:
            return raw_path
        if os.path.isabs(raw_path):
            return raw_path
        candidate = os.path.join(sample_dir, raw_path)
        return candidate if os.path.exists(candidate) else raw_path

    with open("${samplesheet}", 'r') as csvfile:
        reader = csv.DictReader(csvfile, quotechar="\\${quote_char}")
        for row in reader:
            batches = ${batches}
            if batches < 1:
                batches = 1
            sample_id = row['id']
            if 'starting_pdb' in row:
                row['starting_pdb_path'] = row['starting_pdb']
                row['starting_pdb'] = os.path.basename(row['starting_pdb'])
            row['lengths'] = [int(row['min_length']), int(row['max_length'])]
            number_of_final_designs = int(row['number_of_final_designs'])
            max_trajectories = int(row['max_trajectories'])
            if batches > max_trajectories:
                batches = max_trajectories

            settings_advanced = (row.get('settings_advanced') or '').strip()
            if not settings_advanced:
                settings_advanced = "${default_advanced}"
            settings_advanced = resolve_path(settings_advanced)
            with open(settings_advanced, 'r') as advanced_file:
                advanced_template = json.load(advanced_file)
            
            max_trajectories_per_batch = math.ceil(max_trajectories / batches)
            number_of_final_designs_per_batch = math.ceil(number_of_final_designs / batches)
            row['number_of_final_designs'] = number_of_final_designs_per_batch
            row.pop('max_trajectories', None)
            for batch_id in range(0, batches):
                if batch_id == batches - 1:
                    row['number_of_final_designs'] = number_of_final_designs - batch_id * number_of_final_designs_per_batch
                row['design_path'] = f"{sample_id}_{batch_id}_output"
                with open(f"target_json/{sample_id}-{batch_id}.json", 'w') as jsonfile:
                    json.dump(row, jsonfile, indent=2)

                advanced_settings = dict(advanced_template)
                advanced_settings['max_trajectories'] = max_trajectories_per_batch
                if batch_id == batches - 1:
                    advanced_settings['max_trajectories'] = max_trajectories - batch_id * max_trajectories_per_batch
                with open(f"advanced_json/{sample_id}-{batch_id}-advanced.json", 'w') as advanced_json_file:
                    json.dump(advanced_settings, advanced_json_file, indent=2)
        
    with open ("versions.yml", "w") as version_file:
	    version_file.write("\\"${task.process}\\":\\n    python: {}\\n".format(sys.version.split()[0].strip()))
    """

    stub:
    """
    mkdir -p target_json advanced_json
    touch target_json/s1-0.json
    touch target_json/s1-1.json
    touch advanced_json/s1-0-advanced.json
    touch advanced_json/s1-1-advanced.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
