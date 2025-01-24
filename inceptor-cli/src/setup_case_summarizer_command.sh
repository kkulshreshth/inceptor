#!/bin/bash

set -e

github_url="https://raw.githubusercontent.com/kkulshreshth/inceptor/refs/heads/main/inceptor-cli/caseSummaryGenerator.py"       
output_path="$HOME/caseSummaryGenerator.py"  

# Function to install Python packages using pip on RHEL
install_python_packages_rhel() {
  echo "Installing Python on RHEL..."
  sudo dnf install -y python3
  echo "Installing python-pip on RHEL..."
  sudo dnf install -y python3-pip
  echo
  echo "Checking Python and pip version..."
  python3 --version
  pip3 --version
  echo
  echo "Installing Python packages langchain-community and langchain-core..."
  pip3 install langchain-community langchain-core
}

# Function to install Python packages using pip on macOS
install_python_packages_macos() {
  echo "Installing Python using Homebrew on macOS..."
  brew install python
  echo

  echo "Installing virtualenv..."
  pipx install virtualenv
  echo

  echo "Creating a virtual environment..."
  python3 -m venv inceptor_venv

  echo "Activating the virtual environment..."
  source inceptor_venv/bin/activate

  echo "Checking Python and pip version inside the virtual environment..."
  python3 --version
  pip3 --version
  echo

  echo "Installing Python packages langchain-community and langchain-core inside the virtual environment..."
  pip3 install langchain-community langchain-core pip requests

  echo "Virtual environment setup complete. The virtual environment will be activated for the following operations."

  # Keep the virtual environment active
  export VIRTUAL_ENV=active

}

# Function to copy Python script from GitHub
copy_python_script() {
  github_url=$1
  output_path=$2

  echo "Downloading from GitHub: $github_url..."
  curl -L "$github_url" -o "$output_path"

  # Check if curl command succeeded
  if [ $? -eq 0 ]; then
      echo "Download successful. File saved to: $output_path"
  else
      echo "Failed to download the file from GitHub: $github_url"
      exit 1
  fi
}

# Function to install Ollama's software on RHEL
install_ollama_rhel() {
  echo "Installing Ollama software on RHEL..."
  curl -fsSL https://ollama.com/install.sh | sh
}

# Function to install Ollama's software on macOS
install_ollama_macos() {
  url="https://ollama.com/download/Ollama-darwin.zip"
  temp_zip="/tmp/Ollama-darwin.zip"  # Temporary location to store the downloaded ZIP
  install_dir="/Applications"       # Directory to install Ollama (adjust as needed)

  echo "Downloading Ollama from $url..."
  curl -L -o "$temp_zip" "$url"

  # Check if curl command succeeded
  if [ $? -ne 0 ]; then
      echo "Failed to download Ollama from $url"
      exit 1
  fi

  echo "Extracting Ollama package..."
  unzip -q "$temp_zip" -d "$install_dir"

  # Check if unzip command succeeded
  if [ $? -ne 0 ]; then
      echo "Failed to extract Ollama package"
      exit 1
  fi

  echo "copying ollama to /usr/local/bin"
  sudo ln -s /Applications/Ollama.app/Contents/Resources/ollama /usr/local/bin/ollama

  echo "Cleaning up..."
  rm "$temp_zip"

  echo "Ollama installation completed successfully."
}

# Function to pull the wizardlm2 model using Ollama
pull_wizardlm2_model() {
  echo "Pulling wizardlm2 model..."
  ollama pull wizardlm2
}

# Ask the user for the operating system
echo "Please select your operating system:"
echo "1) RHEL"
echo "2) MacOS"
read -p "Enter the number corresponding to your OS (1 or 2): " os_choice

# Execute the functions based on OS choice
if [ "$os_choice" == "1" ]; then
  echo "You selected RHEL."
  install_python_packages_rhel
  copy_python_script "$github_url" "$output_path"
  install_ollama_rhel
  pull_wizardlm2_model
elif [ "$os_choice" == "2" ]; then
  echo "You selected macOS."
  install_python_packages_macos
  #copy_python_script "$github_url" "$output_path"
  #install_ollama_macos
  #pull_wizardlm2_model
else
  echo "Invalid selection. Please run the script again and choose either 1 or 2."
  exit 1
fi

echo "Installation completed successfully."