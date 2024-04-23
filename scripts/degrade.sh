#!/bin/bash

oc get deploy/cluster-autoscaler-operator
#oc get cm/kube-rbac-proxy-cluster-autoscaler-operator

if [ $? -eq 0 ]; then 
 
     oc delete deploy/cluster-autoscaler-operator	
#  oc delete cm/kube-rbac-proxy-cluster-autoscaler-operator

else
  
  sleep 45

fi
