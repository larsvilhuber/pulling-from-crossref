# ###########################
# CONFIG: define  and filenames for later reference
# ###########################

issns.file <- file.path(dataloc,paste0("issns.Rds"))

full.file <- file.path(dataloc,"crossrefdois")
full.file.Rds <- paste(full.file,"Rds",sep=".")
full.file.csv <- paste(full.file,"csv",sep=".")

new.file.Rds <- file.path(interwrk,paste0("new.Rds"))

addtl.file <- file.path(dataloc,paste0("addtl_doi.csv"))

# you may need to change this
Sys.setenv(crossref_email = "ldi@cornell.edu")

# Entity we are searching for:

affiliation.target = "World Bank"
