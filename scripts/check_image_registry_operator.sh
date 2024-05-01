#!/bin/bash

# Set color codes for formatting terminal output
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[44m"
RESET="\033[0m"

# Assign the first command-line argument to the variable 'cluster_id'
cluster_id=$1

# Initialize a search string for Knowledge Center Search
search_string="image%20registry%20operator%20degraded%20in%20OpenShift"

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
    
    # Use 'ocm backplane login' command to log into the cluster using the provided 'cluster_id'
    ocm backplane login $cluster_id
}


# Define a function named 'get_basic_info'
get_basic_info() {
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    
    # Echo a message indicating the start of listing basic information in yellow color
    echo -e "${YELLOW}Listing basic information about the cluster...${RESET}"
    
    # Use 'osdctl cluster context' command to display cluster context using the provided 'cluster_id'
    osdctl cluster context $cluster_id
    
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


# Function to check the status of the Image Registry Operator
check_image_registry_operator_status() {
    # Echo a blank line for spacing
    echo
    
    # Echo a message indicating the start of checking Image Registry Operator status in yellow color
    echo -e "${YELLOW}Checking Image Registry Operator Status...${RESET}"
    
    # Use 'oc get co image-registry' command to get the status of the Image Registry Operator
    oc get co image-registry
    
    # Echo a blank line for spacing
    echo
    
    # Provide information about the '.status.conditions' section and its significance
    echo -e "The below ${GREEN}'.status.conditions'${RESET} section provides insights into the overall health and operational state of the Operator."
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    
    # Use 'oc describe co image-registry' command to get detailed information about the Image Registry Operator
    # Pipe the output to 'awk' to filter and print the relevant '.status.conditions' section
    oc describe co image-registry | awk '/^\s*Conditions:/, /^\s*Extension:/{if(/^\s*Extension:/) exit; print}'
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    
    # Echo a blank line for spacing
    echo
}


# Function to check the deployment and pods for image-registry
check_operator_resources() {
    # Echo a blank line for spacing
    echo
    
    # Echo a message indicating the start of checking deployment and pods for image-registry in yellow color
    echo -e "${YELLOW}Checking the deployment and pods for image-registry...${RESET}"
    
    # Echo a message indicating the start of deployment section in green color
    echo -e "${GREEN}DEPLOYMENT:${RESET}"
    
    # Use 'oc' command to get deployments in the namespace 'openshift-image-registry'
    oc -n openshift-image-registry get deployments
    
    # Echo a blank line for spacing
    echo
    echo
    
    # Echo a message indicating the start of pods section in green color
    echo -e "${GREEN}PODS:${RESET}"
    
    # Use 'oc' command to get pods in the namespace 'openshift-image-registry'
    oc -n openshift-image-registry get pods
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    
    # Echo a blank line for spacing
    echo
}


# Function to gather Image Registry Operator Pod Logs
check_image_registry_operator_pod_logs() {
    # Echo a blank line for spacing
    echo
    
    # Echo a message indicating the start of gathering Image Registry Operator Pod Logs in yellow color
    echo -e "${YELLOW}Gathering Image Registry Operator Pod Logs...${RESET}"
    
    # Get the name of the Image Registry Operator pod
    operator_pod=$(oc -n openshift-image-registry get pods --no-headers -o custom-columns=":metadata.name" | grep cluster-image-registry-operator)
    
    # Define red flags indicating potential issues in logs
    red_flags=("error" "degraded" "timeout" "expire" "canceled" "ImagePrunerDegraded" "RequestError" "Unavailable" "backoff" "failed" "x509")
    
    # Check if the operator pod exists
    if [ -n "$operator_pod" ]; then
        # Echo the name of the operator pod
        echo -e "${GREEN}OPERATOR POD NAME: $operator_pod${RESET}"
        echo
        
        # Get the last 10 lines of logs from the operator pod and filter them for red flags
        log_output=$(oc --tail 10 logs -n openshift-image-registry "$operator_pod" | grep -E 'error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|ImagePrunerDegraded|RequestError|x509')
        
        # Colorize the logs containing red flags
        colored_logs="$log_output"
        for word in "${red_flags[@]}"; do
            colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
        done
        
        # Print the colorized logs
        echo -e "$colored_logs"
    else
        # Echo a message if no operator pod is found
        echo "No Image Registry Operator pod found."
    fi
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}



# Function to gather logs from image-registry pods and check for red flags
check_image_registry_pod_logs() {
    # Echo a blank line for spacing
    echo
    
    # Echo a message indicating the start of gathering logs from image-registry pods in yellow color
    echo -e "${YELLOW}Gathering logs from one of the image-registry pods...${RESET}"
    
    # Define red flags indicating potential issues in logs
    red_flags=("error" "degraded" "timeout" "expire" "canceled" "ImagePrunerDegraded" "RequestError" "Unavailable" "backoff" "failed" "x509")

    # Echo the name of the operator pod
    echo -e "${GREEN}OPERATOR POD NAME: $operator_pod${RESET}"
    echo
    
    # Get the last 10 lines of logs from the 'image-registry' deployment and filter them for red flags
    log_output=$(oc --tail 10 -n openshift-image-registry logs deployment/image-registry | grep -E 'error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|ImagePrunerDegraded|RequestError|x509')
    
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


# Function to check other configurations related to image-registry
check_other_configuration() {
    # Echo a blank line for spacing
    echo
    
    # Echo a message indicating the start of listing events from namespace 'openshift-image-registry' in yellow color
    echo -e "${YELLOW}Listing events from namespace/openshift-image-registry${RESET}"
    
    # Use 'oc get events' command to get events in namespace 'openshift-image-registry'
    oc get events -n openshift-image-registry
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    
    # Echo a message indicating the start of checking the config for image-registry in yellow color
    echo -e "${YELLOW}Checking the config for image-registry${RESET}"
    
    # Print command to get config for image-registry in green color
    echo -e "${GREEN}oc get configs.imageregistry.operator.openshift.io cluster -o yaml (.status.conditions)${RESET}"
    echo
    
    # Use 'oc get configs.imageregistry.operator.openshift.io' command to get config for image-registry in yaml format
    # Use 'awk' to filter and print the relevant '.status.conditions' section
    oc get configs.imageregistry.operator.openshift.io cluster -o yaml | awk '/^\s*conditions:/, /^\s*generations:/{if(/^\s*generations:/) exit; print}'
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    
    # Echo a message indicating the start of fetching storage configuration in yellow color
    echo -e "${YELLOW}Fetching storage configuration${RESET}"
    
    # Print command to get storage configuration for image-registry in green color
    echo -e "${GREEN}oc get configs.imageregistry.operator.openshift.io cluster -o json | jq -r '.spec.storage'${RESET}"
    echo
    
    # Use 'oc get configs.imageregistry.operator.openshift.io' command to get storage configuration for image-registry in json format
    # Use 'jq' to parse and print the storage configuration
    oc get configs.imageregistry.operator.openshift.io cluster -o json | jq -r '.spec.storage'
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    
    # Echo a blank line for spacing
    echo
    
    # Echo a message indicating the start of checking imagepruner in yellow color
    echo -e "${YELLOW}Check imagepruner (.status.conditions)${RESET}"
    
    # Print command to get imagepruner status in green color
    echo -e "${GREEN}oc get imagepruner cluster -o yaml (.status.conditions)${RESET}"
    
    # Use 'oc get imagepruner' command to get imagepruner status in yaml format
    # Use 'awk' to filter and print the relevant '.status.conditions' section
    oc get imagepruner cluster -o yaml | awk '/^\s*conditions:/, /^\s*observedGeneration:/{if(/^\s*observedGeneration:/) exit; print}'
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}


# Function to address known issues related to job pruning
job_pruning_issues() {
    # Echo a message indicating known issues and solutions in blue color
    echo -e "${BLUE}KNOWN ISSUES and SOLUTIONS${RESET}"
    
    # Echo a message about pruning job failures in yellow color
    echo -e "${YELLOW}PRUNING JOB FAILURES${RESET}"
    echo
    
    # Echo a common cause of operator degradation due to pruning job failures
    echo -e "A common cause of the cluster operator to become degraded is through the failure of its periodic pruning jobs."
    
    # Echo a message to check for any jobs that did not complete
    echo -e "${GREEN}Check for any jobs which did not complete, they will show up as '0/1' in the completions column${RESET}"
    
    # Use 'oc get job' command to list jobs in namespace 'openshift-image-registry'
    oc get job -n openshift-image-registry
    echo
    
    # Echo a message to check logs for the pod corresponding to the failed job
    echo -e "If any job did not complete, check the logs for the pod corresponding to the job for more information about the failure using the following command:"
    echo -e "${GREEN}oc logs -n openshift-image-registry -l job-name=$JOBNAME${RESET}"
    echo
    
    # Echo a message to remove failed jobs if successive pruning jobs have completed
    echo -e "If successive pruning jobs have completed, ask the SRE/customer to remove the failed jobs using the following command:"
    echo -e "${GREEN}oc delete job -n openshift-image-registry $JOBNAME${RESET}"
    
    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}


# Function to print additional information
print_additional_info() {
    # Echo a message indicating additional information in yellow color
    echo -e "${YELLOW}Additional Information:${RESET}"
    
    # Echo a message about getting in touch with OCP engineering for the operator
    echo -e "To get in touch with OCP engineering for this operator, join ${GREEN}forum-imageregistry${RESET} slack channel and ping ${GREEN}@imageregistry-team${RESET} handle with any queries."
}


# Function to build search string for KCS based on operator degraded message
build_search_string() {
    # Echo a blank line for spacing
    echo
    
    # Get operator degraded message from the cluster
    operator_degraded_message=$(oc get co image-registry -o json | jq -r '.status.conditions[] | select(.type == "Degraded") | .message')
    
    # Check if operator degraded message is null
    if [ "$operator_degraded_message" == "null" ]; then
        # If null, get operator progressing message
        operator_degraded_message=$(oc get co image-registry -o json | jq -r '.status.conditions[] | select(.type == "Progressing") | .message')
    fi

    # Check if operator degraded message is still null
    if [ "$operator_degraded_message" == "null" ]; then
        # If still null, set flag to skip KCS search
        do_kcs_search="false"
    else
        # Strings to search for KCS, can be expanded based on defined errors
        search_pattern=("Progressing: Unable to apply resources: unable to sync storage configuration: RequestError: send request failed" "ImagePrunerDegraded: Job has reached the specified backoff limit" "Degraded: The deployment does not have available replicas" "unsupported protocol scheme")

        # Variable to store the found strings
        found_strings=""

        # Loop through each search string
        for search_str in "${search_pattern[@]}"; do
            # Check if the search string is present in the operator degraded message
            if [[ $operator_degraded_message =~ $search_str ]]; then
                # If found, append it to the variable
                found_strings="$found_strings $search_str"
            fi
        done

        # Encode found strings for URL
        updated_operator_degraded_message=$(echo "$found_strings" | sed 's/ /%20/g')
        # Append updated search string with found strings
        search_string="$search_string%20$updated_operator_degraded_message"
        # Echo a separator line in green color for visual distinction
        echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    fi
}



# Function to search for KCS solutions based on the generated search string
search_kcs() {
    # Echo a blank line for spacing
    echo
    
    # Check if KCS search is required
    if [ "$do_kcs_search" == "false" ]; then
        # If not required, provide guidance and a link to a specific KCS solution
        echo -e "${GREEN}Couldn't build a valid search string. It looks like the operator is not being reported as degraded. If there are issues with the operator, please review the logs and resources related to image-registry pods. You can also refer the following KCS for further troubleshooting:${RESET}${RED} https://access.redhat.com/solutions/3804741${RESET}"
    else
        # If KCS search is required, proceed with the search
        echo -e "${YELLOW}Searching for KCS Solutions...${RESET}"
        
        # Construct the API URL for KCS search
        api_url="https://api.access.redhat.com/support/search/kcs?fq=documentKind:(%22Solution%22)&q=*$search_string*&rows=3&start=0"
        
        # Make the API call using curl and store the response in a variable
        api_response=$(curl -s -X GET -u "$username:$pass" "$api_url")

        # Check the HTTP status code of the API call
        http_status_code=$(curl -s -o /dev/null -w "%{http_code}" "$api_url")

        # Check if the API call was successful (HTTP status code 200)
        if [ "$http_status_code" -eq 200 ]; then
            # If successful, display the API response
            echo "API call was successful."
            echo "API Response:"
            # Extract and display KCS solution URLs from the API response
            echo "$api_response" | grep -o 'https://access.redhat.com/solutions/[^ ]*' | sed -e 's/["}].*//'
        else
            # If unsuccessful, display an error message with the HTTP status code
            echo "API call failed with HTTP status code $http_status_code."
        fi
    fi
}


# Function to generate and display Prometheus graph links related to image registry operator metrics
get_prometheus_graph_links() {
    # Echo a blank line for spacing
    echo
    
    # Echo a message indicating the start of running Prometheus queries in yellow color
    echo -e "${YELLOW}Running prometheus queries...${RESET}"
    
    # Echo a message prompting the user to navigate to the provided links to review metrics related to the image registry operator
    echo -e "${YELLOW}Please navigate to the following links to review metrics related to the image registry operator:${RESET}"
    echo

    # Define the command to run in a new terminal
    command_to_run="ocm backplane console $cluster_id"

    # Define the file to store the command output
    output_file="console_url_file.txt"

    # Step 1: Open a new terminal, run the command, and store its output
    gnome-terminal -- bash -c "$command_to_run > $output_file; read -n 1 -p 'Press any key to exit.'; exit"

    # Wait for 60 seconds to ensure the command execution completes
    sleep 60

    # Extract the console URL from the output file
    console_url=$(grep -o 'http[^\ ]*' $output_file)

    # Echo the first Prometheus graph link: MONITORING DASHBOARD for namespace/openshift-image-registry
    echo -e "${GREEN}1. MONITORING DASHBOARD for namespace/openshift-image-registry: ${RESET}"
    query="monitoring/dashboards/grafana-dashboard-k8s-resources-workloads-namespace?namespace=openshift-image-registry&type=deployment"
    echo
    query_url="$console_url/$query"
    echo -e "$query_url"
    echo
    
    # Echo the second Prometheus graph link: Query Executed
    echo -e "${GREEN}2. Query Executed:${RESET} kube_job_status_failed{namespace="openshift-image-registry"}"
    echo -e "This query provides information about the ${GREEN}FAILED${RESET} jobs inside the namespace/openshift-image_registry"
    echo
    query="monitoring/query-browser?query0=kube_job_status_failed%7Bnamespace%3D%22openshift-image-registry%22%7D"
    query_url="$console_url/$query"
    echo -e "$query_url"
    echo
}


# Main function orchestrating the execution of various tasks related to image registry troubleshooting
main() {
    # Call functions to perform login, gather basic information, and check operator status
    login_via_backplane
    get_basic_info
    check_image_registry_operator_status
    
    # Check operator resources, operator pod logs, and image registry pod logs
    check_operator_resources
    check_image_registry_operator_pod_logs
    check_image_registry_pod_logs
    
    # Check other configurations, job pruning issues, and build search string for KCS
    check_other_configuration
    job_pruning_issues
    build_search_string
    
    # Search for KCS solutions, get Prometheus graph links, and print additional information
    search_kcs
    get_prometheus_graph_links
    print_additional_info
}

# =============================== FUNCTION Definition END ====================================

# ===============================================================================================

# ================ MAIN FUNCTION Invoke (which will invoke all other functions) =====================

# Call the main function to start the execution
main
