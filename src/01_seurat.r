library(ggplot2)
library(Seurat)
library(dplyr)
library(tidyr)
library(harmony)
library(Matrix)
library(optparse)


# Function to identify markers for each cluster at different resolutions and save the results as CSV files
identify_and_save_markers <- function(obj, results_dir, res) {

    outpath <- paste0(results_dir, "/markers")
    if (!dir.exists(outpath)) {
    dir.create(outpath)
    }

    # Join the RNA assay layers to ensure all data is in a single layer for marker identification
    obj[["RNA"]] <- JoinLayers(obj[["RNA"]])

    for (r in res) {
    Idents(obj) <- paste0("RNA_snn_res.", r)
    
    # Find all markers for the current resolution
    all_markers <- FindAllMarkers(
        obj, 
        min.pct = 0.25, 
        logfc.threshold = 0.25, 
        only.pos = TRUE)
    
    # Keep only adjusted p < 0.05
    significant_markers <- all_markers[all_markers$p_val_adj < 0.05, ]
    write.csv(
        significant_markers, 
        file = paste0(outpath, "/All_markers_res_", r, ".csv"), 
        row.names = FALSE)
    
    top_10 <- significant_markers %>% group_by(cluster) %>% slice_max(order_by = avg_log2FC, n = 10)
    write.csv(top_10, file = paste0(outpath, "/Top_10_markers_res_", r, ".csv"),row.names = FALSE)
    }
}

# Function to identify clusters for different resolutions and visualize UMAPs for each resolution and batch effects
identify_clusters_and_visualize_umaps <- function(obj, results_dir, res) {

    outpath <- paste0(results_dir, "/UMAP_plots")
    if (!dir.exists(outpath)) {
    dir.create(outpath)
    }

    # Cluster the data at multiple resolutions and visualize UMAPs for each resolution
    for (r in res) {
        obj <- FindClusters(obj, resolution = r)
        message("Identified clusters at resolution: ", r)
        dimplot <- DimPlot(
            obj, 
            reduction = "umap_harmony", 
            group.by = paste0("RNA_snn_res.", r))

        ggsave(
            filename = paste0(outpath, "/umap_clusters_res_", r, ".pdf"), 
            plot = dimplot, 
            width = 7, 
            height=7)
    }

    # Visutalize batch effects
    dimplot_batch <- DimPlot(
        obj, 
        reduction = "umap_harmony", 
        group.by = "orig.ident") 
    ggsave(
        filename = paste0(outpath, "/umap_batch_effects.pdf"), 
        plot = dimplot_batch, 
        width = 7, 
        height=7)  

    return(obj)
}

# Function to process raw counts, perform quality control, and filter the data
process_raw_counts <- function(data_dir, results_dir) {
    # Load the data
    obj <- readRDS(data_dir)

    # quality control metrics 
    obj[["percent.mt"]] <- PercentageFeatureSet(
        obj, 
        pattern = "^[Mm][Tt]-")

    Idents(obj) <- "orig.ident"
    VlnPlot <- VlnPlot(
        obj, 
        features = c("nFeature_RNA", "nCount_RNA", "percent.mt"), 
        pt.size = 0, 
        ncol = 3, 
        raster = FALSE, 
        layer = "counts") &
    theme(axis.text.x = element_text(size = 6))

    ggsave(
        filename = paste0(results_dir, "/vlnplot_qc_metrics.pdf"), 
        plot = VlnPlot, 
        width = 14, 
        height=7)
    

    # Filter the data based on quality control metrics
    obj_filtered <- subset(
        obj, 
        subset = nFeature_RNA > 200 & nFeature_RNA < 2000 & nCount_RNA < 5000 & percent.mt < 5)

    return(obj_filtered)
}

