#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[44m"
RESET="\033[0m"
cluster_id=$1
search_string="kube%20controller-manager%20operator%20degraded%20in%20OpenShift"
do_kcs_search="true"

echo "Enter your username (ex: rhn-support-<kerberos>):"
read username

echo "Enter your password:"
read -s pass

echo

login_via_backplane() {
    echo -e "${YELLOW}Logging into the cluster via backplane...${RESET}"
    ocm backplane login $cluster_id
}

get_basic_info() {
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo -e "${YELLOW}Listing basic information about the cluster...${RESET}"
    osdctl cluster context $cluster_id
    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    echo -e "${YELLOW}Listing the service logs sent in past 30 days...${RESET}"
    osdctl servicelog list $cluster_id
    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    echo -e "${YELLOW}Checking node status...${RESET}"
    oc get nodes
    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}

# Function to check the status of the kube-controller-manager Operator
check_kube-controller-manager_operator_status() {
    echo
    echo -e "${YELLOW}Checking kube-controller-manager Operator Status...${RESET}"
    oc get co kube-controller-manager 
    echo
    echo -e "The below ${GREEN}'.status.conditions'${RESET} section provides insights into the overall health and operational state of the Operator."
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    oc describe co kube-controller-manager | awk '/^\s*Conditions:/, /^\s*Extension:/{if(/^\s*Extension:/) exit; print}'
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}

# Checking the deployment and pods for kube-controller-manager
check_operator_resources() {
    echo
    echo -e "${YELLOW}Checking the deployment and pods for kube-controller-manager...${RESET}"
    echo -e "${GREEN}GET ALL:${RESET}"
    oc -n openshift-kube-controller-manager get all
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}

check_kube-controller-manager_operator_pod_logs() {
    echo
    echo -e "${YELLOW}Gathering kube-controller-manager Operator Pod Logs...${RESET}"
    operator_pod=$(oc -n openshift-kube-controller-manager-operator get pods --no-headers -o custom-columns=":metadata.name" | grep kube-controller-manager-operator)
    red_flags=("error" "degraded" "timeout" "Terminating" "canceled" "CrashLoopBackOff" "RequestError" "Unavailable" "backoff" "failed" "x509")

    if [ -n "$operator_pod" ]; then
        echo -e "${GREEN}OPERATOR POD NAME: $operator_pod${RESET}"
        echo
        log_output=$(oc --tail 10 logs -n openshift-kube-controller-manager-operator "$operator_pod" | grep -E 'error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|CrashLoopBackOff|RequestError|x509')
        colored_logs="$log_output"
        for word in "${red_flags[@]}"; do
            colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
        done

        # Print the colored logs
        echo -e "$colored_logs"
    else
        echo "No kube-controller-manager_operator_pod found."
    fi
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}

# Checking logs of openshift-kube-controller-manager  pods
check_openshift-kube-controller-manager_pod_logs() {
    echo
    echo -e "${YELLOW}Gathering logs from one of the openshift-kube-controller-manager  pods...${RESET}"
    
    red_flags=("error" "degraded" "timeout" "Terminating" "canceled" "CrashLoopBackOff" "RequestError" "Unavailable" "backoff" "failed" "x509")

    echo -e "${GREEN}OPERATOR POD NAME: $operator_pod${RESET}"
    echo
    log_output=$(for i in $(oc get pods -o name -n openshift-kube-controller-manager) ; do oc --tail 10 logs $i -n openshift-kube-controller-manager | grep -E 'error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|CrashLoopBackOff|RequestError|x509' ; done)
    colored_logs="$log_output"
    for word in "${red_flags[@]}"; do
        colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
    done

    # Print the colored logs
    echo -e "$colored_logs"
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}



check_other_configuration() {
    echo
    echo -e "${YELLOW}Listing events from namespace/openshift-kube-controller-manager${RESET}"
    oc get events -n openshift-kube-controller-manager
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    echo -e "${YELLOW}Checking describe for openshift-kube-controller-manager${RESET}"
    oc get kubecontrollermanager/cluster -o json | jq -r '.status.conditions[]' 
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    echo -e "${YELLOW}Checking MCP status ${RESET}"
    oc get mcp
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}



print_additional_info() {
    echo -e "${YELLOW}Additional Information:${RESET}"
    echo -e "To get in touch with OCP engineering for this operator, join ${GREEN}forum-ocp-workloads${RESET} to handle with any queries."
}

