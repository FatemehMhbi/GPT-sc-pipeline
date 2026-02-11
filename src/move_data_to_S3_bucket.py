import boto3
import requests
from io import BytesIO
import os
from dotenv import load_dotenv

load_dotenv()

s3 = boto3.client(
    's3',
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=os.getenv("AWS_DEFAULT_REGION") # This should be us-east-2 for your bucket
)

#The public URL for the PBMC 3k dataset
DATA_URL = "https://github.com/chanzuckerberg/cellxgene/raw/main/example-dataset/pbmc3k.h5ad"

#Download the data into memory
print("Downloading PBMC 3k data...")
response = requests.get(DATA_URL)
data_file = BytesIO(response.content)

#Stream to S3
s3 = boto3.client('s3')
bucket_name = ''

s3.upload_fileobj(data_file, bucket_name, 'pbmc3k.h5ad')
print(f"Success! pbmc3k.h5ad is now in S3 bucket")