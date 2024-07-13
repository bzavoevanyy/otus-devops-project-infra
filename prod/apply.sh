#!/usr/bin/env bash

export PATH=$PATH
AWS_S3_ENDPOINT=https://storage.yandexcloud.net
export AWS_S3_ENDPOINT
terraform apply "tfplan"