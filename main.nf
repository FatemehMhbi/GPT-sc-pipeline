nextflow.enable.dsl=2

// 1. Set a default value, but this gets overwritten by your command line input
params.links_file = "" 

process PREP_DATA {
    // This tells Nextflow which environment to use
    conda "${baseDir}/environment.yml"
    
    input:
    path user_file

    output:
    path "staging_complete.txt", emit: signal

    script:
    """
    python3 ${baseDir}/bin/move_data_to_S3_bucket.py --links_file ${user_file}
    """
}

process UNTAR_AND_SEURAT {
    conda "${projectDir}/environment.yml"
    publishDir "${params.outdir}", mode: 'copy'

    input:
    // The 'collect' makes this a LIST of all S3 files
    path all_tar_files 

    output:
    path "seurat_output/*.rds"

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
            file("s3://${params.bucket}/seurat_project_files/data/*.tar.gz") 
        }
        .collect() // THIS IS KEY: It bundles all files into a single list

    UNTAR_AND_SEURAT(samples_ch)
}

