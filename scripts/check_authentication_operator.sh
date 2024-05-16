#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[44m"
RESET="\033[0m"
cluster_id="${args[clusterid]:-$1}"
search_string="authentication%20operator%20degraded%20in%20OpenShift"
do_kcs_search="true"
keyword_counter=0

echo "Enter your username (ex: rhn-support-<kerberos>):"
read username

echo "Enter your password:"
read -s pass

# Function to login to the cluster via backplane
login_via_backplane() {
    echo -e "${YELLOW}Logging into the cluster via backplane...${RESET}"
    ocm backplane login $cluster_id
}

# For default browsers when prom links function executed ---
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

# Function to get basic info about the cluster
get_basic_info() {
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo -e "${YELLOW}Listing basic information about the cluster...${RESET}"
    osdctl -S cluster context $cluster_id
    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    echo -e "${YELLOW}Listing the service logs sent in past 30 days...${RESET}"
    osdctl -S servicelog list $cluster_id
    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    echo -e "${YELLOW}Checking node status...${RESET}"
    oc get nodes
    echo
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
}


# Function to check the status of the Authentication Operator
check_authentication_operator() {
    echo
    echo -e "${YELLOW}Checking Authentication Operator Status...${RESET}"
    oc get co authentication
    echo
    echo -e "The below ${GREEN}'.status.conditions'${RESET} section provides insights into the overall health and operational state of the Operator."
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    oc describe co authentication | awk '/^\s*Conditions:/, /^\s*Extension:/{if(/^\s*Extension:/) exit; print}'
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
}

# Checking the deployment and pods for image-registry
check_operator_resources() {
    echo
    echo -e "${YELLOW}Checking the deployment and pods for authentication operator...${RESET}"
    echo -e "${GREEN}DEPLOYMENTS:${RESET}"
    oc -n openshift-authentication-operator get deployments
    oc -n openshift-authentication get deployments
    echo
    echo
    echo -e "${GREEN}PODS:${RESET}"
    oc -n openshift-authentication-operator  get pod
    oc -n openshift-authentication get pod
    echo
}


# Function to gather Authentication Operator logs.
get_authentication_operator_logs() {
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    echo -e "${YELLOW}Gathering Authentication Operator Pod Logs...${RESET}"
    operator_pod=$(oc get pods -n openshift-authentication-operator -o=jsonpath='{.items[0].metadata.name}')
    
    red_flags=("error" "degraded" "timeout" "expire" "canceled" "OAuthServerRouteEndpointAccessibleController" "OAuthServerServiceEndpointAccessibleController reconciliation failed" "IngressStateController reconciliation failed")

    if [ -n "$operator_pod" ]; then
        echo -e "${GREEN}OPERATOR POD NAME: $operator_pod${RESET}"
        echo
        log_output=$(oc --tail 25 logs -n openshift-authentication-operator "$operator_pod")

        colored_logs="$log_output"
        for word in "${red_flags[@]}"; do
            colored_logs=$(echo -e "${colored_logs//$word/\\033[31m$word\\033[0m}")
        done

        # Print the colored logs
        echo -e "$colored_logs"
    else
        echo "No Authentication Operator pod found."
    fi
}

# Build keyword search string for searching KCS solutions:
build_search_string() {
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo -e "${YELLOW}Building search string${RESET}"
    echo
    operator_degraded_message=$(oc get co authentication -o json | jq -r '.status.conditions[] | select(.type == "Degraded" and .status == "True") | .message')
    if [ -z "$operator_degraded_message" ]; then
        operator_degraded_message=$(oc get co authentication -o json | jq -r '.status.conditions[] | select(.type == "Progressing" and .status == "True") | .message')
    fi

    #echo -e "OPERTOR MESSAGE : $operator_degraded_message"

    if [ -z "$operator_degraded_message" ]; then
        do_kcs_search="false"
    else
        # Strings to search for
        search_pattern=("OAuthServerConfigObservationDegraded: failed to apply IDP" "OAuthServerRouteEndpointAccessibleControllerDegraded" "ProxyConfigControllerDegraded" "APIServerDeploymentDegraded" "OAuthServerConfigObservationDegraded: error validating configMap" "ngressStateEndpointsDegraded: No endpoints found for oauth-server" "RouteStatusDegraded: route is not available")

        # Variable to store the found strings
        found_strings=""

        # Loop through each search string
        for search_str in "${search_pattern[@]}"; do
            # Check if the search string is present in the paragraph
            if [[ $operator_degraded_message =~ $search_str ]]; then
                # If found, append it to the variable
                found_strings="$found_strings $search_str"
                keyword_counter=$keyword_counter + 1
            fi
        done

        if [ "$keyword_counter" -eq 0 ]; then
            # If keyword_counter is  equal to 0, send the original message as found string
            found_strings="$operator_degraded_message"
        fi

        # Print the result
        #echo "Found strings: $found_strings"

        updated_operator_degraded_message=$(echo "$found_strings" | sed 's/ /%20/g')
        search_string="$search_string%20$updated_operator_degraded_message"
        #echo "NEW SEARCH STRINGS: $search_string"
    fi
}

