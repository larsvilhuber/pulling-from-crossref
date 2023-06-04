# ###########################
# CONFIG: define  and filenames for later reference
# ###########################

replication_list_KEY <- "1pLxxyg01L-UkNpBWgP2xCRe7hIuUNw6e9BnVIqcO76c"
repllist.file <- file.path(dataloc,paste0("replication_list_DOI.Rds"))
issns.file <- file.path(dataloc,paste0("issns.Rds"))

full.file <- file.path(dataloc,"aeadois")
full.file.Rds <- paste(full.file,"Rds",sep=".")
full.file.csv <- paste(full.file,"csv",sep=".")

new.file.Rds <- file.path(interwrk,paste0("new.Rds"))

addtl.file <- file.path(dataloc,paste0("addtl_doi.csv"))

# you may need to change this
Sys.setenv(crossref_email = "ldi@cornell.edu")

##To pass your email address to Crossref, simply store it as an environment variable in .Renviron like this:

##Open file: file.edit("~/.Renviron")

##Add email address to be shared with Crossref crossref_email= "name@example.com"

#Save the file and restart your R session

##To stop sharing your email when using rcrossref simply delete it from your .Renviron file
