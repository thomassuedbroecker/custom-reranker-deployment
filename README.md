# Custom reranker deployment

Deploy the [reranker](https://github.com/primeqa/primeqa/tree/main/primeqa/components) to a Kubernetes cluster. In a VPC on IBM Cloud. You can set up an IBM Cloud Kubernetes cluster for example by following the steps in my blog post [`Use Terraform to create a VPC and a Kubernetes Cluster on IBM Cloud`](https://suedbroecker.net/2022/07/05/use-terraform-to-create-a-vpc-and-a-kubernetes-cluster-on-ibm-cloud/).

### Prerequisites

* Create a `Kubernetes Cluster` on IBM Cloud
* Install Docker Desktop

### Step 1: Clone project

```sh
export HOME_PATH=$(pwd)
git clone https://github.com/thomassuedbroecker/custom-reranker-deployment.git
```

### Step 2: Create a copy of the needed environment

```sh
cd $HOME_PATH/custom-reranker-deployment/code
cat .env_template > .env
```

### Step 3: Build and push containers to the IBM Cloud registry 

```sh
cd $HOME_PATH/code/scripts
sh build_and_push_container_images.sh
```

### Step 4: Deploy the reranker to the cluster

```sh
cd $HOME_PATH/code/scripts
sh deploy_to_kubernetes.sh
```

### Step 5: Wait until the load balancer service is available

```sh
kubectl get svc reranker-nlb -n reranker
```

* Example output:

```sh
NAME           TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
reranker-nlb   LoadBalancer   172.21.101.92   XXXXXXXXXXX   50052:31945/TCP   26m
```

### Step 6: Invoke the endpoint

```sh
HOST_NAME=$(kubectl get svc reranker-nlb -n reranker --ignore-not-found --output 'jsonpath={.status.loadBalancer.ingress[*].hostname}')
echo $HOST_NAME
curl http://$HOST_NAME:50052/rerankers
```

* Example output:

```sh
[{"reranker_id":"SeqClassificationReranker","parameters":[{"parameter_id":"model","name":"Model","description":"Path to model","type":"String","value":"ibm/re2g-reranker-nq","options":null,"range":null},{"parameter_id":"max_num_documents","name":"Maximum number of retrieved documents","description":null,"type":"Numeric","value":-1,"options":null,"range":[-1,100,1]},{"parameter_id":"max_batch_size","name":"Maximum batch size","description":null,"type":"Numeric","value":128,"options":null,"range":[1,256,8]}]},{"reranker_id":"ColBERTReranker","parameters":[{"parameter_id":"model","name":"Model","description":"Path to model","type":"String","value":"drdecr","options":null,"range":null},{"parameter_id":"max_num_documents","name":"Maximum number of retrieved documents","description":null,"type":"Numeric","value":-1,"options":null,"range":[-1,100,1]},{"parameter_id":"doc_maxlen","name":"doc_maxlen","description":"maximum document length (sub-word units)","type":"Numeric","value":180,"options":null,"range":null},{"parameter_id":"query_maxlen","name":"query_maxlen","description":"maximum query length (sub-word units)","type":"Numeric","value":32,"options":null,"range":null}]}]
```
