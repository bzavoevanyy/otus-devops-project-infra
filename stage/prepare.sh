#!/bin/zsh
YC_TOKEN=$(yc iam create-token)
YC_CLOUD_ID=$(yc config get cloud-id)
YC_FOLDER_ID=$(yc config get folder-id)
AWS_ENDPOINT_URL_S3=https://storage.yandexcloud.net
AWS_S3_ENDPOINT=https://storage.yandexcloud.net
export YC_TOKEN
export YC_CLOUD_ID
export YC_FOLDER_ID
export AWS_ENDPOINT_URL_S3
export AWS_S3_ENDPOINT

mkdir -p "secret-files"

yc lockbox secret get --name terraform-secrets --format json | jq '.current_version.payload_entry_keys[]' | xargs -L1 -I'{}' sh -c "yc lockbox payload get --id $(yc lockbox secret get --name terraform-secrets --format json | jq '.id') --format json --key {} > secret-files/{}"

terraform init -upgrade -backend-config=./secret-files/s3-cred