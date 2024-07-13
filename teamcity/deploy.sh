#!/usr/bin/env bash

# set ip correct address
HOST_IP=158.160.41.224
USER=yc-user

scp -r ./agents ${USER}@${HOST_IP}:~/
scp -r ./data_dir ${USER}@${HOST_IP}:~/
scp -r ./teamcity-server-logs ${USER}@${HOST_IP}:~/

docker-machine create --driver generic --generic-ip-address=${HOST_IP} --generic-ssh-user ${USER} --generic-ssh-key ~/.ssh/id_rsa docker-host
eval "$(docker-machine env docker-host)"

docker-compose up -d

