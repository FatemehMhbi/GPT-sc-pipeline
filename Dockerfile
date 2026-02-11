# Step 1: Use an official lightweight Python image
FROM python:3.10-slim

# Step 2: Set the directory where our code will live
WORKDIR /app

# Step 3: Copy our requirements first (this makes builds faster!)
COPY requirements.txt .

# Step 4: Install the libraries
RUN pip install --no-cache-dir -r requirements.txt

# Step 5: Copy the rest of our code (main.py and .env)
COPY . .

# Step 6: The command to run your script
CMD ["python", "src/main.py"]
