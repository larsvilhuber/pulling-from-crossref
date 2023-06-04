#!/bin/bash

source config.sh
  
# build the docker 
docker build . -t $space/$dockername:$tag
nohup docker push $space/$dockername:$tag &
