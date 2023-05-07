#!/bin/bash

# **************** Global variables
export HOME_PATH=$(pwd)

# IBM Cloud - variables
source "$HOME_PATH"/../.env

#export RERANKER_DOCKERFILE_NAME="Dockerfile_custom.cpu"
export RERANKER_DOCKERFILE_NAME="Dockerfile.cpu"
export INIT_CONTAINER_DOCKERFILE_NAME="Dockerfile.init-container"

# **********************************************************************************
# Functions definition
# **********************************************************************************

function check_docker () {
    ERROR=$(docker ps 2>&1)
    RESULT=$(echo $ERROR | grep 'Cannot' | awk '{print $1;}')
    VERIFY="Cannot"
    if [ "$RESULT" == "$VERIFY" ]; then
        echo "Docker is not running. Stop script execution."
        exit 1 
    fi
}

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

function build_and_push_init_container () {
  
    export CONTAINER_IMAGE_URL="$CR/$CR_REPOSITORY/$CI_INIT_NAME:$CI_TAG"

    echo "****** Build init container image *********"
    echo "Name: $CONTAINER_IMAGE_URL"

    IMAGE=$(docker images | grep $CI_INIT_NAME | awk '{print $1;}')
    VERIFY=$CI_INIT_NAME
    if [[ "${IMAGE}" == "${VERIFY}" ]]; then
        echo "Container image ${IMAGE} does exist!"
    else       
        docker build -f $HOME_PATH"/../dockerfiles/$INIT_CONTAINER_DOCKERFILE_NAME" \
                     -t $CONTAINER_IMAGE_URL .  
    fi
    
    # Login to container with IBM Cloud registy  
    ibmcloud cr login

    ERROR=$(ibmcloud target -g $CR_RESOURCE_GROUP 2>&1)
    RESULT=$(echo $ERROR | grep 'FAILED' | awk '{print $1;}')
    VERIFY="FAILED"
    if [ "$RESULT" == "$VERIFY" ]; then
        echo "Can't set to resource group: ($CR_RESOURCE_GROUP) but I move on."
    fi

    ibmcloud cr region-set $CR_REGION

    # Create a new namespace, if the namespace doesn't exists
    CURR_CONTAINER_NAMESPACE=$(ibmcloud cr namespace-list -v | grep $CR_REPOSITORY | awk '{print $1;}')
    if [ "$CR_REPOSITORY" != "$CURR_CONTAINER_NAMESPACE" ]; then
        ibmcloud cr namespace-add $CR_REPOSITORY
    fi

    # Login to IBM Cloud registy with Docker
    docker login -u iamapikey -p $IBM_CLOUD_API_KEY $CR_REGION 
    docker push "$CONTAINER_IMAGE_URL"
    
    ibmcloud target -g $IBM_CLOUD_RESOURCE_GROUP

}

function build_and_push_reranker_container () {
  
    export CONTAINER_IMAGE_URL="$CR/$CR_REPOSITORY/$CI_NAME:$CI_TAG"

    echo "****** Download PrimeQA and build container image *********"
    echo "Name: $CONTAINER_IMAGE_URL"

    VERIFY=$HOME_PATH/primeqa
    if [ -d "$VERIFY" ];
    then   
        echo "$VERIFY directory exists."
        cd $VERIFY
        VERSION=$(cat VERSION) 
    else   
        echo "$VERIFY directory does not exist." 
        git clone https://github.com/primeqa/primeqa.git
        cd primeqa
        VERSION=$(cat VERSION) 
    fi 

    IMAGE=$(docker images | grep $CI_NAME | awk '{print $1;}')
    VERIFY=$CI_NAME
    if [[ "${IMAGE}" == "${VERIFY}" ]]; then
        echo "Container image ${IMAGE} does exist!"
    else
        docker build -f Dockerfiles/$RERANKER_DOCKERFILE_NAME \
                     -t $CONTAINER_IMAGE_URL \
                     --build-arg image_version:$VERSION .  
    fi
    
    # Login to container with IBM Cloud registy  
    ibmcloud cr login

    ERROR=$(ibmcloud target -g $CR_RESOURCE_GROUP 2>&1)
    RESULT=$(echo $ERROR | grep 'FAILED' | awk '{print $1;}')
    VERIFY="FAILED"
    if [ "$RESULT" == "$VERIFY" ]; then
        echo "Can't set to resource group: ($CR_RESOURCE_GROUP) but I move on."
    fi

    ibmcloud cr region-set $CR_REGION

    # Create a new namespace, if the namespace doesn't exists
    CURR_CONTAINER_NAMESPACE=$(ibmcloud cr namespace-list -v | grep $CR_REPOSITORY | awk '{print $1;}')
    if [ "$CR_REPOSITORY" != "$CURR_CONTAINER_NAMESPACE" ]; then
        ibmcloud cr namespace-add $CR_REPOSITORY
    fi

    # Login to IBM Cloud registy with Docker
    docker login -u iamapikey -p $IBM_CLOUD_API_KEY $CR_REGION 
    docker push "$CONTAINER_IMAGE_URL"
    
    ibmcloud target -g $IBM_CLOUD_RESOURCE_GROUP

}

#**********************************************************************************
# Execution
# *********************************************************************************

check_docker
login_to_ibm_cloud
build_and_push_init_container
build_and_push_reranker_container