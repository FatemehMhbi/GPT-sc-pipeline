# scGPT-Flow

A scalable Nextflow pipeline for staging single-cell genomic data to AWS S3 and performing integrated Seurat analysis.

## 📌 Overview
`scGPT-Flow` automates the heavy lifting of single-cell data management. It processes raw data links, handles secure cloud uploads, and aggregates multi-sample datasets into a structured format ready for R/Seurat workflows.

## 🧬 Key Features
* **Automated Data Staging:** A robust Python-based module to download, verify, and upload raw matrix links to S3 buckets.
* **Hybrid Cloud Architecture:** Leverages S3 for persistent intermediate storage while maintaining a lightweight local footprint for analysis.
* **Integrated Seurat Workflow:** Automatically aggregates multi-sample tarballs into structured directories for seamless `Read10X` compatibility.
* **Resumability & Persistence:** Designed to resume work exactly where it left off, even across different days or environments, by utilizing Nextflow's deep caching logic.
* **Reproducibility & Portability:** Powered by **Conda** and **Nextflow DSL2**, ensuring consistent results across local machines and HPC environments.
* **Security Focused:** Built-in support for environment variables (`.env`) to keep cloud credentials and bucket names private.



## 🏗️ Architecture
The pipeline consists of three main stages:
1. **Data Staging (Python):** Downloads raw `.tar.gz` matrices from provided links and uploads them to a private AWS S3 bucket.
2. **Analysis (R/Seurat):** Discovers staged files in S3, downloads and unpacks them locally into a unified directory structure, generates Seurat objects (`.rds`), and run Seurat pipeline (saves markers and UMAPs for resolutions 0.1 to 1.0).
3. **Cell type annotation using OpenAI for the best resolution based on average silhouette width. 

## 🛠️ Installation & Setup

### Prerequisites
- [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html)
- [Conda](https://docs.conda.io/en/latest/) or Mamba
- AWS CLI configured with appropriate permissions

### Environment Configuration
This project uses a `.env` file to keep sensitive information out of version control. Create a `.env` file in the root directory:

```env
S3_BUCKET_NAME=your-private-bucket-name
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
S3_BUCKET_NAME=your_bucket_name
AWS_DEFAULT_REGION=your_region
