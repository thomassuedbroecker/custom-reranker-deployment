#!/bin/bash
HOME_PATH=$(pwd)

echo "*******************************"
echo "1. Update OS"
apt update -y
apt install -y docker-compose
apt install -y git
apt install -y python3-pip
apt install -y net-tools
apt-get install -y python3-venv
apt-get install -y openjdk-11-jdk

echo "*******************************"
echo "2. Download github repositories"
mkdir $HOME_PATH/gitRepos
cd $HOME_PATH/gitRepos
git clone https://github.com/primeqa/create-primeqa-app
git clone https://github.com/primeqa/primeqa.git

echo "*******************************"
echo "3. Download drdecr for app configuration"
cd $HOME_PATH/gitRepos/create-primeqa-app/primeqa-store/checkpoints
mkdir drdecr
cd $HOME_PATH/gitRepos/create-primeqa-app/primeqa-store/checkpoints/drdecr
wget https://huggingface.co/PrimeQA/DrDecr_XOR-TyDi_whitebox/resolve/main/DrDecr.dnn

echo "*******************************"
echo "4. Create primeqa container image for GPU"
cd $HOME_PATH/gitRepos/primeqa
cat VERSION
VERSION=$(cat VERSION)
docker build -f Dockerfiles/Dockerfile.cpu -t primeqa-cpu:$(cat VERSION) --build-arg image_version:$(cat VERSION) .
cd $HOME_PATH

echo "*******************************"
echo "5. Change the accees rights for the volume mapping"
chmod -R 777 $HOME_PATH/gitRepos/create-primeqa-app/cache/
chmod -R 777 $HOME_PATH/gitRepos/create-primeqa-app/primeqa-store/

echo "*******************************"
echo "6. Start container primeqa-gpu:$(cat VERSION)"
cd $HOME_PATH/gitRepos/create-primeqa-app
docker run -it --name primeqa-rest -p 50052:50052 \
       --mount type=bind,source="$(pwd)"/primeqa-store,target=/store \
       --mount type=bind,source="$(pwd)"/cache/huggingface/,target=/cache/huggingface/ \
       -e STORE_DIR=/store \
       -e mode=rest \
       -e require_ssl=false \
       primeqa-gpu:$VERSION
