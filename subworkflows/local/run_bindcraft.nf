//
// Subworkflow with functionality specific to the AustralianBioCommons/sbp-bindflow pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { JSONMANAGER               } from '../../modules/local/jsonmanager'
include { samplesheetToList         } from 'plugin/nf-schema'
include { BINDCRAFT                 } from '../../modules/local/bindcraft'
include { RANKER                 } from '../../modules/local/ranker'
include { GENERATE_REPORT        } from '../../modules/local/generate_report'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow RUN_BINDCRAFT {

    take:
    input             //  string: Path to input samplesheet
    batches           //  integer: the number of batches to divid the final number of designs on to run bindcraft in parallel
    quote_char
    main:

    ch_versions = Channel.empty()
    
    input
    .splitCsv(header: true, quote : quote_char)
    .map {row ->
       [
            ["id": row.id], 
            file(row.starting_pdb, checkIfExists: true),
            get_file(row.settings_filters, params.settings_filters, "${projectDir}/assets/bindcraft/default_filters.json")
       ]
    }
    .set { ch_settings }
    input
    .splitCsv(header: true, quote : quote_char)
    .map {row ->
       [
            ["id": row.id],
            row.number_of_final_designs
       ] 
    }.set{ch_final_designs}

    JSONMANAGER(
        input,
        batches
    )

    JSONMANAGER.out.json
        .flatten()
        .map{[["id": it.baseName.split('-')[0..-2].join('-'), "batch": it.baseName.split('-')[-1].replace(".json", "")], it]}
        .join(
            JSONMANAGER.out.advanced_json
                .flatten()
                .map{
                    def stripped_base = it.baseName.replaceFirst(/-advanced$/, '')
                    [["id": stripped_base.split('-')[0..-2].join('-'), "batch": stripped_base.split('-')[-1]], it]
                }
        )
        .map{[["id": it[0].id], it[0].batch, it[1], it[2]]}
        .combine(ch_settings)
        .filter{it[0].id == it[4].id}
        .map{[["id": it[0].id, "batch": it[1]], it[2], it[5], it[6], it[3]]}
        .set {ch_bindcraft_input}
    
    BINDCRAFT(
        ch_bindcraft_input.map {[it[0], it[1]]},
        ch_bindcraft_input.map {it[2]},
        ch_bindcraft_input.map {it[3]},
        ch_bindcraft_input.map {it[4]}
    )

    BINDCRAFT.out.accepted
        .map{[["id": it[0].id], it[1]]}
        .groupTuple()
        .join(ch_final_designs, remainder: true)
        .map { [it[0], it[1] ?: [], it[2]] }
        .subscribe{
            if (it[1].size() < it[2]){
                log.warn "Sample: ${it[0].id}: The pipeline was unable to generate the target number of successful designs (${it[1].size()} of ${it[2]}) in the allocated time. Please consider changing hotspot residues or design configuration to increase design success rates"
            }
        } 

    RANKER(
        BINDCRAFT.out.stats.map{[["id": it[0].id], it[1]]}.groupTuple(),
        BINDCRAFT.out.accepted_ranked.map{[["id": it[0].id], it[1]]}.groupTuple()
    )
    
    GENERATE_REPORT(
        BINDCRAFT.out.output_dir.map{it[1]}.collect(),
        BINDCRAFT.out.failure_csv
            .map{it[1]}
            .splitCsv( header: true )
            .collect()
            .map{
                it.inject([:]) { acc, map ->
                    map.each { k, v ->
                        def num = v?.toString()?.isNumber() ? v.toBigDecimal() : 0
                        acc[k] = (acc[k] ?: 0) + num
                }
                def keys = acc.keySet().toList()
                def values = keys.collect { acc[it] }
                keys.join(',') + "\n" + values.join(',')
                }
            }.collectFile( name: "failure_csv.csv")
            ,
        RANKER.out.stats.map{it[1]},
        BINDCRAFT.out.mpnn_design_stats
        .map{it[1].text}
        .collectFile( name: "mpnn_design_stats.csv" ),
        BINDCRAFT.out.trajectory_stats
        .map{it[1].text}
        .collectFile( name: "trajectory_stats.csv" ),
        Channel.fromPath("${projectDir}/assets/bindcraft_reporting.qmd").first()
    )

    emit:
    input_json  = JSONMANAGER.out.json
                    .flatten()
                    .map{[it.baseName.split('-')[0..-2].join('-'), 
                          it.baseName.split('-')[-1].replace(".json", ""), 
                          it]
                    }
    output_dir  = BINDCRAFT.out.output_dir
    stats       = RANKER.out.stats
    ranked      = RANKER.out.accepted_ranked
    reports     = GENERATE_REPORT.out.report
    versions    = ch_versions
}

def get_file(String sheet_file, String general_file, String assets_file) {
    if (!sheet_file || sheet_file.trim().isEmpty()) {
        return general_file ? file(general_file) : file(assets_file)
    }
    
    if (!file(sheet_file).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> file does not exist!\n${sheet_file}"
    }

    return file(sheet_file)
}