build_search_string() {
    echo
    operator_degraded_message=$(oc get co kube-controller-manager -o json | jq -r '.status.conditions[] | select(.type == "Degraded") | .message')
    if [ "$operator_degraded_message" == "null" ]; then
        operator_degraded_message=$(oc get co kube-controller-manager -o json | jq -r '.status.conditions[] | select(.type == "Progressing") | .message')
    fi

    #echo -e "OPERTOR MESSAGE : $operator_degraded_message"

    if [ "$operator_degraded_message" == "null" ]; then
        do_kcs_search="false"
    else
        # Strings to search for KCS, will add more strings based on defined errors
        search_pattern=("StaticPodsDegraded: pod/kube-controller-manager" "StaticPodsDegraded")

        # Variable to store the found strings
        found_strings=""

        # Loop through each search string
        for search_str in "${search_pattern[@]}"; do
            # Check if the search string is present in the paragraph
            if [[ $operator_degraded_message =~ $search_str ]]; then
                # If found, append it to the variable
                found_strings="$found_strings $search_str"
            fi
        done

        # Print the result
        #echo "Found strings: $found_strings"

        updated_operator_degraded_message=$(echo "$found_strings" | sed 's/ /%20/g')
        search_string="$search_string%20$updated_operator_degraded_message"
        #echo "NEW SEARCH STRINGS: $search_string"
        echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    fi
}

search_kcs() {
    echo
    if [ "$do_kcs_search" == "false" ]; then
        echo -e "${GREEN}Couldn't build a valid search string. It looks like the operator is not being reported as degraded. If there are issues with the operator, please review the logs and resources related to image-regitry pods. You can also refer the following KCS for further troubleshooting:${RESET}${RED} https://access.redhat.com/solutions/3804741${RESET}"
    else
        echo -e "${YELLOW}Searching for KCS Solutions...${RESET}"
        api_url="https://api.access.redhat.com/support/search/kcs?fq=documentKind:(%22Solution%22)&q=*$search_string*&rows=3&start=0"
	
	      # Make the API call and store the response in a variable
        api_response=$(curl -s -X GET -u "$username:$pass" "$api_url")

        # Check if the API call was successful (HTTP status code 200)
        http_status_code=$(curl -s -o /dev/null -w "%{http_code}" "$api_url")

        if [ "$http_status_code" -eq 200 ]; then
            echo "API call was successful."
            echo "API Response:"
            echo "$api_response" | grep -o 'https://access.redhat.com/solutions/[^ ]*' | sed -e 's/["}].*//'
            echo "this KCS also might help  https://access.redhat.com/solutions/7059756"
        else
            echo "API call failed with HTTP status code $http_status_code."
        fi
    fi
}

get_prometheus_graph_links() {
    echo
    echo -e "${YELLOW}Running prometheus queries...${RESET}"
    echo -e "${YELLOW}Please navigate to the following links to review metrics related to the image registry operator:${RESET}"
    echo

    command_to_run="ocm backplane console $cluster_id"

    # Define the file to store the command output
    output_file="console_url_file.txt"

    # Step 1: Open a new terminal, run the command, and store its output
    gnome-terminal -- bash -c "$command_to_run > $output_file; read -n 1 -p 'Press any key to exit.'; exit"

    sleep 60

    console_url=$(grep -o 'http[^\ ]*' $output_file)

    echo -e "${GREEN}1. MONITORING DASHBOARD for namespace/openshift-kube-controller-manager: ${RESET}"
    query="monitoring/dashboards/grafana-dashboard-k8s-resources-workloads-namespace?namespace=openshift-kube-controller-manager&type=pod"
    echo
    query_url="$console_url/$query"
    echo -e "$query_url"
    echo
    echo -e "${GREEN}2. Query Executed:${RESET} kube_job_status_failed{namespace="openshift-kube-controller-manager"}"
    echo -e "This query provides information about the ${GREEN}FAILED${RESET} jobs inside the namespace/openshift-image_registry"
    echo
    query="monitoring/query-browser?query0=kube_job_status_failed%7Bnamespace%3D%22openshift-kube-controller-manager%22%7D"
    query_url="$console_url/$query"
    echo -e "$query_url"
    echo
}

main() {
    login_via_backplane
    get_basic_info
    check_image_registry_operator_status
    check_operator_resources
    check_image_registry_operator_pod_logs
    check_image_registry_pod_logs
    check_other_configuration
    job_pruning_issues
    build_search_string
    search_kcs
    get_prometheus_graph_links
    print_additional_info
}

main
