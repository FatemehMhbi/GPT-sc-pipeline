import os
import pandas as pd
from openai import OpenAI
from dotenv import load_dotenv

# Load your .env file
load_dotenv()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def annotate_cell_type(markers, tissue):
    # Convert list of markers to a comma-separated string
    gene_list = ", ".join(markers)
    
    prompt = f"""
    Identify the most likely cell type for a cluster of {tissue} cells 
    based on the following top 10 marker genes: {gene_list}.
    
    Please follow these rules:
    1. Think step-by-step: briefly explain what cell types each key marker is associated with.
    2. Provide a single 'Final Decision' as the most probable cell type name.
    3. If it is a mixture, suggest the dominant type.
    """

    response = client.chat.completions.create(
        model="gpt-4o-mini", # Use gpt-4o for higher accuracy
        messages=[
            {"role": "system", "content": "You are a professional senior bioinformatician expert in single-cell RNA sequencing."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.1  # Low temperature = more consistent, less "creative" answers
    )
    
    return response.choices[0].message.content

# Example usage:
top_markers = ["CD3D", "CD3E", "CD4", "IL7R", "LDHB", "NOSIP", "LEF1", "CCR7", "CD27", "MAL"]
#result = annotate_cell_type(top_markers)
#print(result)

top_markers_dir = "/Users/fatemehmohebbi/Desktop/My_AI_projects/scGPT-Flow/results/markers/Top_10_markers_res_0.1.csv"
markers_df = pd.read_csv(top_markers_dir)


for name, group in markers_df.groupby('cluster'):
    print(f"Cluster number: {name}")
    #print(group)

    markers_list = group["gene"].tolist()
    print(f"Markers for cluster {name}: {markers_list}")
    results = annotate_cell_type(markers_list, "Human PBMC")
    print(f"Predicted cell type for cluster {name}: {results}\n")


#markers_df["Predicted_Cell_Type"] = markers_df["Markers"].apply(lambda x: annotate_cell_type(x.split(", ")))
#markers_df.to_csv("/Users/fatemehmohebbi/Desktop/My_AI_projects/" \
#"scGPT-Flow/results/markers/Top_10_markers_with_predictions.csv", index=False)