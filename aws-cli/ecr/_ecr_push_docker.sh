#!/bin/bash

# AWS ECR details
#AWS_REGION="us-east-1"
ecr_name_search_string="container"
AWS_REGION=$(aws configure get region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_REPO_NAME=$(aws ecr describe-repositories --query 'repositories[*].repositoryName' --output text|grep "${ecr_name_search_string}")

# Docker image details
DOCKER_IMAGE_NAME="nginx_docker"
DOCKER_TAG="latest"

# Build Docker image
docker build -t ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} .

# Log in to AWS ECR
aws ecr get-login-password --region ${AWS_REGION} | \
 docker login \
   --username AWS \
   --password-stdin \
   ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}

# Tag the Docker image
docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${DOCKER_TAG}

# Push the Docker image to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${DOCKER_TAG}

# Clean up - remove local Docker image
docker rmi ${DOCKER_IMAGE_NAME}:${DOCKER_TAG}
