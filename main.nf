nextflow.enable.dsl=2

params.project_name = "default_project"
params.tissue = "unknown"
params.species = "unknown"
params.outdir = "${launchDir}/results/${params.project_name}"

// 1. Set a default value, but this gets overwritten by your command line input
params.links_file = "" 

process PREP_DATA {
    publishDir "${params.outdir}", mode: 'copy'
    // This tells Nextflow which environment to use
    conda "${baseDir}/environment.yml"
    
    input:
    path user_file

    output:
    path "staging_complete.txt", emit: signal

    script:
    """
    python3 ${baseDir}/bin/move_data_to_S3_bucket.py \
    --links_file ${user_file} \
    --S3_dir ${params.project_name} 
    echo "Data staging complete" > staging_complete.txt
    """
}

process UNTAR_AND_SEURAT {
    debug true
    publishDir "${params.outdir}", mode: 'copy'
    conda "${projectDir}/environment.yml"

    input:
    // The 'collect' makes this a LIST of all S3 files
    path all_tar_files 

    output:
    path "seurat_output/**.{png,pdf}", emit: plots
    path "seurat_output/**/*.csv", emit: markers
    path "seurat_output/*.rds", emit: rds

    script:
    """
    mkdir -p total_data_dir
    mkdir -p seurat_output

    # Loop through every tar file and unpack it into its own subfolder
    for f in ${all_tar_files}; do
        # Create a folder name based on the filename (removing .tar.gz)
        dirname=\$(basename \$f .tar.gz)
        mkdir -p "total_data_dir/\$dirname"
        
        # Untar into that specific subfolder
        tar -xzvf \$f -C "total_data_dir/\$dirname" --strip-components=1
    done

    # pointing to the parent directory containing all folders
    Rscript ${projectDir}/bin/make_seurat_obj.R \
        --input_dir total_data_dir/ \
        --out_dir seurat_output/

    # Run Analysis
    Rscript ${projectDir}/bin/seurat_pipeline.r \
    --input_dir seurat_output/seurat_object.rds \
    --out_dir seurat_output/
    """
}


process PICK_RESOLUTION {
    publishDir "${params.outdir}", mode: 'copy'
    conda "${projectDir}/environment.yml"

    input:
    path rds_file

    output:
    path "*.txt", emit: resolution

    script:
    """
    Rscript ${projectDir}/bin/pick_resolution.r \
        --input_dir ${rds_file} \
        --out_dir .
    """
}

process ANNOTATIONS {
    publishDir "${params.outdir}", mode: 'copy'
    conda "${projectDir}/environment.yml"

    input:
    path target_csv
    val tissue   // Bridges params.tissue
    val species  // Bridges params.species

    output:
    path "*.txt", emit: annotations

    script:
    """    
    python3 ${projectDir}/bin/gpt_annotator.py \
        --input_dir ${target_csv} \
        --out_dir . \
        --tissue ${tissue} \
        --species ${species} \

    """
}   

workflow {
    // Error handling if you forget to provide the file
    if (params.links_file == "") {
        error "Usage: nextflow run main.nf --links_file <your_file.txt>"
    }

    links_ch = Channel.fromPath(params.links_file)
    PREP_DATA(links_ch)

    samples_ch = PREP_DATA.out.signal
        .collect()
        .flatMap { _ -> 
            file("s3://${params.bucket}/${params.project_name}/data/*.tar.gz") 
        }
        .collect() // THIS IS KEY: It bundles all files into a single list

    UNTAR_AND_SEURAT(samples_ch)

    // Filter the channel to only pass the 'clustered.rds' file
    target_rds = UNTAR_AND_SEURAT.out.rds
        .flatten()
        .filter { it.name =~ /clustered.rds/ }

    PICK_RESOLUTION(target_rds)

    // Flatten the marker list
    markers_flat = UNTAR_AND_SEURAT.out.markers.flatMap { it }  

    // Flatten resolutions
    res_val_flat = PICK_RESOLUTION.out.resolution.map { it.text.trim() }.flatten()

    target_csv = markers_flat
        .combine(res_val_flat)
        .filter { marker, res -> 
            marker.name.contains("Top_10_") && marker.name.contains(res)
        }
        .map { marker, res -> marker } // Correctly unpack the tuple
        
    target_csv.view { "Markers for cell type annotation: ${it.name}" }
    ANNOTATIONS(target_csv, params.tissue, params.species)

}

workflow.onComplete {
    // We use a simple if/else to avoid complex Groovy logic that might fail
    if (workflow.success) {
        println "============================================================"
        println "✅ SUCCESS: Pipeline finished for ${params.tissue}"
        println "Finished at: ${workflow.complete}"
        println "Duration   : ${workflow.duration}"
        println "============================================================"
    } else {
        println "============================================================"
        println "❌ FAILED: Pipeline stopped with an error."
        println "Exit status: ${workflow.exitStatus}"
        println "============================================================"
    }
}
