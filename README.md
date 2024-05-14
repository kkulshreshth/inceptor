# Inceptor: Streamlined ROSA/OSD Cluster Troubleshooting

# Description:
Inceptor is a comprehensive CLI tool designed to simplify troubleshooting for operators within ROSA/OSD clusters. With a single command, Inceptor aggregates crucial information including resources, logs, events, support status, service logs, suggested KCS solutions and Prometheus graph links. By consolidating these essential details into one accessible interface, Inceptor empowers operators to efficiently diagnose and resolve issues, promoting smoother operation and enhanced performance within Openshift environments.

# Prerequisite:
- ocm backplane CLI
- osdctl CLI

# How to get inceptor CLI binary?
1. Navigate to https://github.com/kkulshreshth/inceptor/tree/main/inceptor-cli and download the inceptor binary file.
2. Place the binary in /usr/local/bin/ in your system.
3. Verify using ```inceptor --version```

# Usage:
Current version: 0.1.0
The current version contains the following commands/sub-commands:
1. check (c) : check is the main command that is used for troubleshooting the operators. You need to provide the operator name as sub-command to specify which operator to troubleshoot.
   SUB-COMMANDS: 
   - cluster-health (ch): This sub-command runs many health check tasks against the cluster and prints out the results.
   - authentication (auth): This sub-command checks information related to authentication operator.
   - cloud-credential (cc): This sub-command checks information related to cloud-credential operator
   - image-registry (ir): This sub-command checks information related to image-registry operator

Example:
```
inceptor check <operator-name> <cluster-id>
```
where,
- inceptor is the CLI tool name
- check is the command
- <operator-name> is a nested-command or a sub command (for example: authentication or auth)
- <cluster-id> is a command line argument (External ID of the cluster)
