#!/bin/bash

ocm backplane login $1

jobDetails=$(ocm backplane managedjob create CEE/cluster-health-check)

while read -r line; do
    # Check if the line contains "ocm backplane managedjob get"
    if [[ $line == *"ocm backplane managedjob get openshift-job-"* ]]; then
        # If found, store it in check_job_status variable
        check_job_status="$line"
        break  # Exit loop after finding the first occurrence
    fi
done <<< "$jobDetails"

while read -r line; do
    # Check if the line contains "ocm backplane managedjob get"
    if [[ $line == *"ocm backplane managedjob logs openshift-job-"* ]]; then
        # If found, store it in check_job_status variable
        get_logs="$line"
        break  # Exit loop after finding the first occurrence
    fi
done <<< "$jobDetails"

check_status() {
    # Run the command and store the output in a variable
    jobGetOutput=$(eval "$check_job_status")

    # Extract the STATUS field using awk
    status=$(echo "$jobGetOutput" | awk 'NR==2{print $2}')

    # Return the status
    echo "$status"
}

# Loop until status is "Succeeded"
while true; do
    # Check the status
    status=$(check_status)
    
    # Check if status is "Succeeded"
    if [ "$status" = "Succeeded" ]; then
        echo "Job Status is Succeeded. Checking job logs..."
        eval "$get_logs"
        break  # Exit the loop
    else
        echo "Waiting for status to be Succeeded..."
        sleep 15  # Wait for some time before checking again
    fi
done