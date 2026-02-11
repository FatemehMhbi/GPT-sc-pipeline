import os
import pandas as pd
from dotenv import load_dotenv
from openai import OpenAI

# 1. Load your .env secrets
load_dotenv()

# 2. Setup the AI Client
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# 3. Simple Test: Let's use Pandas to create a tiny "Gene List"
data = {'Gene': ['TP53', 'BRCA1', 'EGFR'], 'Role': ['Tumor Suppressor', 'DNA Repair', 'Growth Factor']}
df = pd.DataFrame(data)

print("--- GENE TABLE LOADED ---")
print(df)

# 4. Ask the AI to explain the first gene
gene_to_ask = df.iloc[0]['Gene']
response = client.chat.completions.create(
  model="gpt-4o-mini",
  messages=[{"role": "user", "content": f"Briefly explain the clinical significance of {gene_to_ask}."}]
)

print(f"\n--- AI INSIGHT FOR {gene_to_ask} ---")
print(response.choices[0].message.content)