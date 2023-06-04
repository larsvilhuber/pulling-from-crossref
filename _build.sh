#!/bin/sh

set -ev


cd $(dirname $0)

# build the handbook
R CMD BATCH programs/build.R

