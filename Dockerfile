# Use Micromamba for a fast, lightweight Conda environment
FROM mambaorg/micromamba:1.5.1

# Set up the environment name
ARG ENV_NAME=scgpt_flow_env

# 1. Copy your environment.yml into the container
COPY --chown=$MAMBA_USER:$MAMBA_USER environment.yml /tmp/env.yaml

# 2. Install dependencies
# Micromamba installs directly into the 'base' environment or a named one
RUN micromamba install -y -n base -f /tmp/env.yaml && \
    micromamba clean --all --yes

# 3. Set the working directory
WORKDIR /app

# 4. Copy your scripts into the image
COPY --chown=$MAMBA_USER:$MAMBA_USER . /app

# 5. Ensure the environment is activated for any shell commands
# This makes python and R available in the PATH automatically
ARG MAMBA_DOCKERFILE_ACTIVATE=1

# 6. Make scripts executable
USER root
RUN chmod +x /app/*.py /app/*.R
USER $MAMBA_USER

# Default command
CMD ["python3"]
