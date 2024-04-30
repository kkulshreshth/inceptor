#!/usr/bin/env bash


BDEF='\x1B[1m'
BRED='\x1B[1;31m'
RED='\x1B[0;31m'
BYEL='\x1B[1;33m'
YEL='\x1B[0;33m'
BGRN='\x1B[1;32m'
GRN='\x1B[0;32m'
GREY='\x1B[0;90m'

NC='\x1B[0m' # RESET

operators=()
mode=''
# search_strings=()
declare -A search_strings

.

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
  echo -e "\n${YEL}Logging into cluster \"${cluster_id}\" via backplane...${NC}\n"
  ocm_outuput=$(ocm backplane login $cluster_id)
  whoami_output=$(oc whoami 2>&1)
  if [[ $whoami_output == *"rror"* ]]; then
    echo -e "\n${RED}Couldn't login to cluster ${cluster_id}\nexiting..${NC}"
    exit 1
  else
    echo -e "\n${GRN}Login successful. ${NC}"
  fi
}

# Login credential ---
inc_get_creds () { 

  username_err_msg="${YEL}Error: Invalid username format${NC}"

  echo -e "\n"
  while true; do
    read -e -p "Enter your username (ex: rhn-support-<kerberos>): " username
    pre_sections=$(echo "$username" | tr '-' ' ' | wc -w)
    sections=${pre_sections//[!0-9]/}
    kerberos_id=$(echo "$username" | cut -d'-' -f 3)

    if [[ $sections -ne 3 ]] || ! echo "$kerberos_id" | grep -q '^[[:alnum:]]*$' ; then
      echo -e $username_err_msg
      continue
    fi
    break 
  done
  
  while true; do
    read -s -p "Password: " password

    password_tokens=$(grep -oE '[[:digit:]]+' <<< $password | sort -rn | head -n1)
    password_spechars=$(grep -o '[[:punct:]]' <<< $password | tr -d '\n')
    password_lowercase=$(grep -o '[[:lower:]]' <<< $password | tr -d '\n')
    password_uppercase=$(grep -o '[[:upper:]]' <<< $password | tr -d '\n')

    login_errors=()
    if (( ${#password_spechars} < 2 )); then login_errors+=("special characters"); fi
    if (( ${#password_tokens} < 6 )); then login_errors+=("6-digit tokens"); fi
    if (( ((${#password_lowercase} + ${#password_uppercase})) < 3 )); then login_errors+=("3 letters"); fi
    if (( ${#password_lowercase} < 1 )); then login_errors+=("one lowercase character (a-z)"); fi
    if (( ${#password_uppercase} < 1 )); then login_errors+=("one uppercase character (A-Z)"); fi
    if (( ${#password} < 14 )); then login_errors+=("14 total length"); fi

    if [[ -n "${login_errors[@]}" ]]; then
      echo -e "${YEL}Password must have at least:${NC}"
      for err in "${login_errors[@]}"; do
        echo -e "${RED} > $err${NC}"
      done
      echo ""
      continue
    fi
    break
  done
}

print_json() {
  OUTPUT_FORMAT="${OUTPUT_FORMAT:-yaml}"

  if [[ $OUTPUT_FORMAT == "yaml" ]]; then
    echo "$*" | jq '.' | sed -E -e 's/\{|\}|\[|\]|\"//g' -e 's/,\s*$//g'
  else
    echo "$*" | jq -C '.'
  fi
}

# To open default browsers when prom links function executed ---
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

# Cloud credential operator function ---

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

  # For prom alert rules - supported operators
  case $prom_namespace in
    openshift-cloud-credential-operator)
    promql_rules_param='cco_credentials_requests_conditions{condition=~"CredentialsDeprovisionFailure|CloudCredentialOperatorDeprovisioningFailed|CloudCredentialOperatorInsufficientCloudCreds|CloudCredentialOperatorProvisioningFailed|CloudCredentialOperatorStaleCredentials|CloudCredentialOperatorTargetNamespaceMissing"}'
    ;;
  esac


  echo -e "${GRN}Collecting console url...${NC}"

  # To ensure no other ocm backplane console session is open to output prom links
  if [[ -z ${console_url} ]]; then
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
    echo -e "Success: ${GRN}$console_url${NC}"
  
  elif [[ $skipped == true ]]; then
    echo -e "${YEL}TIMEDOUT: Console is taking so long to return.${NC}"
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
  # For supported operators
 if [[ -n "$promql_rules_param" ]]; then
    echo -e "\n"
    echo -e "${GRN}3. FIRED ALERT rules for namespace/$prom_namespace${NC}"
    promql_rules_param_encoded=$(jq -rn --arg x ${promql_rules_param} '$x|@uri')
    rules_query="monitoring/query-browser?query0=$promql_rules_param_encoded"
    alert_rules_url="$console_url/$rules_query"
    echo -e "$alert_rules_url"
  fi

  echo -e "\n"
  echo -e "${GRN}Opening urls in browser ..${NC}"
  $OPEN "\"$dash_url\"" &>/dev/null
  $OPEN "\"$failed_jobs_url\"" &>/dev/null
  if [[ -n "$promql_rules_param" ]]; then
    $OPEN "\"$rules_url\"" &>/dev/null
  fi
}

search_kcs() {
  local search_header="openshift-cloud-credential-operator"
  local search_params='documentKind:("Solution")'
  local api_url_pattern="https://api.access.redhat.com/support/search/kcs?fq=P_DATA&q=Q_DATA&rows=3&start=0"

  inc_separator
  if [[ ${#search_strings[@]} -eq 0 ]]; then 
    echo -e "${GRN}No critical issues were detected${NC}"
    return 1
  fi
  echo -e "${YEL}Some issues were detected, trying to collect KCS suggestions${NC}"
  for issue in "${!search_strings[@]}"; do
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

print_additional_info() {
  inc_separator
  inc_title "Additional Information :"
  echo -e "To get in touch with OCP engineering for this operator, join ${GRN}$1${NC} slack channel and ping ${GRN}$2${NC} handle with any queries."
}


# Main ---
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
  cco_conditions=$(oc get co cloud-credential -o json | jq '.status | {status: {"conditions"}}')
  formatted_cco_conditions=$(print_json $cco_conditions | sed -e "s/Degraded/${BRED}&${NC}/g")
  echo -e "$formatted_cco_conditions"

  cco_latest_condition=$(echo "$cco_conditions" | jq '.status.conditions | .[-1]')
  condition_errors=$(echo "$cco_latest_condition" | grep --color=never -o -E 'Degraded|MissingUpgradeableAnnotation')

  while IFS= read -r err_reason; do
    search_strings["$err_reason"]=1
  done <<< "$condition_errors"
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
  read -p "Do you want to open full logs (y/n)? " logs_answer
    case $logs_answer in
      [yY])
        echo -e "${GRN}Collecting all logs ..${NC}"
        
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
        echo -e "${YEL}Please answer (y)es or (n)o${NC}"
      ;;
    esac
  done

 # For KCS search strs of logs ----
  logs_search_patterns=("CredentialsProvisionFailure" "InsufficientCloudCreds" "ebs-cloud-credentials not found" "disabled")
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

#Parsing args ---
case "${1}" in
  check)
    mode="check"
  ;;
  *)
    echo -e "${BRED}Invalid mode \"$1\"${NC}"
    exit 1
  ;;
esac

if [[ ! "$2" =~ ^- ]]; then
  cluster_id=$2; shift; shift
else
  echo -e "${BRED}Missing cluster ID${NC}"
  exit 1
fi

# SUPPORTED OPERATORS
while (( "$#" )); do
  case $1 in
    -cloud-credential)
    operators+=("_cloud_credential_operator")
    ;;
    --yaml)
    OUTPUT_FORMAT="yaml"
    ;;
    --json)
    OUTPUT_FORMAT="json"
    ;;
    *)
    echo -e "${YEL}WARN: \"$1\" is not a supported operator${NC}"
    ;;
  esac
  shift
done

if [[ -z "${operators[@]}" ]]; then
  echo -e "${BRED}No valid operators were provided${NC}"
  exit 1
fi

# setting env and global vars
os_default_browser

# get creds + login
inc_get_creds
inc_login

# collecting general context (common data between operators)
get_basic_info

# running operators
for operator in "${operators[@]}"; do
  run$operator
done