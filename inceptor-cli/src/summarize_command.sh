#!/usr/bin/env bash

# Auto-generated by Bashly v0.9.5
# https://bashly.dannyb.co/
# DO NOT EDIT THIS FILE DIRECTLY. INSTEAD, EDIT THE YAML CONFIGURATION FILE AND REGENERATE.

case_id="${args[caseid]:-$1}"

command_summarize_case() {
  # Prompt user to select OS
  echo "Which operating system are you using?"
  echo "1. RHEL"
  echo "2. MacOS"
  read -p "Enter your choice (1 or 2): " os_choice

  case $os_choice in
    1)
      # Execute on RHEL (Assuming python3 is available)
      if ! command -v python3 &> /dev/null; then
        echo "Python3 is not installed. Please install it to use this command."
        exit 1
      fi
      
      python3 $HOME/caseSummaryGenerator.py "$case_id"
      ;;
    2)
      if ! command -v python3 &> /dev/null; then
        echo "Python3 is not installed. Please install it to use this command."
        exit 1
      fi
      
      # Activate venv created in setup-case-summarizer script
      source "inceptor_venv/bin/activate"
      python3 $HOME/caseSummaryGenerator.py "$case_id"
      ;;
    *)
      echo "Invalid choice. Please enter 1 or 2."
      ;;
  esac
}

# Main entry point
command_summarize_case
    