#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

github_url="https://raw.githubusercontent.com/kkulshreshth/inceptor/main/inceptor-cli/src/caseSummaryGenerator.py"       
output_path="$HOME/caseSummaryGenerator.py"       

# Function to install Python packages using pip
install_python_packages() {
  echo "Installing python..."
  sudo dnf install python3
  echo
  echo "Installing python-pip..."
  sudo dnf install python3-pip
  echo 
  echo "Checking python and pip version..."
  python3 --version
  pip3 --version
  echo "Installing Python packages langchain-community and langchain-core..."
  pip install langchain-community langchain-core
}

copy_python_script() {
  # Download the file using curl
  echo "Downloading from GitHub: $github_url..."
  wget "$github_url" -O "$output_path"

  # Check if curl command succeeded
  if [ $? -eq 0 ]; then
      echo "Download successful. File saved to: $output_path"
  else
      echo "Failed to download the file from GitHub: $github_url"
      exit 1
  fi
}

# Function to install Ollama's software
install_ollama() {
  echo "Installing Ollama software..."
  curl -fsSL https://ollama.com/install.sh | sh
}

# Function to pull the wizardlm2 model using Ollama
pull_wizardlm2_model() {
  echo "Pulling wizardlm2 model..."
  ollama pull wizardlm2
}

# Execute the functions
#install_python_packages
copy_python_script
#install_ollama
#pull_wizardlm2_model

echo "Installation completed successfully."