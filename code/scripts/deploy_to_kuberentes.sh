#!/bin/bash

# **************** Global variables
export HOME_PATH=$(pwd)
source $HOME_PATH/../.env

# **********************************************************************************
# Functions definition
# **********************************************************************************

function login_to_ibm_cloud () {
    
    echo ""
    echo "*********************"
    echo "loginIBMCloud"
    echo "*********************"
    echo ""

    ibmcloud login --apikey $IBM_CLOUD_API_KEY 
    ibmcloud target -r $IBM_CLOUD_REGION
    ibmcloud target -g $IBM_CLOUD_RESOURCE_GROUP
}

function connect_to_cluster () {
    echo ""
    echo "*********************"
    echo "Connect to cluster $CLUSTER_NAME"
    echo "*********************"
    echo ""
    ibmcloud ks cluster config -c $CLUSTER_NAME
}

function pull_secret_and_sa () {
    echo ""
    echo "*********************"
    echo "Create pull secret and patch default service account"
    echo "*********************"
    echo ""
    kubectl create secret docker-registry custom-reg-credentials \
           --docker-server=$CR \
           --docker-username=$CR_USER \
           --docker-password=$IBM_CLOUD_API_KEY \
           --docker-email=$CR_EMAIL \
           -n reranker
    kubectl patch serviceaccount default -n reranker -p '{"imagePullSecrets": [{"name": "custom-reg-credentials"},{"name": "all-icr-io"}]}'
    kubectl get sa -n reranker default -o yaml
}

#**********************************************************************************
# Execution
# *********************************************************************************

login_to_ibm_cloud
connect_to_cluster

echo "1. Create namespace"
kubectl apply -f $HOME_PATH/../deployment/namespace.yaml

echo "2. Get existing screts to access the IBM Cloud Registry  in the default namespace"
kubectl get secrets -n default | grep icr-io

echo "3. Copy the IBM Cloud container registry access secret to the reranker namespace"
kubectl get secret all-icr-io -n default -o yaml | sed 's/default/reranker/g' | kubectl create -n reranker -f - 

echo "4. Patch the service account to in the default namespace."
kubectl get secrets -n reranker | grep icr-io
pull_secret_and_sa

echo "5. Create configmap"
kubectl apply -f $HOME_PATH/../deployment/configmap.yaml

echo "6. Create deployment"
kubectl apply -f $HOME_PATH/../deployment/deployment.yaml

echo "7. Create service"
kubectl apply -f $HOME_PATH/../deployment/service.yaml

echo "8. Create service loadbalancer"
kubectl apply -f $HOME_PATH/../deployment/service-loadbalancer.yaml

# Delete
# ======================================
# kubectl delete -f ./deployment/deployment.yaml
# kubectl delete -f ./deployment/configmap.yaml
# kubectl delete -f ./deployment/service.yaml
# kubectl delete -f ./deployment/service-loadbalancer.yaml

# IBM Cloud internal access with nodeport
# ======================================
# kubectl describe service reranker-service -n reranker 
# kubectl describe service reranker-nlb -n reranker 
# WORKER_NODE_IP=$(ibmcloud oc workers --cluster $CLUSTER_NAME  | grep "Ready" | awk '{print $2;}' | head -n 1)
# NODEPORT=$(kubectl get svc reranker-service -n reranker --ignore-not-found --output 'jsonpath={.spec.ports[*].nodePort}')
# echo $NODEPORT
# echo "URL: http://$WORKER_NODE_IP:$NODEPORT/rerankers" 
