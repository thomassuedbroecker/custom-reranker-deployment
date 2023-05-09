#!/bin/bash

echo 'Setup a model'
echo $(whoami) 
echo $(ls) 
echo '****' 
"/bin/sh" ./generate_env-config.sh > ./.env
source ./.env
mkdir /store/checkpoints/$MODEL_DIR
echo 'Using: wget $MODEL_URL -P /store/checkpoints/$MODEL_DIR"]
wget $MODEL_URL -P /store/checkpoints/$MODEL_DIR