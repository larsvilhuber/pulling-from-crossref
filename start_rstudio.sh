#!/bin/bash
source config.sh
  
# build the docker if necessary

docker pull $space/$dockername:$tag
BUILD=no
arg1=$1

if [[ $? == 1 ]]
then
  ## maybe it's local only
  docker image inspect $space/$dockername:$tag > /dev/null
  [[ $? == 0 ]] && BUILD=no
fi
# override
[[ "$arg1" == "force" ]] && BUILD=yes

#BUILD=no
if [[ "$BUILD" == "yes" ]]; then
./build_docker.sh
fi

if [[ "$arg1" == "" ]]; then
  argExtra="-p 8787:8787 "
else
  argExtra="-it -w /home/rstudio"
fi

docker run $argExtra -e DISABLE_AUTH=true -v $WORKSPACE:/home/rstudio --rm $space/$dockername:$tag "$@"
