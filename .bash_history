ls
R CMD BATCH programs/build.R 
chmod a+rx _build.sh 
./_build.sh 
rm data/outputs/*
./_build.sh 
