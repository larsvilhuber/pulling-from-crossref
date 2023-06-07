# ###########################
# CONFIG: define paths and filenames for later reference
# ###########################

# Change the basepath depending on your system

basepath <- rprojroot::find_root(rprojroot::has_file("pathconfig.R"))
setwd(basepath)

# Main directories
datadir  <- file.path(basepath, "data")
dataloc <- file.path(datadir,"outputs")
acquired <- file.path(datadir,"acquired")
interwrk <- file.path(datadir,"interwrk")

for ( dir in list(datadir,acquired,interwrk,dataloc)){
  if (file.exists(dir)){
  } else {
    dir.create(file.path(dir))
  }
}


programs <- file.path(basepath)
