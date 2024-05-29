#!/bin/bash


# clear the terminal
clear

# Set color codes for formatting terminal output
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;44m"
RESET="\033[0m"

# Assign the first command-line argument to the variable 'cluster_id'
cluster_id=$1

# Initialize a search string for Knowledge Center Search
search_string="ingress+controller+%2B+operator+%2B+openshift"
# - q=ingress+controller+%2B+openshift+in+"access.redhat.com%2Fsolutions"
# - q=ingress+controller+%2B+openshift+in+"access.redhat.com%2Farticles"
# - q=ingress+controller+%2B+operator+%2B+openshift+in+"access.redhat.com%2Fsolutions"
# - q=ingress+controller+%2B+operator+%2B+openshift+in+"access.redhat.com%2Farticles"

# Set a flag to indicate whether to perform Knowledge Center Search
do_kcs_search="true"

# declaring a global variable to capture if user is logged in or not
logged_in=""

echo
echo

# ===============================================================================================
# =============================== FUNCTION Definition Start ====================================

# Define a function named to check if logged in / if not; do login.
check_login() {

    read -p "Have you already connected via VPN and logged in into the cluster ? (y/n) " logged_in
    if [[ "$logged_in" == y* || "$logged_in" == Y* ]]; then
        echo
        echo "Awesome! thanks for your confirmation"
    else
        echo
        echo -e "${YELLOW}Let me login into the cluster for you ... ${RESET}"
        echo

        # Prompt the user to enter their username
        # Read the input from the user and store it in the variable 'username'
        echo -n "Enter your username (ex: rhn-support-<kerberos>): "
        read username

        # Prompt the user to enter their password (with the '-s' flag to silence input)
        # Read the input from the user without echoing it to the terminal (for password input)
        echo -n "Enter your password: "
        read -s pass

        echo
        echo
        echo -e "${YELLOW}Logging into the cluster via backplane...${RESET}"

        # Use 'ocm backplane login' command to log into the cluster using the provided 'cluster_id'
        ocm backplane login $cluster_id
        echo

    fi
}

# Define a function named 'get_basic_info'
get_basic_info() {
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo
    echo -e "${YELLOW}Listing basic information about the cluster...${RESET}"
    echo

    # Use 'osdctl cluster context' command to display cluster context using the provided 'cluster_id'
    osdctl -S cluster context $cluster_id

    echo

    # Echo a separator line in green color for visual distinction
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo

    echo -e "${YELLOW}Listing the service logs sent in past 30 days...${RESET}"

    # Use 'osdctl servicelog list' command to list service logs for the provided 'cluster_id'
    osdctl -S servicelog list $cluster_id

    echo

    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo

    echo -e "${YELLOW}Checking cluster version, node and all cluster operator status...${RESET}"
    echo
    oc get clusterversion; echo; echo; oc get nodes; echo; echo; oc get co

    echo

    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}

# Function to check ingress cluster operator status.
check_ingress_cluster_operator_status() {
    echo

    echo -e "${YELLOW}Checking Ingress Operator Status...${RESET}"

    # Use 'oc get co ingress' command to get the status of the Ingress Cluster Operator
    echo
    oc get co ingress
    echo

    # Provide information about the '.status.conditions' section and its significance
    echo -e "The below ${GREEN}'.status.conditions'${RESET} section provides insights into the overall health and operational state of the Operator."

    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo

    # Use 'oc describe co ingress' command to get detailed information about the Ingress Cluster Operator
    # Pipe the output to 'awk' to filter and print the relevant '.status.conditions' section
    oc describe co ingress | awk '/^\s*Conditions:/, /^\s*Extension:/{if(/^\s*Extension:/) exit; print}'

    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo
}

# Function to check the deployment and pods for ingress
check_ingress_cluster_operator_resources() {

    echo -e "${YELLOW}Checking the deployment and pods in openshift-ingress namespace...${RESET}"
    echo

    echo -e "${GREEN}DEPLOYMENT:${RESET}"

    # Use 'oc' command to get deployments in the namespace 'openshift-ingress'
    oc -n openshift-ingress get deployments

    echo
    echo

    echo -e "${GREEN}PODS:${RESET}"

    # Use 'oc' command to get pods in the namespace 'openshift-ingress'
    oc -n openshift-ingress get pods

    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo

    echo -e "${YELLOW}Checking the deployment and pods in openshift-ingress-operator namespace...${RESET}"
    echo

    echo -e "${GREEN}DEPLOYMENT:${RESET}"

    # Use 'oc' command to get deployments in the namespace 'openshift-ingress'
    oc -n openshift-ingress-operator get deployments

    echo
    echo

    echo -e "${GREEN}PODS:${RESET}"

    # Use 'oc' command to get pods in the namespace 'openshift-ingress'
    oc -n openshift-ingress-operator get pods

    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo
}


