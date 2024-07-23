#!/usr/bin/env bash

FILE=secret-files/secret.tfvars
AWS_S3_ENDPOINT=https://storage.yandexcloud.net
export AWS_S3_ENDPOINT
if [ -f $FILE ]; then
  terraform plan -var-file secret-files/secret.tfvars -out=tfplan
else
  terraform plan -out=tfplan
fi