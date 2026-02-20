#!/usr/bin/env Rscript
library(Seurat)
library(optparse)

# This script reads in the raw count matrices from multiple samples
# The input directory should contain subdirectories for each sample, and within those, 
# the 10x Genomics output files (matrix.mtx.gz, features.tsv.gz, barcodes.tsv.gz)
# The output is a single Seurat object saved as an RDS file for downstream analysis.
option_list <- list(
  make_option(c("-i", "--input_dir"), type="character", help="Input directory"),
  make_option(c("-o", "--out_dir"), type="character", help="Output directory")
)

opt <- parse_args(OptionParser(option_list=option_list))

sample_dirs <- list.dirs(opt$input_dir, recursive = FALSE)

seurat_list <- list()

for (s in sample_dirs) {
  donor_id <- basename(s)

  # DYNAMIC SEARCH: Find where 'matrix.mtx.gz' is hiding inside this donor folder
  # recursive = TRUE lets us search through all sub-levels
  matrix_file <- list.files(path = s, 
                            pattern = "matrix.mtx(\\.gz)?$", 
                            recursive = TRUE, 
                            full.names = TRUE)


  if (length(matrix_file) > 0) {
    # Get the directory name containing that file
    # We take [1] just in case there are multiple (e.g. raw and filtered)
    target_dir <- dirname(matrix_file[1])
    
    message("Success: Found 10x data for ", donor_id, " in: ", target_dir)
    
    counts <- Read10X(data.dir = target_dir)

    obj <- CreateSeuratObject(counts = counts, project = donor_id)
    
    # OPTIONAL: Explicitly add a donor column to be safe
    obj$sample <- donor_id
    
    seurat_list[[donor_id]] <- obj
  } else {
    warning("Failure: Could not find matrix.mtx.gz inside ", s)
  }
}

# Merge all samples into one generic object
if (length(seurat_list) > 1) {
  combined_obj <- merge(x = seurat_list[[1]], y = seurat_list[-1], add.cell.ids = names(seurat_list))
} else {
  combined_obj <- seurat_list[[1]]
}

saveRDS(combined_obj, file = paste0(opt$out_dir, "/seurat_object.rds"))
message("Seurat object created and saved successfully at: ", paste0(opt$out_dir, "/seurat_object.rds"))