# Function to check the namespace events for ingress
check_ingress_cluster_operator_events(){

    echo -e "${YELLOW}Listing events from namespace/openshift-ingess${RESET}"
    echo

    # Use 'oc get events' command to get events in namespace 'openshift-ingess'
    oc get events -n openshift-ingress

    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"

    echo
    echo

    echo -e "${YELLOW}Listing events from namespace/openshift-ingess-operator .. ${RESET}"

    echo

    # Use 'oc get events' command to get events in namespace 'openshift-ingess'
    oc get events -n openshift-ingress-operator

    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}

# Function to gather all Ingress related Pod Logs
check_ingress_cluster_operator_pod_logs() {

    echo

    echo -e "${YELLOW}Gathering openshift-ingress Pod Logs...${RESET}"
    echo

    # Get the name of the openshift-ingress pod
    oi_pod=$(oc -n openshift-ingress get pods --no-headers -o custom-columns=":metadata.name")

    # Define red flags indicating potential issues in logs
    red_flags=("issue" "error" "degrade" "timeout" "expire" "not responding" "overload" "canceled" "RequestError" "Unavailable" "backoff" "failed" "unreachable" "x509" "connection error" "reconciliation failed" "not created" "conflict" "bottleneck" "congestion" "drop" "spike" "imbalance" "misconfiguration")

    # Check if the pods exist
    if [ -n "$oi_pod" ]; then

        for pod in $oi_pod; do
            # Echo the name of the operator pod
            echo
            echo -e "${GREEN}INGRESS POD NAME: $pod${RESET}"
            echo

            # Get the last 10 lines of logs from the operator pod and filter them for red flags
            log_output=$(oc --tail 20 logs -n openshift-ingress "$pod" | grep -iE 'issue|error|degrade|timeout|expire|not responding|overload|canceled|RequestError|Unavailable|backoff|failed|unreachable|x509|connection error|reconciliation failed|not created|conflict|congestion|misconfigur')

            # Colorize the logs containing red flags
            colored_logs="$log_output"
            for word in "${red_flags[@]}"; do
                colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
            done

            # Print the colorized logs
            echo -e "$colored_logs"
        done
    else
        # Echo a message if no operator pod is found
        echo "No Ingress pods found."
    fi

    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo

    echo -e "${YELLOW}Gathering openshift-ingress-operator Pod Logs...${RESET}"
    echo

    # Get the name of the openshift-ingress-operator pod
    oio_pod=$(oc -n openshift-ingress-operator get pods --no-headers -o custom-columns=":metadata.name")

    # Check if the pods exist
    if [ -n "$oio_pod" ]; then

        for pod in $oio_pod; do
            # Echo the name of the operator pod
            echo
            echo -e "${GREEN}INGRESS OPERATOR POD NAME: $pod${RESET}"
            echo

            # Get the last 10 lines of logs from the operator pod and filter them for red flags
            log_output=$(oc --tail 10 logs -n openshift-ingress-operator "$pod" | grep -iE 'issue|error|degrade|timeout|expire|not responding|overload|canceled|RequestError|Unavailable|backoff|failed|unreachable|x509|connection error|reconciliation failed|not created|conflict|congestion|misconfigur')

            # Colorize the logs containing red flags
            colored_logs="$log_output"
            for word in "${red_flags[@]}"; do
                colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
            done

            # Print the colorized logs
            echo -e "$colored_logs"
        done
    else
        # Echo a message if no operator pod is found
        echo "No Ingress Operator pod found."
    fi

    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}


# Function to check other configurations related to ingess
check_ingress_controller_status() {
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
        search_pattern=("IngressControllerUnavailable" "SyncLoadBalancerFailed" "issue" "error" "degrade" "timeout" "expire" "not responding" "canceled" "RequestError" "Unavailable" "backoff" "failed" "unreachable" "x509" "connection error" "reconciliation failed" "misconfigur")

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

    disclaimer="Content retrieved via this service may not fully address your specific concerns. Please verify information manually before implementing any suggestions. As we are in the development phase, your understanding is appreciated. Thank you."

    if [ "$do_kcs_search" == "false" ]; then

        echo -e "${GREEN}We couldn't build a valid search string. It looks like the operator is not being reported as degraded. If there are issues with the operator, please review the logs and resources manually.${RESET}"

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

# Function to display any additional information
other_info() {
    echo
    echo "For further concerns you can reach out to the SRE or cloudy or regional channel. Additionally, you can check the other network configurations such as certificates, loadbalancer configurations and check other cluster operators too ..."
    echo
    echo "Thank you for trying our service, hope to serve you the best!"
    echo
    if [[ "$logged_in" == y* || "$logged_in" == Y* ]]; then
        echo
    else
        ocm backplane logout &> /dev/null
    fi

}

# Main function
main() {

    # perform cluster login, basic checks.
    check_login
    get_basic_info

    # start looking into ingress things
    check_ingress_cluster_operator_status
    check_ingress_cluster_operator_resources
    check_ingress_cluster_operator_events

    # dig deep into ingress
    check_ingress_cluster_operator_pod_logs
    check_ingress_controller_status

    # Build KCS search string, search for KCS solutions and some other info + log out from cluster.
    get_kcs
    other_info

}

# =============================== FUNCTION Definition END ====================================

# ================================ MAIN FUNCTION Invoke ======================================


# Call the main function to start the program execution
main
