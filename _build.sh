#!/bin/sh

set -ev


cd $(dirname $0)

# build the handbook
Rscript programs/build.R

