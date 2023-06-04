PWD=$(pwd)
repo=${PWD##*/}
dockername=$(echo $repo | tr [A-Z] [a-z])
tag=2023-06-04
space=larsvilhuber
case $USER in
  vilhuber)
  WORKSPACE=$PWD
  ;;
  codespace)
  WORKSPACE=$PWD
  ;;
esac
