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
search_string="ingress+controller+%2B+operator+%2B+openshift"
# #- q=ingress+controller+%2B+openshift+in+"access.redhat.com%2Fsolutions"
# - q=ingress+controller+%2B+openshift+in+"access.redhat.com%2Farticles"
# - q=ingress+controller+%2B+operator+%2B+openshift+in+"access.redhat.com%2Fsolutions"
# - q=ingress+controller+%2B+operator+%2B+openshift+in+"access.redhat.com%2Farticles"

# Set a flag to indicate whether to perform Knowledge Center Search
do_kcs_search="true"

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
check_login() {

    read -p "Have you already connected via VPN and logged in into the cluster ? (y/n) " logged_in
    if [[ "$logged_in" == y* || "$logged_in" == Y* ]]; then
        echo
        echo "Awesome! thanks for your confirmation"
    else
        # Echo a message indicating the start of the login process in yellow color
        echo -e "${YELLOW}Logging into the cluster via backplane...${RESET}"
        echo

        # Prompt the user to enter their username
        # Read the input from the user and store it in the variable 'username'
        echo -n "Enter your username (ex: rhn-support-<kerberos>): "
        read username

        # Prompt the user to enter their password (with the '-s' flag to silence input)
        # Read the input from the user without echoing it to the terminal (for password input)
        echo -n "Enter your password: "
        read -s pass


        # Use 'ocm backplane login' command to log into the cluster using the provided 'cluster_id'
        ocm backplane login $cluster_id
        echo
        oc get nodes
    fi
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
    red_flags=("issue" "error" "degrade" "timeout" "expire" "not responding" "overload" "canceled" "RequestError" "Unavailable" "backoff" "failed" "unreachable" "x509" "connection error" "reconciliation failed" "not created" "conflict" "bottleneck" "congestion" "drop" "spike" "imbalance" "misconfiguration")

    # Check if the pods exist
    if [ -n "$oi_pod" ]; then
        # Echo the name of the operator pod
        echo -e "${GREEN}OPERATOR POD NAME: $oi_pod${RESET}"
        echo

        # Get the last 10 lines of logs from the operator pod and filter them for red flags
        log_output=$(oc --tail 10 logs -n openshift-ingress "$oi_pod" | grep -iE 'issue|error|degrade|timeout|expire|not responding|overload|canceled|RequestError|Unavailable|backoff|failed|unreachable|x509|connection error|reconciliation failed|not created|conflict|bottleneck|congestion|drop|spike|imbalance|misconfiguration')

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
        log_output=$(oc --tail 10 logs -n openshift-ingress-operator "$oio_pod" | grep -iE 'issue|error|degrade|timeout|expire|not responding|overload|canceled|RequestError|Unavailable|backoff|failed|unreachable|x509|connection error|reconciliation failed|not created|conflict|bottleneck|congestion|drop|spike|imbalance|misconfiguration')

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

# Function to build search string and find KCS based on operator degraded message

get_kcs() {
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    operator_degraded_message=$(oc get co ingress -o json | jq -r '.status.conditions[] | select(.type == "Degraded" and .status == "True") | .message')
    if [ -z "$operator_degraded_message" ]; then
        operator_degraded_message=$(oc get co ingress -o json | jq -r '.status.conditions[] | select(.type == "Progressing" and .status == "True") | .message')
    fi

    #echo -e "OPERTOR MESSAGE : $operator_degraded_message"

    if [ -z "$operator_degraded_message" ]; then
        do_kcs_search="false"
    else
        # Strings to search for
        search_pattern=("IngressControllerUnavailable" "SyncLoadBalancerFailed" "issue" "error" "degrade" "timeout" "expire" "not responding" "overload" "canceled" "RequestError" "Unavailable" "backoff" "failed" "unreachable" "x509" "connection error" "reconciliation failed" "not created" "conflict" "misconfiguration")

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


        updated_operator_degraded_message=$(echo "$found_strings" | sed 's/ /%20/g')
        updated_search_string="$search_string$updated_operator_degraded_message"

    fi

    echo

    disclaimer="The articles or solutions retrieved via this service may not be entirely suitable for your specific concerns. We advise verifying the content manually before considering or implementing any suggestions provided therein. While we strive to provide accurate information, the responsibility for validation ultimately rests with the user. Thank you for your understanding."

    if [ "$do_kcs_search" == "false" ]; then
        echo -e "${GREEN}We couldn't build a valid search string. It looks like the operator is not being reported as degraded. If there are issues with the operator, please review the logs and resources manually."

        # page1=https://access.redhat.com/solutions?title=ingress&product=91541&category=All&state=published&kcs_state=All&language=en&field_internal_tags_tid=All

        # page2=https://access.redhat.com/articles?title=ingress&kcs_article_type=All&product=91541&category=All&language=en&order=state&sort=desc

    else
        echo -e "${YELLOW}Searching for KCS Solutions...${RESET}"

        api_url_primary="https://api.access.redhat.com/support/search/kcs?fq=documentKind:(%22Solution%22)&q=*$updated_search_string*&rows=3&start=0"

        api_url_secondary="https://api.access.redhat.com/support/search/kcs?fq=documentKind:(%22Solution%22)&q=*$search_string*&rows=3&start=0"

	    # Make the API call and store the response in a variable

        if [[ "$logged_in" == y* || "$logged_in" == Y* ]]; then

            KCS=$(curl -s -X GET "$api_url_primary" | grep -o 'https://access.redhat.com/solutions/[^ ]*' | sed -e 's/["}].*//')

            if [ -z "$KCS" ]; then
                KCS=$(curl -s -X GET "$api_url_secondary" | grep -o 'https://access.redhat.com/solutions/[^ ]*' | sed -e 's/["}].*//')
            else
                # KCS is not empty
                # good to proceed
                echo
            fi
        else
            KCS=$(curl -s -X GET -u "$username:$pass" "$api_url_primary" | grep -o 'https://access.redhat.com/solutions/[^ ]*' | sed -e 's/["}].*//')

            if [ -z "$KCS" ]; then
                KCS=$(curl -s -X GET -u "$username:$pass" "$api_url_secondary" | grep -o 'https://access.redhat.com/solutions/[^ ]*' | sed -e 's/["}].*//')
            else
                # KCS is not empty
                # good to proceed
            echo
            fi
        fi

        # Check if the API call was successful (HTTP status code 200)
        http_status_codep=$(curl -s -o /dev/null -w "%{http_code}" "$api_url_primary")
        http_status_codes=$(curl -s -o /dev/null -w "%{http_code}" "$api_url_secondary")

        if [ "$http_status_codep" -eq 200 ] || [ "$http_status_codes" -eq 200 ] ; then
            echo "Heya! we found some KCS for you : "
            echo $KCS | sed 's/ /\n/g'
            echo
            echo $disclaimer
            echo
        else
            echo "We apologise, the API request for 'KCS Search' has been failed with HTTP status code $http_status_code."
        fi
    fi
}

# Function to generate and display Prometheus graph links related to ingress operator metrics
get_prometheus_graph_links() {
    # echo "I will give you Prometheus graph links()"
    echo "For further concerns you can reach out to the SRE or cloud or regional channel.."

}

# Main function
main() {

    #os_default_browser
    check_login
    #get_basic_info
    #check_ingress_cluster_operator_status

    # Check operator resources, events, operator pod logs and other configurations
    #check_ingress_cluster_operator_resources
    #check_ingress_cluster_operator_events
    #check_ingress_cluster_operator_pod_logs
    #check_ingress_controller_status

    # Build KCS search string, search for KCS solutions, get Prometheus graph links
    #get_kcs
    #search_kcs
    #get_prometheus_graph_links
    echo "main function completed"

}

# =============================== FUNCTION Definition END ====================================

# ===============================================================================================

# ================ MAIN FUNCTION Invoke (which will invoke all other functions) =====================


# Call the main function to start the program execution
main
