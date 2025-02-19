#!/bin/bash

# Step-1: Describe the cluster using the provided cluster ID
CLUSTER_ID="${args[clusterid]:-$1}"
CLUSTER_DESCRIPTION=$(ocm describe cluster "$CLUSTER_ID" 2>/dev/null)

# Check if the describe command was successful
if [ $? -ne 0 ]; then
  echo "Failed to describe the cluster. Please ensure the cluster ID is correct and OCM CLI is configured."
  exit 1
fi

# Function to perform pre-checks
pre_checks() {
  # CHECK-1: Verify if the cluster is HCP
  HCP_VALUE=$(echo "$CLUSTER_DESCRIPTION" | grep -E '^ *HCP:' | awk '{print $2}')
  
  if [ "$HCP_VALUE" == "true" ]; then
    echo "This is an HCP cluster. Kindly open an OHSS ticket to raise a request for moving this cluster into limited support."
    exit 1
  else
    echo "This is a ROSA classic cluster."
  fi

  # CHECK-2: Ask user confirmation for contractual obligations
  echo "Confirm Customer understands the contractual obligations of confidentiality and disclosure for vulnerabilities identified, as described in Red Hat Online Subscriptions Product Appendix 4."
  echo "Product Appendix 4: https://www.redhat.com/licenses/Appendix_4_Red_Hat_Online_Services_20220720.pdf?extIdCarryOver=true&sc_cid=701f2000001Css5AAC"
  read -p "Have we received an explicit consent from the customer on Product Appendix 4? (Y/N): " RESPONSE1
  if [[ ! "$RESPONSE1" =~ ^[Yy](es)?$ ]]; then
    echo "Customer did not acknowledge the contractual obligations. Exiting."
    exit 1
  fi

  echo "Confirm Customer understands AWS policies on Penetration Testing and Stress Testing in the event test scope includes underlying AWS infrastructure."
  echo "Penetration Testing: https://aws.amazon.com/security/penetration-testing/"
  echo "DDoS Simulation Testing: https://aws.amazon.com/security/ddos-simulation-testing/"
  read -p "Have we received an explicit consent from the customer on AWS Policies? (Y/N): " RESPONSE2
  if [[ ! "$RESPONSE2" =~ ^[Yy](es)?$ ]]; then
    echo "Customer did not acknowledge AWS policies. Exiting."
    exit 1
  fi
}

# Run pre-checks
pre_checks

# Step-2: Extract the value of the "ID" field
INTERNAL_CLUSTER_ID=$(echo "$CLUSTER_DESCRIPTION" | grep -E '^ *ID:' | awk '{print $2}')

# Validate the INTERNAL_CLUSTER_ID value
if [ -z "$INTERNAL_CLUSTER_ID" ]; then
  echo "Failed to extract INTERNAL_CLUSTER_ID from cluster description."
  exit 1
fi

echo "Extracted INTERNAL_CLUSTER_ID: $INTERNAL_CLUSTER_ID"

# Step-3: Move the cluster to limited support
curl https://raw.githubusercontent.com/openshift/managed-notifications/master/osd/limited_support/scheduled_chaos_test.json | ocm post /api/clusters_mgmt/v1/clusters/${INTERNAL_CLUSTER_ID}/limited_support_reasons