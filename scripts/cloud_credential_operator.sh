#!/usr/bin/env bash

BDEF='\x1B[1m'
BRED='\x1B[1;31m'
RED='\x1B[0;31m'
BYEL='\x1B[1;33m'
YEL='\x1B[0;33m'
BGRN='\x1B[1;32m'
GRN='\x1B[0;32m'
NC='\x1B[0m' # RESET
cluster_id=$1

# For KCS search string
declare -A search_strings

# Title, separator, logs format ---
inc_title() {
  echo -e "${YEL}$*${NC}\n"
}

inc_separator() {
    echo -e "\n${GRN}------------------------------------------------------------------------${NC}"
}

format_logs() {
  while IFS= read -r line; do
    echo $line | sed -e "s/info/${BDEF}&${NC}/" -e "s/\(error\|timeout\|unavailable\)/${BRED}&${NC}/" -e "s/warning/${BYEL}&${NC}/"
  done <<< "$1"
}

# Cluster login via ocm backplane ---
inc_login() {
  echo -e "\n${YEL}Logging into cluster via backplane...${NC}\n"
  ocm_outuput=$(ocm backplane login $cluster_id)
  whoami_output=$(oc whoami 2>&1)
  if [[ $whoami_output == *"rror"* ]]; then
    echo -e "\n${RED}Couldn't login to cluster ${cluster_id}\nexiting..${NC}"
    exit 1
  else
    echo -e "\n${GRN}Login successful. ${NC}"
  fi
}


