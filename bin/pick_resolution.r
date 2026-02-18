#!/usr/bin/env Rscript
library(cluster)
library(Seurat)
library(optparse)

option_list <- list(
    make_option(c("-i", "--input_dir"), type="character", help="Input directory")
    )

resolutions <- seq(0.1, 1.0, by = 0.1)
avg_purity <- c()

seurat_obj <- readRDS(opt$input_dir)

# 1. Identify your resolution columns
res_cols <- grep("RNA_snn_res\\.", colnames(seurat_obj@meta.data), value = TRUE)

# 2. Get the Distance Matrix from PCA (Top 20 PCs)
# This is much faster and more stable than raw counts
pc_dist <- dist(Embeddings(seurat_obj, "pca")[, 1:20])

# 3. Calculate Average Silhouette Width for each resolution
sil_results <- sapply(res_cols, function(col) {
  clusters <- as.numeric(as.factor(seurat_obj[[col, drop = TRUE]]))
  
  # Silhouette needs at least 2 clusters to work
  if(length(unique(clusters)) < 2) return(0)
  
  ss <- silhouette(clusters, pc_dist)
  return(mean(ss[, 3])) # Average width: higher is better
})

# 4. Find the 'Best' resolution name
best_res_name <- names(which.max(sil_results))

# 5. Output ONLY the string for Nextflow/Python
# Example: "RNA_snn_res.0.6"
cat(best_res_name)