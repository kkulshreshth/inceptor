#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[44m"
RESET="\033[0m"
cluster_id="${args[clusterid]:-$1}"

# Function to login to the cluster via backplane
login_via_backplane() {
    echo -e "${YELLOW}Logging into the cluster via backplane...${RESET}"
    ocm backplane login $cluster_id
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to log into the cluster via backplane. Exiting script.${RESET}"
        exit 1
    fi
}

# Function to check MachineSet status
check_machineset_status() {
  echo -e "\n${GREEN}Fetching MachineSet status...${RESET}"
  oc -n openshift-machine-api get machinesets
}

# Function to check Machine status
check_machine_status() {
  echo -e "\n${GREEN}Fetching Machine status...${RESET}"
  oc -n openshift-machine-api get machines
}

# Function to check Node status
check_node_status() {
  echo -e "\n${GREEN}Fetching Node status...${RESET}"
  oc get nodes
}

# Function to check pending CSRs
check_pending_csrs() {
  echo -e "\n${GREEN}Checking for pending CSRs...${RESET}"
  oc get csr | grep Pending
}

# Function to troubleshoot a specific machine
troubleshoot_machine() {
  local machine_name=$1
  
  echo -e "\n${GREEN}Starting troubleshooting for machine: $machine_name ${RESET}"
  
  # Check if the machine is stuck in Provisioned status
  status=$(oc -n openshift-machine-api get machine "$machine_name" -o jsonpath='{.status.phase}')
  if [[ $status == "Provisioned" ]]; then
    echo -e "Machine is in ${YELLOW}'Provisioned'${RESET} status. Checking for EC2 instance and machine-config-daemon logs..."
    
    echo -e "\n${GREEN}Checking machine-config-daemon logs for errors:${RESET}"
    for POD in $(oc -n openshift-machine-config-operator get pods -o name | grep machine-config-daemon); do
      oc -n openshift-machine-config-operator logs $POD -c machine-config-daemon | grep Error
    done

    echo -e "\n${GREEN}Recommendation:${RESET} If a failed pull is detected, and the registry is online, delete the Machine."
  fi

  # Check if the machine is in Deleting status
  if [[ $status == "Deleting" ]]; then
    echo -e "Machine is in ${RED}'Deleting'${RESET} status. Checking machine-controller logs..."
    oc logs -n openshift-machine-api deploy/machine-api-controllers -c machine-controller --since=10m | grep "$machine_name"

    echo -e "\n${GREEN}Recommendation:${RESET} If the error relates to a pod that can't be evicted, try manually draining the node:"
    echo -e "\nIf draining fails, manually delete stuck pods until the drain/machine delete completes."
  fi

  # Check if the machine status is Failed or Provisioning
  if [[ $status == "Failed" || $status == "Provisioning" || $status == "Running" ]]; then
    echo -e "Machine is in ${YELLOW}'$status'${RESET} status. Checking machine-controller logs..."

    # Check machine-controller logs for error details
    oc logs -n openshift-machine-api deploy/machine-api-controllers -c machine-controller --since=10m | grep "$machine_name"

    # Machine Status:
    echo -e "${GREEN}Machine status:${RESET}"
    oc describe machine "$machine_name" -n openshift-machine-api | grep -A 20 "Status:"

    # Get the AWS instance ID for the machine
    instance_id=$(oc describe machine "$machine_name" -n openshift-machine-api | grep "Instance Id" | awk '{print $3}')

    # AWS cloud console link:
    echo
    ocm backplane cloud console
 
    echo
    echo -e "\n${GREEN}Recommendation:${RESET} To further check the issue, navigate to AWS console -> EC2 -> check if the EC2 instance is present."
    echo -e "If the associated EC2 instance is not present in the AWS console, check the cloud trail event history for the Instance Id ($instance_id)."
  fi
}

# Main menu for the interactive script

login_via_backplane

while true; do
  echo -e "\n${GREEN}OpenShift Machine Troubleshooting Script${RESET}"
  echo -e "${YELLOW}1. Check MachineSet status${RESET}"
  echo -e "${YELLOW}2. Check Machine status${RESET}"
  echo -e "${YELLOW}3. Check Node status${RESET}"
  echo -e "${YELLOW}4. Check pending CSRs${RESET}"
  echo -e "${YELLOW}5. Troubleshoot a specific machine${RESET}"
  echo -e "${YELLOW}6. Exit${RESET}"
  read -p "Enter your choice [1-6]:" choice

  case $choice in
    1)
      check_machineset_status
      ;;
    2)
      check_machine_status
      ;;
    3)
      check_node_status
      ;;
    4)
      check_pending_csrs
      ;;
    5)
      check_machine_status
      read -p "Enter the name of the machine to troubleshoot: " machine_name
      troubleshoot_machine "$machine_name"
      ;;
    6)
      echo "Exiting script. Goodbye!"
      break
      ;;
    *)
      echo "Invalid choice. Please select a valid option."
      ;;
  esac

done