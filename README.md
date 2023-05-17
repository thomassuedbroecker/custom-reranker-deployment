# Custom Reranker deployment

The objective of this project is to deploy the [Reranker](https://github.com/primeqa/primeqa/tree/main/primeqa/components) to a Kubernetes cluster in a VPC or free Kubernetes cluster on IBM Cloud and access the REST API of the Reranker.

The [Reranker](https://github.com/primeqa/primeqa/tree/main/primeqa/components) is a component of [PrimeQA](https://github.com/primeqa/primeqa/tree/main/primeqa).

> _"**PrimeQA** is a public open-source repository that enables researchers and developers to train state-of-the-art models for question answering (QA). By using PrimeQA, a researcher can replicate the experiments outlined in a paper published in the latest NLP conference while also enjoying the capability to download pre-trained models (from an online repository) and run them on their own custom data."_

> _"The [Reranker](https://github.com/primeqa/primeqa/tree/main/primeqa/components) component takes a question and a list of documents and returns a rescored and reranked list of documents."_

### Content 


[1. Simplified architecture overview](#1-simplified-architecture-overview)


### 1. Simplified architecture overview

In the [create-primeqa-app](https://github.com/primeqa/create-primeqa-app/blob/main/docker-compose-cpu.yaml) repository, you will find how to run prime qa locally with "Docker Compose". Furthermore, by inspecting the source code in the repositories, you can find the following dependencies of applications and components.

The image below shows the dependencies of applications and components when you use a `Docker Compose` to run Prime QA on your local machine.

In the image below, you see three applications.

* UI
* Prime QA
* Orchestrator

Prime QA contains four components.

* Indexer
* Retreivers
* Readers
* Reranker

![](/images/reranker-in-primeqa-1.png)

You can set up an IBM Cloud Kubernetes cluster for example, by following the steps in my blog post [`Use Terraform to create a VPC and a Kubernetes Cluster on IBM Cloud`](https://suedbroecker.net/2022/07/05/use-terraform-to-create-a-vpc-and-a-kubernetes-cluster-on-ibm-cloud/).

In the image below, we see what we need to deploy when we only want to use the [Reranker](https://github.com/primeqa/primeqa/tree/main/primeqa/components) component.

![](/images/reranker-in-primeqa-2.png)

### 2. Kubernetes deployment

When we deploy the Reranker, we need to ensure that a model is loaded and is an accessible folder structure for a store.

To realize this functionality we going to use an init container and a "runtime" container. (sure the [init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) takes time at the startup but this is an easy and simple approach for a starting point )

![](/images/reranker-in-primeqa-3.png)

Here is an simple `Deployment.yaml` which can be optimized.

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: reranker
  namespace: reranker
  labels:
      app: reranker
spec:
  selector:
    matchLabels:
      app: reranker
  replicas: 1
  template:
    metadata:
      labels:
        app: reranker
        version: v1
    spec:
      volumes:
      - name: store
        emptyDir: {}
      - name: indexes
        emptyDir: {}
      - name: models
        emptyDir: {}
      - name: cache
        emptyDir: {}
      initContainers:
        - name: install-store
          image: icr.io/reranker-tsuedbro/init-tsuedbro:v1
          imagePullPolicy: Always
          command: ["/bin/sh"]
          args: ["-c", "echo 'Setup a model' && echo $(whoami) && echo $(ls) && echo '****' && mkdir /store/checkpoints/drdecr && echo 'Using: wget https://huggingface.co/PrimeQA/DrDecr_XOR-TyDi_whitebox/resolve/main/DrDecr.dnn -P /store/checkpoints/drdecr' && wget https://huggingface.co/PrimeQA/DrDecr_XOR-TyDi_whitebox/resolve/main/DrDecr.dnn -P /store/checkpoints"]
          volumeMounts:
          - name: store
            mountPath: /store/checkpoints
          - name: indexes
            mountPath: /store/indexes
          - name: models
            mountPath: /store/models
          - name: cache
            mountPath: /cache/huggingface
          securityContext:
            allowPrivilegeEscalation: false
      containers:
      - name: reranker
        image: icr.io/reanker-tsuedbro/reranker-tsuedbro:v1
        imagePullPolicy: Always
        livenessProbe:
          exec:
            command: ["sh", "-c", "ls"]
          initialDelaySeconds: 20
        readinessProbe:
          exec:
            command: ["sh", "-c", "curl http://localhost:50052/rerankers"]"]
          initialDelaySeconds: 40
        env:
        - name: STORE_DIR
          valueFrom:
            configMapKeyRef:
              name: reranker-confmap
              key: STORE_DIR
        - name: mode
          valueFrom:
            configMapKeyRef:
              name: reranker-confmap
              key: mode
        - name: require_ssl
          valueFrom:
            configMapKeyRef:
              name: reranker-confmap
              key: require_ssl
        volumeMounts:
        - name: store
          mountPath: /store/checkpoints
        - name: indexes
          mountPath: /store/indexes
        - name: models
          mountPath: /store/models
        - name: cache
          mountPath: /cache/huggingface
        securityContext:
          allowPrivilegeEscalation: false   
        ports:
        - containerPort: 50052
      restartPolicy: Always
```



### 3. Prerequisites

You need to have the following in place to follow the example setup steps.

* `Kubernetes Cluster` on IBM Cloud
* Docker Desktop

### 4. Setup

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
