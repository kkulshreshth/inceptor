#!/bin/bash

# Script to extract the token from the JSON response using curl and jq

# STEP-1:

# Login to cluster via backplane
 GREEN="\033[32m"
 RESET="\033[0m"
 clusterID="${args[clusterid]:-$1}"

echo -e "${GREEN}Logging into the cluster via backplane...${RESET}"
ocm backplane login $clusterID

# Collect info
echo "Enter your username (ex: rhn-support-<kerberos>):"
read USERNAME

echo "Enter support case ID:"
read caseID

secret_name=case-management-creds

# STEP-2:

echo
echo -e "${GREEN}Getting SFTP token...${RESET}"
echo

URL="https://access.redhat.com/hydra/rest/v1/sftp/token/upload/temporary"

# Fetch the JSON response from the server, this will ask for password
response=$(curl -s -u "$USERNAME" "$URL")

# Check if the response is not empty and contains valid JSON
if [[ -n "$response" ]]; then
    # Extract the token using jq
    temp_token=$(echo "$response" | jq -r '.token')

    # Check if the token was successfully extracted
    if [[ -n "$temp_token" ]]; then
        echo "Token extracted successfully."
        echo "Token: $temp_token"
        echo
    else
        echo "Error: Token could not be extracted. Response might be malformed."
        echo "Response: $response"
        echo
    fi
else
    echo "Error: No response received or the response is empty."
fi

# STEP-3:

URL="https://access.redhat.com/hydra/rest/contacts/sso/$USERNAME"

echo -e "${GREEN}Checking if your Hydra user isInternal...${RESET}"
echo 

isInternal=$(curl -s -u "$USERNAME" "$URL" | jq -r .isInternal)
echo "isInternal: "$isInternal""
echo 

# STEP-4: Create a secret in the openshift-must-gather-operator namespace

echo -e "${GREEN}Creating a secret in the openshift-must-gather-operator namespace...${RESET}"
echo

oc create secret generic $secret_name --from-literal=username=$USERNAME --from-literal=password=$temp_token -n openshift-must-gather-operator

# STEP-5: Create a yaml file on your computer

echo -e "${GREEN}Creating mustgather.yaml file on your computer...${RESET}"

# Define the output file
output_file="mustgather.yaml"

# Create the YAML content with replacements
cat << EOF > "$output_file"
apiVersion: managed.openshift.io/v1alpha1
kind: MustGather
metadata:
  name: ${caseID}-must-gather
  namespace: openshift-must-gather-operator
spec:
  caseID: '${caseID}'
  caseManagementAccountSecretRef:
    name: ${secret_name}  
  serviceAccountRef:
    name: must-gather-admin
  internalUser: ${isInternal}
EOF

# Notify the user of the created file
echo "File '$output_file' created successfully with the following content:"
cat "$output_file"

# Step 6: Use the yaml file to create a MustGather CR

echo
echo -e "${GREEN}Creating Mustgather CR...${RESET}"
echo
oc apply -f mustgather.yaml -n openshift-must-gather-operator

# Step 7: Wait for pod in openshift-must-gather-operator namespace to be marked as Completed

echo -e "${GREEN}Watching and waiting for the pods in openshift-must-gather-operator namespace to be marked as Completed...${RESET}"
echo
oc get pods -n openshift-must-gather-operator -w 