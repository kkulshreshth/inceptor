#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[44m"
RESET="\033[0m"
cluster_id=$1
search_string="cluster%20autoscaler%20operator%20degraded%20in%20OpenShift"

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
    echo -e "\n${YELLOW}Checking top node utilazation status...${RESET}"
    oc adm top node
    echo -e "\n${YELLOW}Checking Machines and it's status...${RESET}"
    oc get machines -n openshift-machine-api
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    

}

# Function to check the status of the Cluster Autoscaler Operator
check_cluster_autoscaler_operator_status() {
    echo
    echo -e "${YELLOW}Checking Cluster Autoscaler Operator Status...${RESET}"
    oc get co cluster-autoscaler
    echo
    echo -e "The below ${GREEN}'.status.conditions'${RESET} section provides insights into the overall health and operational state of the Operator."
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    oc describe co cluster-autoscaler | awk '/^\s*Conditions:/, /^\s*Extension:/{if(/^\s*Extension:/) exit; print}'
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}

# Checking the deployment and pods for cluster_autoscaler
check_operator_resources() {
    echo
    echo -e "${YELLOW}Checking the deployments and pods for cluster-autoscaler...${RESET}"
    echo -e "${GREEN}DEPLOYMENT:${RESET}"
    oc -n openshift-machine-api get deployments
    echo
    echo
    echo -e "${GREEN}PODS:${RESET}"
    oc -n openshift-machine-api get pod
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}


# Checking Cluster Autoscaler config
check_cluster_autoscaler_config() {
    echo
    echo -e "${YELLOW}Checking the config for the cluster-autoscaler...${RESET}"
    echo -e "${GREEN}Config:${RESET}"
    oc -n openshift-machine-api get ca -o yaml
    echo
    echo
}


# Checking Machine Autoscaler config
check_machine_autoscaler_config() {
    echo
    echo -e "${YELLOW}Checking the config for the machine-autoscaler...${RESET}"
    echo -e "${GREEN}Config:${RESET}"
    oc get machineautoscaler -o yaml -n openshift-machine-api
    echo
    echo
}

check_cluster_autoscaler_operator_pod_logs() {
    echo
    echo -e "${YELLOW}Gathering Autoscaler Operator Pod Logs and filtering for known issues.${RESET}"
   
    red_flags=("failed to drain node" "panic:" "signal SIGSEGV" "error" "degraded" "timeout" "expire" "canceled" "RequestError" "Unavailable" "backoff" "failed" "x509" "Skipping" "node group min size reached" "is not suitable for removal" "cannot be removed:" "cpu utilization too big" "pod with local storage present" "pod annotated as not safe to evict present" "is not replicated" "safe-to-evict: false" )

operator_pod=$(oc -n openshift-machine-api get pods --no-headers -o custom-columns=":metadata.name" | grep cluster-autoscaler-operator)

    echo -e "\nPod Name: $operator_pod\n"

    log_output=$(oc -n openshift-machine-api logs deployment/cluster-autoscaler-operator | grep -E 'failed to drain node|panic|signal SIGSEGV|error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|ImagePrunerDegraded|RequestError|x509|Skipping|node group min size reached|is not suitable for removal|cannot be removed|cpu utilization too big|pod with local storage present|pod annotated as not safe to evict present|is not replicated|safe-to-evict: false')
    colored_logs="$log_output"
    for word in "${red_flags[@]}"; do
        colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
    done

    # Print the colored logs
    echo -e "$colored_logs"
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}

# Checking logs of cluster-autoscaler-default pods
check_cluster_autoscaler_default_pod_logs() {
    echo
    echo -e "${YELLOW}Gathering Cluster Autoscaler Default Pod Logs and filtering for known issues.${RESET}"

    autoscaler_default_pod=$(oc -n openshift-machine-api get pods --no-headers -o custom-columns=":metadata.name" | grep cluster-autoscaler-default)

    echo -e "\nPod Name: $autoscaler_default_pod\n"


    red_flags=("failed to drain node" "panic:" "signal SIGSEGV" "error" "degraded" "timeout" "expire" "canceled" "RequestError" "Unavailable" "backoff" "failed" "x509" "Skipping" "node group min size reached" "is not suitable for removal" "cannot be removed:" "cpu utilization too big" "pod with local storage present" "pod annotated as not safe to evict present" "is not replicated" "safe-to-evict: false" )

    echo

    log_output=$(oc -n openshift-machine-api logs deploy/cluster-autoscaler-default | awk 'match ($0, PAT) && ++T[substr($0, RSTART, RLENGTH)]<10' PAT="failed to drain node|panic|signal SIGSEGV|error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|ImagePrunerDegraded|RequestError|x509|Skipping|node group min size reached|is not suitable for removal|cannot be removed|cpu utilization too big|pod with local storage present|pod annotated as not safe to evict present|is not replicated|safe-to-evict: false")


    colored_logs="$log_output"
    for word in "${red_flags[@]}"; do
        colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
    done

    # Print the colored logs
    echo -e "$colored_logs"
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}

