#!/bin/bash

CLUSTER_ID="${args[clusterid]:-$1}"

# Step-1: Describe the cluster
CLUSTER_DESCRIPTION=$(ocm describe cluster "$CLUSTER_ID" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Failed to describe the cluster. Please check the cluster ID and ensure OCM CLI is configured."
  exit 1
fi

# Step-2: Extract the value of "ID" field
INTERNAL_CLUSTER_ID=$(echo "$CLUSTER_DESCRIPTION" | grep -E '^ *ID:' | awk '{print $2}')
if [ -z "$INTERNAL_CLUSTER_ID" ]; then
  echo "Failed to extract INTERNAL_CLUSTER_ID from cluster description."
  exit 1
fi

echo "Extracted INTERNAL_CLUSTER_ID: $INTERNAL_CLUSTER_ID"

# Step-3: Get all Limited Support Reasons for the cluster
LimitedSupportReasonList=$(ocm get cluster "$INTERNAL_CLUSTER_ID/limited_support_reasons" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Failed to retrieve Limited Support Reasons. Please check the cluster ID and connectivity."
  exit 1
fi

# Step-4: Extract the "total" field from the Limited Support Reasons
LIMITED_SUPPORT_REASONS=$(echo "$LimitedSupportReasonList" | jq -r '.total')
if [ -z "$LIMITED_SUPPORT_REASONS" ]; then
  echo "Failed to extract total from Limited Support Reasons."
  exit 1
fi

echo "Total Limited Support Reasons: $LIMITED_SUPPORT_REASONS"

# Step-5: Handle cases based on the value of "total"
if [ "$LIMITED_SUPPORT_REASONS" -gt 1 ]; then
  echo "Full support for the cluster cannot be restored at the moment. Cluster is in limited support due to multiple reasons. Kindly review the above output."
elif [ "$LIMITED_SUPPORT_REASONS" -eq 1 ]; then
  # Extract the summary and href fields
  summary=$(echo "$LimitedSupportReasonList" | jq -r '.items[0].summary')
  href=$(echo "$LimitedSupportReasonList" | jq -r '.items[0].href')

  if [[ "$summary" == *"Cluster is in Limited Support due to scheduled chaos testing"* ]]; then
    # Delete the limited support reason
    ocm delete "$href"
    if [ $? -eq 0 ]; then
      echo "Full support for the cluster is restored."
    else
      echo "Failed to remove the limited support reason."
      exit 1
    fi

    # Retrieve the updated Limited Support Reasons
    ocm get cluster "$INTERNAL_CLUSTER_ID/limited_support_reasons"
  else
    echo "Limited support reason does not match scheduled chaos testing. Manual review needed."
  fi
elif [ "$LIMITED_SUPPORT_REASONS" -eq 0 ]; then
  echo "Cluster is not in Limited Support."
else
  echo "Unexpected value for total: $LIMITED_SUPPORT_REASONS"
  exit 1
fi