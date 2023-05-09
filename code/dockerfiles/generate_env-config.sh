#!/bin/bash
########################################
# Create a file based on the environment variables
# given by the dockerc run -e parameter
########################################
cat <<EOF
# model information
export MODEL_URL=${MODEL_URL}
export MODEL_DIR=${MODEL_DIR}
EOF