#!/bin/bash


# clear the terminal
clear

# Set color codes for formatting terminal output
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[44m"
RESET="\033[0m"

# Assign the first command-line argument to the variable 'cluster_id'
cluster_id=$1

# Initialize a search string for Knowledge Center Search
search_string="ingress%20operator%20in%20OpenShift"

# Set a flag to indicate whether to perform Knowledge Center Search
do_kcs_search="true"

# Prompt the user to enter their username
# Read the input from the user and store it in the variable 'username'
echo -n "Enter your username (ex: rhn-support-<kerberos>): "
read username

# Prompt the user to enter their password (with the '-s' flag to silence input)
# Read the input from the user without echoing it to the terminal (for password input)
echo -n "Enter your password: "
read -s pass

# Echo an empty line for visual separation or formatting purposes
echo
echo

# ===============================================================================================
# =============================== FUNCTION Definition Start ====================================


# Define a function named 'login_via_backplane'
login_via_backplane() {
    # Echo a message indicating the start of the login process in yellow color
    echo -e "${YELLOW}Logging into the cluster via backplane...${RESET}"
    echo

    # Use 'ocm backplane login' command to log into the cluster using the provided 'cluster_id'
    #ocm backplane login $cluster_id
}

# Define a function named 'get_basic_info'
get_basic_info() {
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    # Echo a blank line for spacing
    echo

    # Echo a message indicating the start of listing basic information in yellow color
    echo -e "${YELLOW}Listing basic information about the cluster...${RESET}"

    # Use 'osdctl cluster context' command to display cluster context using the provided 'cluster_id'
    osdctl -S cluster context $cluster_id

    # Echo a blank line for spacing
    echo

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    # Echo a message indicating the start of listing service logs in yellow color
    echo

    echo -e "${YELLOW}Listing the service logs sent in past 30 days...${RESET}"

    # Use 'osdctl servicelog list' command to list service logs for the provided 'cluster_id'
    osdctl servicelog list $cluster_id

    # Echo a blank line for spacing
    echo

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    # Echo a message indicating the start of checking node status in yellow color
    echo

    echo -e "${YELLOW}Checking node status...${RESET}"

    # Use 'oc get nodes' command to check the status of nodes in the cluster
    oc get nodes

    # Echo a blank line for spacing
    echo

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}

check_ingress_cluster_operator_status() {
    # Echo a blank line for spacing
    echo

    # Echo a message indicating the start of checking Ingress Cluster Operator status in yellow color
    echo -e "${YELLOW}Checking Ingress Operator Status...${RESET}"

    # Use 'oc get co ingress' command to get the status of the Ingress Cluster Operator
    oc get co ingress

    # Echo a blank line for spacing
    echo

    # Provide information about the '.status.conditions' section and its significance
    echo -e "The below ${GREEN}'.status.conditions'${RESET} section provides insights into the overall health and operational state of the Operator."

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    # Use 'oc describe co ingress' command to get detailed information about the Ingress Cluster Operator
    # Pipe the output to 'awk' to filter and print the relevant '.status.conditions' section
    oc describe co ingress | awk '/^\s*Conditions:/, /^\s*Extension:/{if(/^\s*Extension:/) exit; print}'

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    # Echo a blank line for spacing
    echo
}

# Function to check the deployment and pods for ingress
check_ingress_cluster_operator_resources() {
    # Echo a blank line for spacing
    echo

    # Echo a message indicating the start of checking deployment and pods for ingress in yellow color
    echo -e "${YELLOW}Checking the deployment and pods for ingress...${RESET}"

    # Echo a message indicating the start of deployment section in green color
    echo -e "${GREEN}DEPLOYMENT:${RESET}"

    # Use 'oc' command to get deployments in the namespace 'openshift-ingress'
    oc -n openshift-ingress get deployments

    # Echo a blank line for spacing
    echo
    echo

    # Echo a message indicating the start of pods section in green color
    echo -e "${GREEN}PODS:${RESET}"

    # Use 'oc' command to get pods in the namespace 'openshift-ingress'
    oc -n openshift-ingress get pods

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    # Echo a blank line for spacing
    echo

    # Echo a message indicating the start of listing events from namespace 'openshift-ingess' in yellow color
    echo -e "${YELLOW}Listing events from namespace/openshift-ingess${RESET}"

    # Use 'oc get events' command to get events in namespace 'openshift-ingess'
    oc get events -n openshift-ingress

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}

# Function to gather Ingress Cluster Operator Pod Logs
check_ingress_cluster_operator_pod_logs() {
    # Echo a blank line for spacing
    echo

    # Echo a message indicating the start of gathering Ingress Cluster Operator Pod Logs in yellow color
    echo -e "${YELLOW}Gathering Ingress Operator Pod Logs...${RESET}"

    # Get the name of the Ingress Cluster Operator pod
    operator_pod=$(oc -n openshift-ingress get pods --no-headers -o custom-columns=":metadata.name")

    # Define red flags indicating potential issues in logs
    red_flags=("error" "degraded" "timeout" "expire" "canceled" "RequestError" "Unavailable" "backoff" "failed" "x509")

    # Check if the operator pod exists
    if [ -n "$operator_pod" ]; then
        # Echo the name of the operator pod
        echo -e "${GREEN}OPERATOR POD NAME: $operator_pod${RESET}"
        echo

        # Get the last 10 lines of logs from the operator pod and filter them for red flags
        log_output=$(oc --tail 10 logs -n openshift-ingress "$operator_pod" | grep -E 'error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|ImagePrunerDegraded|RequestError|x509')

        # Colorize the logs containing red flags
        colored_logs="$log_output"
        for word in "${red_flags[@]}"; do
            colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
        done

        # Print the colorized logs
        echo -e "$colored_logs"
    else
        # Echo a message if no operator pod is found
        echo "No Ingress Operator pod found."
    fi

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}

# Function to gather logs from ingess pods and check for red flags
error_highlights_from_ingress_cluster_operator_pod_logs() {
    # Echo a blank line for spacing
    echo

    # Echo a message indicating the start of gathering logs from ingess pods in yellow color
    echo -e "${YELLOW}Gathering logs from one of the ingess pods...${RESET}"

    # Define red flags indicating potential issues in logs
    red_flags=("error" "degraded" "timeout" "expire" "canceled" "ImagePrunerDegraded" "RequestError" "Unavailable" "backoff" "failed" "x509")

    # Echo the name of the operator pod
    echo -e "${GREEN}OPERATOR POD NAME: $operator_pod${RESET}"
    echo

    # Get the last 10 lines of logs from the 'ingress' deployment and filter them for red flags
    log_output=$(oc --tail 10 -n openshift-ingress logs deployment/image-registry | grep -E 'error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|ImagePrunerDegraded|RequestError|x509')

    # Colorize the logs containing red flags
    colored_logs="$log_output"
    for word in "${red_flags[@]}"; do
        colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
    done

    # Print the colorized logs
    echo -e "$colored_logs"

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}

# Function to check other configurations related to ingess
check_other_ingress_cluster_operator_configuration() {
    # Echo a blank line for spacing
    echo "I am check_other_ingress_cluster_operator_configuration()"
    # Echo a separator line in green color for visual distinction
    #echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    #echo

    # check for pruning jobs as well

}

# Function to build search string for KCS based on operator degraded message
build_kcs_search_string() {
    echo "I am build_kcs_search_string()"
}

# Function to search for KCS solutions based on the generated search string
search_kcs() {
    echo "I am searching KCS()"
}

# Function to generate and display Prometheus graph links related to ingress operator metrics
get_prometheus_graph_links() {
    echo "I will give you Prometheus graph links()"
}

# Main function
main() {

    # Call functions to perform login, gather basic information, and check operator status
    login_via_backplane
    get_basic_info
    check_ingress_cluster_operator_status

    # Check operator resources, events, operator pod logs and other configurations
    check_ingress_cluster_operator_resources
    check_ingress_cluster_operator_pod_logs
    error_highlights_from_ingress_cluster_operator_pod_logs
    check_other_ingress_cluster_operator_configuration

    # Build KCS search string, search for KCS solutions, get Prometheus graph links
    build_kcs_search_string
    search_kcs
    get_prometheus_graph_links

}

# =============================== FUNCTION Definition END ====================================

# ===============================================================================================

# ================ MAIN FUNCTION Invoke (which will invoke all other functions) =====================


# Call the main function to start the program execution
main
