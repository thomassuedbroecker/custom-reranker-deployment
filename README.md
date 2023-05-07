# Custom reranker deployment

Deploy the reranker to Kubernetes.

### Prequistes

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