pick_number_of_pcs <- function(obj){
    # Calculate the percentage of total standard deviation for each PC
    stdevs <- obj[["pca"]]@stdev
    percent_stdev <- (stdevs / sum(stdevs)) * 100

    # Calculate the difference (drop) between consecutive PCs
    # This tells us how much "gain" we lose by moving to the next PC
    stdev_drop <- abs(diff(stdevs))

    # --- CRITERIA 1: PC SD is less than 5% of the total SD ---
    cutoff_5percent <- which(percent_stdev < 5)[1]

    # --- CRITERIA 2: The "Drop" is less than a threshold (e.g., 0.05) ---
    # We find the first PC where the improvement to the next PC is negligible
    drop_threshold <- 0.05
    cutoff_drop <- which(stdev_drop < drop_threshold)[1]

    # number of pcs: Usually the larger of the two to ensure signal retention
    recommended_pcs <- max(cutoff_5percent, cutoff_drop, na.rm = TRUE)

    message("Recommended number of PCs to use: ", recommended_pcs)
    return(recommended_pcs)
}

# Function to perform standard Seurat workflow with Harmony for batch correction
seurat_pipeline_with_harmony <- function(data_dir, results_dir) {
    # Process raw counts, perform quality control, and filter the data
    seurat_obj_filtered <- process_raw_counts(data_dir, results_dir)
    message("Completed quality control and filtering. Proceeding with Seurat workflow...")

    # Perform standard Seurat workflow: normalization, variable feature selection, scaling, PCA, and elbow plot
    seurat_obj_filtered <- NormalizeData(seurat_obj_filtered)
    seurat_obj_filtered <- FindVariableFeatures(
        seurat_obj_filtered, 
        selection.method = "vst", 
        nfeatures = 2000)

    seurat_obj_filtered <- ScaleData(seurat_obj_filtered)
    seurat_obj_filtered <- RunPCA(
        seurat_obj_filtered, 
        features = VariableFeatures(seurat_obj_filtered))

    elbow_plot <- ElbowPlot(seurat_obj_filtered, ndims = 50)
    ggsave(
        filename = paste0(results_dir, "/elbow_plot.pdf"), 
        plot = elbow_plot, 
        width = 7, 
        height=7)

    # Run Harmony for batch correction and clustering at multiple resolutions
    pc_dims <- 1:pick_number_of_pcs(seurat_obj_filtered)
    seurat_obj_filtered <- RunHarmony(
        seurat_obj_filtered, 
        orig.reduction = "pca", 
        new.reduction = "harmony", 
        group.by.vars = "orig.ident")
    message("Completed Harmony batch correction. Proceeding with UMAP and clustering using the Harmony reduction...")

    # Run UMAP and FindNeighbors using the Harmony reduction
    seurat_obj_filtered <- RunUMAP(
        seurat_obj_filtered, 
        dims = pc_dims, 
        reduction="harmony", 
        reduction.name = "umap_harmony")
    
    # Use the Harmony reduction for clustering to ensure batch effects are accounted for in the neighbor graph
    seurat_obj_filtered <- FindNeighbors(
        seurat_obj_filtered, 
        reduction = "harmony", 
        dims = pc_dims)

    seurat_obj_filtered <- identify_clusters_and_visualize_umaps(seurat_obj_filtered, results_dir, seq(0.1, 1.0, by = 0.1)) %>% 
        identify_and_save_markers(results_dir, seq(0.1, 1.0, by = 0.1))
    
    # Save the final Seurat object 
    saveRDS(
        seurat_obj_filtered, 
        file = paste0(results_dir, "/seurat_obj_clustered.rds"))
    message("Saved clustered Seurat object to: ", paste0(results_dir, "/seurat_obj_clustered.rds"))
    #return(seurat_obj_filtered)
}


# --- The "Main" Block ---
#main <- function() {

    #option_list <- list(
    #    make_option(c("-i", "--input"), type="character", help="Input directory")
    #)
    #opt <- parse_args(OptionParser(option_list=option_list))
    
    message("Running pipeline in execution mode...")
  
    data_dir <- "/Users/fatemehmohebbi/Desktop/My_AI_projects/single_cell_analysis_v0/data/raw_dataseurat_object.rds"
    results_dir <- "/Users/fatemehmohebbi/Desktop/My_AI_projects/single_cell_analysis_v0/results"

    if (!dir.exists(results_dir)) {
    dir.create(results_dir)
    }

    # Run the Seurat pipeline with Harmony for batch correction and clustering
    seurat_pipeline_with_harmony(data_dir, results_dir) 

    message("Analysis Complete.")
#}


#main()
#if (sys.nframe() == 0) {
#  main()
#}


