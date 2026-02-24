#!/usr/bin/env python3
import boto3
import requests
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
import os
from dotenv import load_dotenv
import argparse
from itertools import repeat

load_dotenv() # Load AWS credentials and bucket name from .env file

s3 = boto3.client(
    's3',
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=os.getenv("AWS_DEFAULT_REGION") # This should be us-east-2 for your bucket
)

def load_urls(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f if line.strip()]

def fetch_url(url, s3_dir):
    try:
        # 10s timeout is a safe bet for 80 URLs
        print("Downloading data...")
        response = requests.get(url, timeout=10)
        
        #Download the data into memory
        print(f"Downloaded data of size: {len(response.content)} bytes")
        data_file = BytesIO(response.content)
        print("Data is ready to be uploaded to S3.")

        #Stream to S3
        s3 = boto3.client('s3')
        bucket_name = os.getenv("S3_BUCKET_NAME")

        s3.upload_fileobj(data_file, bucket_name, f'{s3_dir}/data/{os.path.basename(url)}')
        print(f"Success! {os.path.basename(url)} is now in S3 bucket")
        return f"{url},Success"
    except Exception as e:
        return f"{url},Error"


# The input is a txt file that contains the URLs of the raw count matrices for each sample. 
# Each line should be a URL pointing to a .tar.gz file (the 10x Genomics output).
parser = argparse.ArgumentParser()
parser.add_argument('--links_file', help="Path to the input links file")
parser.add_argument('--S3_dir', help="A unique name for the S3 directory to upload the data")
args = parser.parse_args()

file_path = args.links_file  # This catches the path from Nextflow
urls = load_urls(file_path)
    
with ThreadPoolExecutor(max_workers=15) as executor:
    results = list(executor.map(fetch_url, urls, repeat(args.S3_dir)))
        

if any("Error" in result for result in results):
    print("Some URLs failed to be processed.")
    for result in results:
        if "Error" in result:
            print(result)
else:
    print("All URLs were successfully processed.")

with open("staging_complete.txt", "w") as f:
    f.write("done")