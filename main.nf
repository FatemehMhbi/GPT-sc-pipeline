nextflow.enable.dsl=2

process UNTAR_AND_STAGE {
    tag "${tar_file.simpleName}"
    
    input:
    path tar_file

    output:
    path "${tar_file.simpleName}_extracted", emit: sample_folder

    script:
    """
    mkdir ${tar_file.simpleName}_extracted
    tar -xzvf ${tar_file} -C ${tar_file.simpleName}_extracted --strip-components=1
    """
}

process RUN_SEURAT {
    tag "${data_dir.name}"
    publishDir "${params.outdir}/seurat_output", mode: 'copy'

    input:
    path data_dir  // Fixed: Added missing input block to receive the folder

    output:
    // Fixed: Standardized output to a directory named 'markers' 
    // so the next process can find the files easily.
    path "markers/*.csv", emit: marker_files

    script:
    """
    # Assuming your script is in bin/ and is executable
    # We pass the directory path to the R script
    mkdir -p markers
    seurat_pipeline.R --input_dir ${data_dir} --out_dir markers
    """
}

process AI_ANNOTATION {
    tag "${marker_file.baseName}"
    publishDir "${params.outdir}/annotations", mode: 'copy'

    input:
    path marker_file

    output:
    path "${marker_file.baseName}_annotated.txt"

    script:
    """
    # Assuming your script is in bin/ and is executable
    openai_annotator.py --input ${marker_file} --output ${marker_file.baseName}_annotated.txt
    """
}

workflow {
    // 1. Channel for tar files
    tars_ch = Channel.fromPath("${params.input_dir}/*.tar.gz")

    // 2. Unzip
    UNTAR_AND_STAGE(tars_ch)

    // 3. Run Seurat (Fixed: Passed the output of the previous process)
    RUN_SEURAT(UNTAR_AND_STAGE.out.sample_folder)

    // 4. Run AI Annotation
    // Fixed: Seurat output is a list of files; flatten() ensures 
    // each CSV triggers its own Python task.
    AI_ANNOTATION(RUN_SEURAT.out.marker_files.flatten())
}