# Search KCS solutions dynamically using hydra API:
search_kcs() {
    echo
    if [ "$do_kcs_search" == "false" ]; then
        echo -e "${GREEN}Couldn't build a valid search string. It looks like the operator is not being reported as degraded. If there are issues with the operator, please review the logs and resources related to oauth pods. You can also refer the following KCS for further troubleshooting:${RESET}${RED} https://access.redhat.com/articles/5900841#operator${RESET}"
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

# Function to gather OAuth server logs
get_oauth_server_logs() {
    echo
    echo -e "${YELLOW}Checking OAuth Pod Status...${RESET}"
    echo 
    echo -e "${GREEN}oc get pods -n openshift-authentication${RESET}"
    oc get pods -n openshift-authentication
    echo
    echo -e "${YELLOW}Gathering OAuth Server Logs...${RESET}"
    oauth_pod=$(oc get pods -n openshift-authentication -o=jsonpath='{.items[?(@.metadata.labels.app=="oauth-openshift")].metadata.name}')
    
    if [ -n "$oauth_pod" ]; then
        pod1=$(oc get pod -n openshift-authentication | awk 'NR==2{print $1}')
        echo
        echo -e "${GREEN}Capturing logs from pod/$pod1${RESET}"
        oc --tail 10 logs $pod1 -n openshift-authentication
        
        pod2=$(oc get pod -n openshift-authentication | awk 'NR==3{print $1}')
        echo
        echo -e "${GREEN}Capturing logs from pod/$pod2${RESET}"
        oc --tail 10 logs $pod2 -n openshift-authentication
        
        pod3=$(oc get pod -n openshift-authentication | awk 'NR==4{print $1}')
        echo
        echo -e "${GREEN}Capturing logs from pod/$pod3${RESET}"
        oc --tail 10 logs $pod3 -n openshift-authentication
        echo
    else
        echo "No OAuth Server pod found."
    fi
}

get_users_and_identities() {
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    # Check user and identity count
    echo -e "${YELLOW}Checking user and identity count for any discrepency. The user count is always greater than the identity count due to backplane user. If this difference is more than 1, it is considered an a discrepency.${RESET}"
    user_count=$(oc get users | grep -v NAME | wc -l)
    echo -e "${GREEN}USERS COUNT${RESET} = $user_count"

    identity_count=$(oc get identity | grep -v NAME | wc -l)
    echo -e "${GREEN}IDENTITY COUNT${RESET} = $identity_count"

    difference=$(echo "scale=2; $user_count - $identity_count" | bc)

    # Check if the difference is greater than 1
    if (( $(echo "$difference > 1" | bc -l) )); then
        echo -e "${YELLOW}There appears to be a discrepency in the user and identity count. Please review the below listed user and identity to find out the discrepency.${RESET}"
        echo -e "${YELLOW}Listing Users...${RESET}"
        oc get users
        echo
	#print_horizontal_line "-" 120
        echo -e "${YELLOW}Listing identities...${RESET}"
        oc get identity
        echo
    else
        echo -e "${GREEN}As per the analysis, there is no discrepency in the user/identity count.${RESET}"
    fi
}

gather_route_data(){
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo -e "${YELLOW}Gathering data for route...${RESET}"
    echo
    echo -e "${GREEN}oc get route -n openshift-authentication${RESET}"
    oc get route -n openshift-authentication
    echo
}

get_prometheus_graph_links() {
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo
    echo -e "${YELLOW}Running prometheus queries...${RESET}"
    echo -e "${YELLOW}Please navigate to the following links to review metrics related to the authentication operator:${RESET}"
    echo

    echo -e "${GRN}Collecting console url...${NC}"
    console_output_file="TEMP_CONSOLE.txt"


    # For backplane console runs in the same terminal
    if [[ -z ${console_url} ]]; then
        podman machine init &> /dev/null
        sleep 1
        podman machine start &> /dev/null
        podman container rm --all --force -i --depend &> /dev/null

        pkill -9 -f "backplane console"
        sleep 15
        rm $console_output_file &> /dev/null

        touch $console_output_file

    # Capturing Console URL ---
        ocm backplane console >> $console_output_file 2>&1  &

        local skipped=true
        for i in $(seq 1 240); do
        if grep -q -e "http" -e "rror" $console_output_file; then
            console_url=$( cat $console_output_file | awk '/available at/ {print $6}')
            skipped=false
            break
        fi
        sleep 1
        done
    fi

    # Console URL fetched ---
    if echo "$console_url" | grep -q "http"; then
        echo -e "Success: ${GRN}$console_url${NC}\n"

    elif [[ $skipped == true ]]; then
        echo -e "${YEL}TIMEOUT ERROR: Unable to retrieve the Console URL.${NC}"
        echo -e "skipping prometheus..."
        console_url=""
        return 1

    else
        local console_error=$(<$console_output_file)
        echo -e "${YEL}The following error occurs while trying to get console URL:\n${RED}--\n$console_error\n--${NC}"
        echo -e "skipping prometheus..."
        console_url=""
        return 1
    fi


    echo -e "${GREEN}1. MONITORING DASHBOARD for namespace/openshift-authentication: ${RESET}"
    query="monitoring/dashboards/grafana-dashboard-k8s-resources-workloads-namespace?namespace=openshift-authentication&type=deployment"
    echo
    query_url="$console_url/$query"
    echo -e "$query_url"
    $OPEN "$query_url" &>/dev/null
    sleep 1
    echo

    echo -e "${GREEN}2. MONITORING DASHBOARD for namespace/openshift-authentication-operator: ${RESET}"
    query="monitoring/dashboards/grafana-dashboard-k8s-resources-workloads-namespace?namespace=openshift-authentication-operator&type=deployment"
    echo
    query_url="$console_url/$query"
    echo -e "$query_url"
    $OPEN "$query_url" &>/dev/null
    sleep 1
    echo

    echo -e "${GREEN}3. Query Executed:${RESET} ${YELLOW}up{service="metrics", namespace="openshift-authentication-operator"}${RESET}"
    echo -e "This query provides information about the ${GREEN}up${RESET} status of service inside the namespace/openshift-authentication-operator"
    query="up%7Bservice%3D%22metrics%22%2C+namespace%3D%22openshift-authentication-operator%22%7D"
    query_url="$console_url/monitoring/query-browser?query0=$query"
    echo -e "$query_url"
    $OPEN "$query_url" &>/dev/null
    sleep 1
    echo

    echo -e "${GREEN}4. Query Executed:${RESET} ${YELLOW}sum(rate(kube_pod_container_status_restarts_total{pod=~"authentication-operator.*"}[5m]))${RESET}"
    echo -e "This Prometheus query calculates the sum of the per-second rates of pod restarts for ${GREEN}authentication-operator pod${RESET} over the last 5 minutes. It gives you an indication of how frequently containers within authentication operator pods are restarting,"
    query="sum%28rate%28kube_pod_container_status_restarts_total%7Bpod%3D~"authentication-operator.*"%7D%5B5m%5D%29%29"
    query_url="$console_url/monitoring/query-browser?query0=$query"
    echo -e "$query_url"
    $OPEN "$query_url" &>/dev/null
    sleep 1
    echo

    echo -e "${GREEN}5. Query Executed:${RESET} ${YELLOW}sum(rate(kube_pod_container_status_restarts_total{pod=~"oauth-openshift.*"}[5m]))${RESET}"
    echo -e "This Prometheus query calculates the sum of the per-second rates of pod restarts for ${GREEN}oauth pods${RESET} over the last 5 minutes. It gives you an indication of how frequently containers within authentication operator pods are restarting,"
    query="sum%28rate%28kube_pod_container_status_restarts_total%7Bpod%3D~"oauth-openshift.*"%7D%5B5m%5D%29%29"
    query_url="$console_url/monitoring/query-browser?query0=$query"
    echo -e "$query_url"
    $OPEN "$query_url" &>/dev/null
    echo -e "${GREEN}------------------------------------------------------------------------${RESET}"
    echo

    echo -e "${RED}To get in touch with OCP engineering for this operator, join #forum-apiserver slack channel and ping @api-auth-apiserver-component-questions handle with queries.${RESET}"
}

# Main function
main() {
    login_via_backplane
    os_default_browser
    get_basic_info
    check_authentication_operator
    check_operator_resources
    get_authentication_operator_logs
    get_oauth_server_logs
    get_users_and_identities
    gather_route_data
    build_search_string
    search_kcs
    get_prometheus_graph_links
}

main