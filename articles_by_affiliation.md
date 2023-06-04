---
title: "Obtaining lists of articles for contributors from a specific Org"
author: "Lars Vilhuber"
date: "2023-06-04"
output: 
  html_document: 
    keep_md: yes
---



## Overview

## Sources

- CrossRef



## Instructions
This file, when executed, will

- download a list of articles for top journals from CrossRef
- Filter those articles by affiliation of the authors
- Save the output as CSV

The program will check for prior files, and will NOT download new data if those files are present. Thus, to get a fresh run, 

- delete ` data/outputs/crossrefdois.Rds ` if you want to re-start the whole process
- delete ` data/interwrk/new.Rds ` to re-download files from CrossRef
- revert ` data/outputs/issns.Rds ` (which stores the last query date, and is updated at the end of this process)

## Data locations

Permanent data is in

> data/outputs

and should be committed to the repository.

Temporary data is in

> data/interwrk

and can (should) be deleted after completion.

## Current list of articles

We first obtain the current list of articles. This is not failsafe - it assumes there *is* such a list.



```r
if (file.exists(full.file.Rds)) {
	print(paste0("File ",full.file.Rds," exists."))
  full.file <- readRDS(full.file.Rds)
  uniques <- full.file %>% select(doi) %>% distinct() 
} else	{
  print(paste0("File ",full.file.Rds," is absent."))
}
```

```
## [1] "File data/outputs/crossrefdois.Rds is absent."
```

```r
# End of else statement
```



```r
# Each journal has a ISSN
if (!file.exists(issns.file)) {
issns <- data.frame(matrix(ncol=2,nrow=10))
names(issns) <- c("journal","issn")
tmp.date <- c("2000-01-01")
issns[1,] <- c("American Economic Journal: Applied Economics","1945-7790")
issns[2,] <- c("American Economic Journal: Economic Policy","1945-774X")
issns[3,] <- c("American Economic Journal: Macroeconomics", "1945-7715")
issns[4,] <- c("American Economic Journal: Microeconomics", "1945-7685")
issns[5,] <- c("The American Economic Review","1944-7981")
issns[6,] <- c("The American Economic Review","0002-8282")  # print ISSN is needed!
issns[7,] <- c("The Quarterly Journal of Economics","0033-5533") # use the print ISSN (OUP). Online ISSN: 1531-4650
issns[8,] <- c("The Review of Economic Studies","0034-6527") # use the print ISSN (OUP). Online ISSN: 1467-937X
issns[9,] <- c("Journal of Political Economy","0022-3808") # online: E-ISSN: 1537-534X
issns[10,] <- c("The Economic Journal Oxford","0013-0133") # Online ISSN 1468-0297 


issns$lastdate <- tmp.date
saveRDS(issns, file= issns.file)
}
```

Now read DOI for all later dates.


```r
# Run this only once per session
# The column "author" contains author-affiliations as well.
if ( file.exists(issns.file) ) {
  issns <- readRDS(file = issns.file)
	crossref.df <- NA
	for ( x in 1:nrow(issns) ) {
		new <- cr_journals(issn=issns[x,"issn"], works=TRUE,
				   filter=c(from_pub_date=issns[x,"lastdate"]),
				   select=c("DOI","title","published-print","volume","issue","container-title","author"),
				   .progress="text",
				   cursor = "*")
		if ( x == 1 ) {
      		#crossref.df <- as.data.frame(new$data)
		      crossref.df <- new %>% purrr::pluck("data")
      		crossref.df$issn = issns[x,"issn"]
    	} else {
    	    #tmp.df <- as.data.frame(new$data)
    	    tmp.df <- new %>% purrr::pluck("data")
    	    tmp.df$issn = issns[x,"issn"]
      		crossref.df <- bind_rows(crossref.df,tmp.df)
      		rm(tmp.df)
    	}
	}
	# extract the author information into columns
	crossref.df %>% unnest(author) -> raw.df
	
	# Cleaning up. OUP breaks out multiple affiliations. We concatenate them back together again
	raw.df %>% 
	  unite(affiliations,starts_with("affiliation"),sep=";",remove=TRUE,na.rm=TRUE) %>%
	  mutate(affiliations = str_remove(string = affiliations,pattern = fixed(" (email: )"))) -> new.df
	saveRDS(new.df, file= new.file.Rds)
	rm(new)
}

# clean read-back
new.df <- readRDS(file= new.file.Rds)
```

We read **13096** article records for **13** journals, with **28887** article-author observations:


|container.title                              | records|
|:--------------------------------------------|-------:|
|American Economic Journal: Applied Economics |    1438|
|American Economic Journal: Economic Policy   |    1526|
|American Economic Journal: Macroeconomics    |    1163|
|American Economic Journal: Microeconomics    |    1311|
|American Economic Review                     |    9856|
|Journal of Political Economy                 |    2740|
|Quarterly Journal of Economics               |     431|
|Review of Economic Studies                   |     920|
|The American Economic Review                 |     119|
|The Economic Journal                         |    5094|
|THE ECONOMIC JOURNAL                         |       2|
|The Quarterly Journal of Economics           |    2178|
|The Review of Economic Studies               |    2109|




The new records can be found [here](data/outputs/addtl_doi.csv). We now update the file we use to track the updates, ` data/outputs/issns.Rds `. If you need to run the process anew, simply revert the file ` data/outputs/issns.Rds ` and run this document again.


```r
issns <- new.df %>% select(journal,lastdate) %>% 
	right_join(issns,by=c("journal")) %>%
	mutate( lastdate = coalesce(lastdate.x,lastdate.y)) %>%
	select(-lastdate.x, -lastdate.y)
saveRDS(issns, file= issns.file)
```

## Writing out final files

We finalize by creating a combined file with all records, and a corresponding CSV file.


```r
# Append new.df and full.file


if (file.exists(full.file.Rds)) {
	print(paste0("File ",full.file.Rds," exists."))
  full.file <- bind_rows(readRDS(full.file.Rds),new.df)
} else	{
  full.file <- new.df 
}

saveRDS(full.file,file=full.file.Rds)
write.csv(full.file,file=full.file.csv,row.names = FALSE)
```

Now pull out the selected affiliation ("World Bank"):


```r
full.file <- readRDS(full.file.Rds)
full.file %>% filter(str_detect(affiliations,affiliation.target)) -> target

# Save the target file

saveRDS(target,target.file.Rds)
write.csv(target,target.file.csv,row.names = FALSE)

# subset to unique articles

target %>% select(container.title,published.print,doi,title) %>%
  distinct() %>%
  mutate(url=paste0("https://doi.org/",doi)) -> target.articles
write.csv(target.articles,target.articles.csv,row.names = FALSE)
```

Here are the articles we found:



## System info


```r
Sys.info()
```

```
##                                       sysname 
##                                       "Linux" 
##                                       release 
##                           "5.15.0-1038-azure" 
##                                       version 
## "#45-Ubuntu SMP Mon Apr 24 15:40:42 UTC 2023" 
##                                      nodename 
##                                "a75db66677d9" 
##                                       machine 
##                                      "x86_64" 
##                                         login 
##                                     "unknown" 
##                                          user 
##                                     "rstudio" 
##                                effective_user 
##                                     "rstudio"
```