print_json() {
  OUTPUT_FORMAT="${OUTPUT_FORMAT:-yaml}"

  if [[ $OUTPUT_FORMAT == "yaml" ]]; then
    echo "$*" | jq '.' | sed -E -e 's/\{|\}|\[|\]|\"//g' -e 's/,\s*$//g'
  else
    echo "$*" | jq -C '.'
  fi
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

# Cluster Basic information ---
get_basic_info() {
  inc_separator
  inc_title "Listing basic information about the cluster..."
  osdctl -S cluster context $cluster_id
  
  inc_separator
  inc_title "Listing the service logs sent in past 30 days..."
  osdctl -S servicelog list $cluster_id

  inc_separator
  inc_title "Checking node status..."
  oc get nodes
}

# Additional Information
print_additional_info() {
  inc_separator
  inc_title "Additional Information :"
  echo -e "To get in touch with OCP engineering for this operator, join ${GRN}$1${NC} slack channel for any inquiries."
}

 # Prometheus link --- 
 # For supported operators
get_prometheus_graph_links() {
  local prom_namespace
  local promql_rules_param
  local rules_url

  # Timeout period for console URL (in seconds) 
  local timeout=240

  console_output_file="TEMP_CONSOLE.txt"


  inc_separator
  prom_namespace=$1
  inc_title "prometheus metrics related to $prom_namespace"

  # For prom alert rules
  case $prom_namespace in
    openshift-cloud-credential-operator)
    promql_rules_param='cco_credentials_requests_conditions{condition=~"CredentialsDeprovisionFailure|CloudCredentialOperatorDeprovisioningFailed|CloudCredentialOperatorInsufficientCloudCreds|CloudCredentialOperatorProvisioningFailed|CloudCredentialOperatorStaleCredentials|CloudCredentialOperatorTargetNamespaceMissing"}'
    ;;
  esac


  echo -e "${GRN}Collecting console url...${NC}"

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
    for i in $(seq 1 $timeout); do
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


 # Dashboard ----
  echo -e "${GRN}1. MONITORING DASHBOARD${NC}"
  dashboard_query="monitoring/dashboards/grafana-dashboard-k8s-resources-workloads-namespace?namespace=$prom_namespace&type=deployment"
  dashboard_url="$console_url/$dashboard_query"
  echo -e "$dashboard_url"

  
  # Failed jobs ----
  echo -e "\n"
  echo -e "${GRN}2. FAILED jobs inside the namespace/$prom_namespace${NC}"
  promql_param='kube_job_status_failed{namespace="USED_NAMESPACE"}'
  promql_param_encoded=$(jq -rn --arg x ${promql_param//USED_NAMESPACE/$prom_namespace} '$x|@uri')
  failed_jobs_query="monitoring/query-browser?query0=$promql_param_encoded"
  failed_jobs_url="$console_url/$failed_jobs_query"
  echo -e "$failed_jobs_url"

  # Prometheus alert rules --- 
  # NOTE: For supported operators
  if [[ -n "$promql_rules_param" ]]; then
      echo -e "\n"
      echo -e "${GRN}3. FIRED ALERT rules for namespace/$prom_namespace${NC}"
      promql_rules_param_encoded=$(jq -rn --arg x ${promql_rules_param} '$x|@uri')
      rules_query="monitoring/query-browser?query0=$promql_rules_param_encoded"
      alert_rules_url="$console_url/$rules_query"
      echo -e "$alert_rules_url"
  fi

  echo -e "\n"
  echo -e "${GRN}Opening the URLs in the browser ..${NC}"
  $OPEN "$dashboard_url" &>/dev/null
  $OPEN "$failed_jobs_url" &>/dev/null
  if [[ -n "$promql_rules_param" ]]; then
    $OPEN "$alert_rules_url" &>/dev/null
  fi
}

search_kcs() {
  local search_header="openshift-cloud-credential-operator"
  local search_params='documentKind:("Solution")'
  local api_url_pattern="https://api.access.redhat.com/support/search/kcs?fq=P_DATA&q=Q_DATA&rows=3&start=0"

  inc_separator
  if [[ ${#search_strings[@]} -eq 0 ]]; then 
    echo -e "${GRN}Couldn't build a valid search string. It looks like the operator is not being reported as degraded. If there are issues with the operator, please review the logs and resources related to cloud-credential pods${NC}"
    return 1
  fi
  echo -e "${YEL}Searching for KCS Solutions...${NC}"
  for issue in "${!search_strings[@]}"; do
    issue="${issue##*:}"
    compiled_search="$search_header $issue"
    compiled_search_encoded=$(jq -rn --arg x "$compiled_search" '$x|@uri')
    search_params_encoded=$(jq -rn --arg x "$search_params" '$x|@uri')

    api_url="$api_url_pattern"
    api_url=${api_url//P_DATA/$search_params_encoded}
    api_url=${api_url//Q_DATA/$compiled_search_encoded}

    echo -e "\nDetected issue: ${YEL}$issue${NC}"
    echo -e "Suggested KCS solution(s):"

    kcs_solutions=$(curl -s -u "$username:$password" "$api_url" | jq -r '.response.docs | .[] | .view_uri')
    echo -e "${GRN}${kcs_solutions:-Nothing was found}${NC}"
    echo -e ""
  done
}


### Cloud credential ###
run_cloud_credential_operator() {
  cco_status
  cco_pods
  cco_resource
  cco_pod_logs
  search_kcs
  get_prometheus_graph_links "openshift-cloud-credential-operator"
  print_additional_info "forum-cloud-credential-operator"
}

cco_status() {
  inc_separator
  local cco_conditions

  inc_title "Checking status for Cloud Credential Operator..."
  oc get co cloud-credential
  cco_conditions=$(oc get co cloud-credential -o json | jq '.status | {status: {"conditions"}} | .status.conditions |= sort_by(.lastTransitionTime) | .status.conditions |= reverse')

  formatted_cco_conditions=$(print_json $cco_conditions | sed -e "s/Degraded/${BRED}&${NC}/g")
  echo -e "$formatted_cco_conditions"

  degraded_messages=$(echo "$cco_conditions" | jq '.status.conditions | .[] | select(.type == "Degraded" and .status == "True") | .message')
  progressing_messages=$(echo "$cco_conditions" | jq '.status.conditions | .[] | select(.type == "Progressing" and .status == "True") | .message')

  if [[ -n $degraded_messages ]]; then
    error_messages=$(echo -e "$degraded_messages" | head -n 1)
  elif [[ -n $progressing_messages ]];then
    error_messages=$(echo -e "$progressing_messages" | head -n 1)
  fi

  while IFS= read -r err_msg; do
    if [[ -n $err_msg ]]; then search_strings["$err_msg"]=1; fi
  done <<< "$error_messages"

}

cco_pods() {
  inc_separator
  inc_title "Checking pods status for Cloud Credential Operator..."
  oc -n openshift-cloud-credential-operator get pods
}

cco_resource() {
  inc_separator
  inc_title "Checking cloud credential resource.."
  oc get cloudcredential cluster -o yaml
}

cco_pod_logs() {
  inc_separator
  local pod_logs
  local logs_answer
  local full_pod_logs
  local default_logs=15

  inc_title "Gathering pod logs for Cloud Credential Operator..."
  pod_logs=$(oc -n openshift-cloud-credential-operator logs --tail=$default_logs deployment/cloud-credential-operator -c cloud-credential-operator)

  if [[ -z $pod_logs ]]; then
    echo -e "\n${YEL}No logs were found\nskipping ...${NC}"
    return 1
  fi

  local formated_pod_logs=$(format_logs "$pod_logs")
  echo -e "$formated_pod_logs"

  while true; do
  echo -e "\n"
  read -p "Do you want to open the full logs (y/n)? " logs_answer
    case $logs_answer in
      [yY])
        echo -e "${GRN}Collecting the full logs ..${NC}"
        
        #For full logs (1000 logs)
        full_pod_logs=$(oc -n openshift-cloud-credential-operator logs --tail=1000 deployment/cloud-credential-operator -c cloud-credential-operator 2>&1)
        local formatted_full_pod_logs=$(format_logs "$full_pod_logs")
        echo -e "$formatted_full_pod_logs" | less -r
        break
      ;;
      [nN])
        break
      ;;
      *)
        echo -e "${YEL}Invalid input. Please answer (y)es or (n)o${NC}"
      ;;
    esac
  done

 # For KCS search strs of logs ----
  logs_search_patterns=("CredentialsProvisionFailure" "InsufficientCloudCreds" "ebs-cloud-credentials not found" "disabled" "empty awsSTSIAMRoleARN" "InvalidClientTokenId" "unable to read info for username")
  for search_str in "${logs_search_patterns[@]}"; do
    err_logs=$(grep --color=never -F "${search_str}" <<< ${full_pod_logs:-$pod_logs})
    if [[ -z $err_logs ]]; then continue; fi

    while IFS= read -r line; do
      err_msg=$(echo $line | grep -m 1 -o 'msg="[^"]*"')
      err_msg=${err_msg#msg=\"} ; err_msg=${err_msg%\"}
      search_strings["$err_msg"]=1
    done <<< "$err_logs"
  done
}

main() {
  if [[ -z $cluster_id ]]; then echo -e "${YEL}missing cluster ID${NC}"; exit 1; fi
  os_default_browser
  inc_login
  get_basic_info
  run_cloud_credential_operator
}

main
