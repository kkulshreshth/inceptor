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

# Capturing OS default browser -- which will be used when prometheus links function executes
os_default_browser() {
  case $(uname | tr '[:upper:]' '[:lower:]') in
  linux*)
    OPEN="xdg-open"
    ;;
  darwin*)
    OPEN="open"
    ;;
  esac
}


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

    echo

    echo -e "${YELLOW}Listing the service logs sent in past 30 days...${RESET}"

    # Use 'osdctl servicelog list' command to list service logs for the provided 'cluster_id'
    osdctl -S servicelog list $cluster_id

    # Echo a blank line for spacing
    echo

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    # Echo a message indicating the start of checking node status in yellow color
    echo

    echo -e "${YELLOW}Checking cluster version, node and all cluster operator status...${RESET}"
    oc get clusterversion; echo; echo; oc get nodes; echo; echo; oc get co

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
    echo -e "${YELLOW}Checking the deployment and pods in openshift-ingress namespace...${RESET}"

    # Echo a message indicating the start of deployment section in green color
    echo -e "${GREEN}DEPLOYMENT:${RESET}"

    # Use 'oc' command to get deployments in the namespace 'openshift-ingress'
    oc -n openshift-ingress get deployments

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

    # Echo a message indicating the start of checking deployment and pods for ingress in yellow color
    echo -e "${YELLOW}Checking the deployment and pods in openshift-ingress-operator namespace...${RESET}"

    # Echo a message indicating the start of deployment section in green color
    echo -e "${GREEN}DEPLOYMENT:${RESET}"

    # Use 'oc' command to get deployments in the namespace 'openshift-ingress'
    oc -n openshift-ingress-operator get deployments

    echo
    echo

    # Echo a message indicating the start of pods section in green color
    echo -e "${GREEN}PODS:${RESET}"

    # Use 'oc' command to get pods in the namespace 'openshift-ingress'
    oc -n openshift-ingress-operator get pods

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo
}


# Function to check the namespace events for ingress
check_ingress_cluster_operator_events(){

    # Echo a message indicating the start of listing events from namespace 'openshift-ingess' in yellow color
    echo -e "${YELLOW}Listing events from namespace/openshift-ingess${RESET}"

    # Use 'oc get events' command to get events in namespace 'openshift-ingess'
    oc get events -n openshift-ingress

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo
    echo

    # Echo a message indicating the start of listing events from namespace 'openshift-ingess' in yellow color
    echo -e "${YELLOW}Listing events from namespace/openshift-ingess-operator .. ${RESET}"

    # Use 'oc get events' command to get events in namespace 'openshift-ingess'
    oc get events -n openshift-ingress-operator

    echo

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo
}

# Function to gather all Ingress related Pod Logs
check_ingress_cluster_operator_pod_logs() {

    echo

    # Echo a message indicating the start of gathering Ingress Pod Logs in yellow color
    echo -e "${YELLOW}Gathering openshift-ingress Pod Logs...${RESET}"

    # Get the name of the openshift-ingress pod
    oi_pod=$(oc -n openshift-ingress get pods --no-headers -o custom-columns=":metadata.name")

    # Define red flags indicating potential issues in logs
    red_flags=("issue" "error" "degraded" "timeout" "expire" "not responding" "overload" "canceled" "RequestError" "Unavailable" "backoff" "failed" "unreachable" "x509" "connection error" "reconciliation failed" "not created" "conflict" "bottleneck" "congestion" "drop" "spike" "imbalance" "misconfiguration")

    # Check if the pods exist
    if [ -n "$oi_pod" ]; then
        # Echo the name of the operator pod
        echo -e "${GREEN}OPERATOR POD NAME: $oi_pod${RESET}"
        echo

        # Get the last 10 lines of logs from the operator pod and filter them for red flags
        log_output=$(oc --tail 10 logs -n openshift-ingress "$oi_pod" | grep -iE 'issue|error|degraded|timeout|expire|not responding|overload|canceled|RequestError|Unavailable|backoff|failed|unreachable|x509|connection error|reconciliation failed|not created|conflict|bottleneck|congestion|drop|spike|imbalance|misconfiguration')

        # Colorize the logs containing red flags
        colored_logs="$log_output"
        for word in "${red_flags[@]}"; do
            colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
        done

        # Print the colorized logs
        echo -e "$colored_logs"
    else
        # Echo a message if no operator pod is found
        echo "No Ingress pods found."
    fi

    echo
    echo

    # Echo a message indicating the start of gathering Ingress Cluster Operator Pod Logs in yellow color
    echo -e "${YELLOW}Gathering openshift-ingress-operator Pod Logs...${RESET}"

    # Get the name of the openshift-ingress-operator pod
    oio_pod=$(oc -n openshift-ingress-operator get pods --no-headers -o custom-columns=":metadata.name")

    # Check if the pods exist
    if [ -n "$oio_pod" ]; then
        # Echo the name of the operator pod
        echo -e "${GREEN}OPERATOR POD NAME: $oio_pod${RESET}"
        echo

        # Get the last 10 lines of logs from the operator pod and filter them for red flags
        log_output=$(oc --tail 10 logs -n openshift-ingress "$oio_pod" | grep -iE 'issue|error|degraded|timeout|expire|not responding|overload|canceled|RequestError|Unavailable|backoff|failed|unreachable|x509|connection error|reconciliation failed|not created|conflict|bottleneck|congestion|drop|spike|imbalance|misconfiguration')

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


# Function to check other configurations related to ingess
check_ingress_controller_status() {
    # Echo a blank line for spacing
    echo
    # Echo a separator line in green color for visual distinction
    #echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    #echo

    ics=$(oc get ingresscontroller -n openshift-ingress-operator --no-headers -o custom-columns=":metadata.name")

    # Split the output into an array using newline as delimiter
    IFS=$'\n' read -r -d '' -a ics_array <<<"$ics"

    if [ -n "$ics_array" ]; then

        for ic in "${ics_array[@]}"; do
            # Echo the name of the Ingress Controllers
            echo -e "${GREEN}INGRESS CONTROLLER NAME: $ic${RESET}"
            echo

            # Provide information about the '.status.conditions' section and its significance
            echo -e "The below ${GREEN}'.status.conditions'${RESET} section provides insights into the overall health and operational state of the Operator."

            # Pipe the output to 'awk' to filter and print the relevant '.status.conditions' section
            oc describe ingresscontroller $ic -n openshift-ingress-operator | awk '/^\s*Conditions:/, /^\s*Extension:/{if(/^\s*Extension:/) exit; print}'

            # Echo a separator line in green color for visual distinction
            echo
            echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
            echo

        done

    else
        echo "No Ingress Controllers found."
    fi

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

    os_default_browser
    login_via_backplane
    get_basic_info
    check_ingress_cluster_operator_status

    # Check operator resources, events, operator pod logs and other configurations
    check_ingress_cluster_operator_resources
    check_ingress_cluster_operator_events
    check_ingress_cluster_operator_pod_logs
    check_ingress_controller_status

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