# Checking logs of machine-api-contoller pods
check_machine_api_controller_pod_logs() {
    echo
    echo -e "${YELLOW}Gathering Machine API Controller Pod Logs and filtering for known issues.${RESET}\n"
    machine_api_pod=$(oc -n openshift-machine-api get pods --no-headers -o custom-columns=":metadata.name" | grep machine-api-controllers)

    echo -e "\nPod Name: $machine_api_pod\n"


    red_flags=("failed to drain node" "panic:" "signal SIGSEGV" "error" "degraded" "timeout" "expire" "canceled" "RequestError" "Unavailable" "backoff" "failed" "x509" "Skipping" "node group min size reached" "is not suitable for removal" "cannot be removed:" "cpu utilization too big" "pod with local storage present" "pod annotated as not safe to evict present" "is not replicated" "safe-to-evict: false" )

    echo

    log_output=$(oc logs deploy/machine-api-controllers -n openshift-machine-api | grep -E 'failed to drain node|panic|signal SIGSEGV|error|failed|degraded|timeout|expire|canceled|Unavailable|backoff|ImagePrunerDegraded|RequestError|x509|Skipping|node group min size reached|is not suitable for removal|cannot be removed|cpu utilization too big|pod with local storage present|pod annotated as not safe to evict present|is not replicated|safe-to-evict: false')

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
    echo -e "${YELLOW}Listing events from namespace/openshift-machine-api${RESET}"
    oc get events -n openshift-machine-api
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo

}



print_additional_info() {
    echo -e "${YELLOW}Additional Information:${RESET}"
    echo -e "To get in touch with OCP engineering for this operator, join ${GREEN}sbr-shift${RESET} slack channel ${GREEN}to handle with any queries."
}

build_search_string() {
    echo
    operator_degraded_message=$(oc get co cluster-autoscaler -o json | jq -r '.status.conditions[] | select(.type == "Degraded") | .message')
    if [ "$operator_degraded_message" == "null" ]; then
        operator_degraded_message=$(oc get co cluster-autoscaler -o json | jq -r '.status.conditions[] | select(.type == "Progressing") | .message')
    fi


    if [ "$operator_degraded_message" == "null" ]; then
        do_kcs_search="false"
    else
        # Strings to search for KCS, will add more strings based on defined errors

#        search_pattern=("node group min size reached" "is not suitable for removal" "cannot be removed" "cpu utilization too big" "pod with local storage present" "pod annotated as not safe to evict present" "is not replicated" "safe-to-evict: false")
        search_pattern=("is not replicated")

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
        echo "NEW SEARCH STRINGS: $search_string"
        echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    fi
}

search_kcs() {
    echo
    if [ "$do_kcs_search" == "false" ]; then
        echo -e "${GREEN}Couldn't build a valid search string. It looks like the operator is not being reported as degraded. If there are issues with the operator, please review the logs and resources related to cluster-operator pods. You can also refer the following KCS for further troubleshooting:${RESET}${RED} https://access.redhat.com/solutions/6821651${RESET}"
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
        else
            echo "API call failed with HTTP status code $http_status_code."
        fi
    fi
}

get_prometheus_graph_links() {
    echo
    echo -e "${YELLOW}Running prometheus queries...${RESET}"
    echo -e "${YELLOW}Please navigate to the following links to review metrics related to the cluater-autoscaler operator:${RESET}"
    echo

    command_to_run="ocm backplane console $cluster_id"

    # Define the file to store the command output
    output_file="console_url_file.txt"

    # Step 1: Open a new terminal, run the command, and store its output
    gnome-terminal -- bash -c "$command_to_run > $output_file; read -n 1 -p 'Press any key to exit.'; exit"

    sleep 60

    console_url=$(grep -o 'http[^\ ]*' $output_file)

    echo -e "${GREEN}1. MONITORING DASHBOARD for namespace/openshift-machine-api: ${RESET}"
    query="monitoring/dashboards/grafana-dashboard-k8s-resources-workloads-namespace?namespace=openshift-machine-api&type=deployment"
    echo
    query_url="$console_url/$query"
    echo -e "$query_url"
    echo
    echo -e "${GREEN}2. Query Executed:${RESET} kube_job_status_failed{namespace="openshift-machine-api"}"
    echo -e "This query provides information about the ${GREEN}FAILED${RESET} jobs inside the namespace/openshift-machine-api"
    echo
    query="monitoring/query-browser?query0=kube_job_status_failed%7Bnamespace%3D%22openshift-machine-api%22%7D"
    query_url="$console_url/$query"
    echo -e "$query_url"
    echo
}

main() {
    login_via_backplane
    get_basic_info
    check_cluster_autoscaler_operator_status
    check_operator_resources
    check_cluster_autoscaler_config
    check_machine_autoscaler_config
    check_cluster_autoscaler_operator_pod_logs
    check_cluster_autoscaler_default_pod_logs
    check_other_configuration
    build_search_string
    search_kcs
    get_prometheus_graph_links
    print_additional_info
}

main
