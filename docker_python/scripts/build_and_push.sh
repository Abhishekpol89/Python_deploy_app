#!/bin/bash
set -e
# This script builds the Docker image and pushes it to ECR.

echo "Inside build_and_push.sh file"
DOCKER_IMAGE_NAME=$1

echo "Value of DOCKER_IMAGE_NAME is $DOCKER_IMAGE_NAME"

if [ -z "$DOCKER_IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

src_dir=$CODEBUILD_SRC_DIR

# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Failed to get AWS account ID"
    exit 255
fi

# Get the region defined in the current configuration
region=${AWS_REGION:-us-west-2}
echo "Region value is: $region"

# If the repository doesn't exist in ECR, create it.
ecr_repo_name="${DOCKER_IMAGE_NAME}-ecr-repo"
echo "Value of ecr_repo_name is $ecr_repo_name"

aws ecr describe-repositories --repository-names ${ecr_repo_name} || aws ecr create-repository --repository-name ${ecr_repo_name}

image_name="${DOCKER_IMAGE_NAME}-${CODEBUILD_BUILD_NUMBER}"

# Docker login
aws ecr get-login-password | docker login --username AWS --password-stdin ${account}.dkr.ecr.${region}.amazonaws.com
if [ $? -ne 0 ]; then
    echo "Docker login failed"
    exit 1
fi

fullname="${account}.dkr.ecr.${region}.amazonaws.com/${ecr_repo_name}:${image_name}"
echo "Fullname is $fullname"

# Build the Docker image
docker build -t ${image_name} "$src_dir/docker_python/"
echo "Docker build complete"

# Tag the Docker image
echo "Tagging Docker image..."
docker tag ${image_name} ${fullname}
echo "Tagging complete"

# Push the Docker image
echo "Pushing Docker image..."
docker push ${fullname}
if [ $? -ne 0 ]; then
    echo "Docker push failed for image ${fullname}"
    exit 1
else
    echo "Docker push succeeded for image ${fullname}"
fi
