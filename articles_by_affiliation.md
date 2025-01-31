---
title: "Obtaining lists of articles for contributors from a specific Org"
author: "Lars Vilhuber"
date: "2023-06-05"
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

We read **13096** article records for **13** journals, with **28853** article-author observations:


|container.title                              | records|
|:--------------------------------------------|-------:|
|American Economic Journal: Applied Economics |    1438|
|American Economic Journal: Economic Policy   |    1526|
|American Economic Journal: Macroeconomics    |    1163|
|American Economic Journal: Microeconomics    |    1311|
|American Economic Review                     |    9822|
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

We finalize by creating a combined file with all records, and a corresponding CSV file. These can be re-used.


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

## Finding target institutions'  authors

Now pull out the selected affiliation ("World Bank, IMF, International Monetary Fund"):


```r
full.file <- readRDS(full.file.Rds)
# Iterate over targets
if ( exists("target.df") ) { rm(target.df) }
for ( target in affiliation.target ) {
  full.file %>% filter(str_detect(affiliations,target)) %>%
    mutate(detected_target = target) -> tmp.df
  if ( exists("target.df") ) {
    target.df <- bind_rows(target.df,tmp.df)
  } else {
    target.df <- tmp.df
  }
  rm(tmp.df)
}
```

As it turns out, the Journal of Political Economy does not encode its metadata with affiliations. We thus need to search for publications by specific authors. Note that this might yield papers that are from these authors when they were not yet, or no longer, at the relevant institutions.


```r
# first file was manually obtained from IMF website
# It was manully cleaned using 
# sed 's+""+"+g'  imf_authors.csv | sed 's+""+"+g' > cleaned_imf_cvs.csv
library(readr)
target.authors <- read_csv("data/inputs/cleaned_imf_cvs.csv",
                    col_names = FALSE)
```

```
## Rows: 161 Columns: 2
## ── Column specification ────────────────────────────────────────────────────────
## Delimiter: ","
## chr (2): X1, X2
## 
## ℹ Use `spec()` to retrieve the full column specification for this data.
## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.
```

```r
names(target.authors) <- c("last","first")
target.authors$institution = "IMF"

# An equivalent list from the World Bank would be useful.

# Now merge against the full file and identify the subset of publications by these authors.

jpe.imf <- left_join(full.file %>% filter(container.title=="Journal of Political Economy"),target.authors,c("family"="last","given"="first")) %>%
  filter(!is.na(institution)) %>%
  select(-institution) %>%
  rename(institution = affiliations)

# now append that to the target file
target.df <- bind_rows(target.df,jpe.imf)
```

##  Save the target file


```r
saveRDS(target.df,target.file.Rds)
write.csv(target.df,target.file.csv,row.names = FALSE)

# subset to unique articles

target.df %>% select(container.title,published.print,doi,title,detected_target) %>%
  distinct() %>%
  mutate(url=paste0("https://doi.org/",doi)) -> target.articles
write.csv(target.articles,target.articles.csv,row.names = FALSE)
```

We found 305:


|detected_target             | Count|
|:---------------------------|-----:|
|IMF                         |    13|
|International Monetary Fund |   105|
|World Bank                  |   184|
|NA                          |     3|
(Table may contain some double-counting if the same article has authors from multiple targeted institutions)

Here are the articles we found:


|container.title                              |published.print |doi                              |title                                                                                                                                             |detected_target             |url                                              |
|:--------------------------------------------|:---------------|:--------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------------|:------------------------------------------------|
|American Economic Journal: Applied Economics |2019-07-01      |10.1257/app.20170128             |Long-Run Effects of Temporary Incentives on Medical Care Productivity                                                                             |World Bank                  |https://doi.org/10.1257/app.20170128             |
|American Economic Journal: Applied Economics |2014-10-01      |10.1257/app.6.4.197              |Soil Endowments, Female Labor Force Participation, and the Demographic Deficit of Women in India                                                  |World Bank                  |https://doi.org/10.1257/app.6.4.197              |
|American Economic Journal: Applied Economics |2016-10-01      |10.1257/app.20150149             |The Impact of High School Financial Education: Evidence from a Large-Scale Evaluation in Brazil                                                   |World Bank                  |https://doi.org/10.1257/app.20150149             |
|American Economic Journal: Applied Economics |2020-04-01      |10.1257/app.20180369             |Do Management Interventions Last? Evidence from India                                                                                             |World Bank                  |https://doi.org/10.1257/app.20180369             |
|American Economic Journal: Applied Economics |2016-04-01      |10.1257/app.20150023             |The Returns to Microenterprise Support among the Ultrapoor: A Field Experiment in Postwar Uganda                                                  |World Bank                  |https://doi.org/10.1257/app.20150023             |
|American Economic Journal: Applied Economics |2019-01-01      |10.1257/app.20170497             |Labor Drops: Experimental Evidence on the Return to Additional Labor in Microenterprises                                                          |World Bank                  |https://doi.org/10.1257/app.20170497             |
|American Economic Journal: Applied Economics |2016-10-01      |10.1257/app.20130399             |What Does Debt Relief Do for Development? Evidence from India's Bailout for Rural Households                                                      |World Bank                  |https://doi.org/10.1257/app.20130399             |
|American Economic Journal: Applied Economics |2013-01-01      |10.1257/app.5.2.122              |The Demand for, and Consequences of, Formalization among Informal Firms in Sri Lanka                                                              |World Bank                  |https://doi.org/10.1257/app.5.2.122              |
|American Economic Journal: Applied Economics |2010-10-01      |10.1257/app.2.4.213              |Put Your Money Where Your Butt Is: A Commitment Contract for Smoking Cessation                                                                    |World Bank                  |https://doi.org/10.1257/app.2.4.213              |
|American Economic Journal: Applied Economics |2021-04-01      |10.1257/app.20180340             |Growing Markets through Business Training for Female Entrepreneurs: A Market-Level Randomized Experiment in Kenya                                 |World Bank                  |https://doi.org/10.1257/app.20180340             |
|American Economic Journal: Applied Economics |2009-09-01      |10.1257/app.1.4.200              |In Pursuit of Balance: Randomization in Practice in Development Field Experiments                                                                 |World Bank                  |https://doi.org/10.1257/app.1.4.200              |
|American Economic Journal: Applied Economics |2021-07-01      |10.1257/app.20190083             |Credit Rationing and Pass-Through in Supply Chains: Theory and Evidence from Bangladesh                                                           |World Bank                  |https://doi.org/10.1257/app.20190083             |
|American Economic Journal: Applied Economics |2014-10-01      |10.1257/app.6.4.35               |Citizenship, Fertility, and Parental Investments                                                                                                  |World Bank                  |https://doi.org/10.1257/app.6.4.35               |
|American Economic Journal: Applied Economics |2014-10-01      |10.1257/app.6.4.1                |Should Aid Reward Performance? Evidence from a Field Experiment on Health and Education in Indonesia                                              |World Bank                  |https://doi.org/10.1257/app.6.4.1                |
|American Economic Journal: Applied Economics |2011-01-01      |10.1257/app.3.1.35               |Transactional Sex as a Response to Risk in Western Kenya                                                                                          |World Bank                  |https://doi.org/10.1257/app.3.1.35               |
|American Economic Journal: Applied Economics |2012-07-01      |10.1257/app.4.3.64               |Enforcement of Labor Regulation and Informality                                                                                                   |World Bank                  |https://doi.org/10.1257/app.4.3.64               |
|American Economic Journal: Applied Economics |2021-01-01      |10.1257/app.20190067             |Poverty and Migration in the Digital Age: Experimental Evidence on Mobile Banking in Bangladesh                                                   |World Bank                  |https://doi.org/10.1257/app.20190067             |
|American Economic Journal: Applied Economics |2013-01-01      |10.1257/app.5.1.104              |Barriers to Household Risk Management: Evidence from India                                                                                        |World Bank                  |https://doi.org/10.1257/app.5.1.104              |
|American Economic Journal: Applied Economics |2010-07-01      |10.1257/app.2.3.60               |Microfinance Games                                                                                                                                |World Bank                  |https://doi.org/10.1257/app.2.3.60               |
|American Economic Journal: Applied Economics |2023-01-01      |10.1257/app.20210041             |The Effects of Working While in School: Evidence from Employment Lotteries                                                                        |World Bank                  |https://doi.org/10.1257/app.20210041             |
|American Economic Journal: Applied Economics |2010-07-01      |10.1257/app.2.3.190              |Service Delivery and Corruption in Public Services: How Does History Matter?                                                                      |World Bank                  |https://doi.org/10.1257/app.2.3.190              |
|American Economic Journal: Applied Economics |2017-10-01      |10.1257/app.20150342             |Customary Norms, Inheritance, and Human Capital: Evidence from a Reform of the Matrilineal System in Ghana                                        |World Bank                  |https://doi.org/10.1257/app.20150342             |
|American Economic Journal: Applied Economics |2019-04-01      |10.1257/app.20170566             |Bridging the Intention-Behavior Gap? The Effect of Plan-Making Prompts on Job Search and Employment                                               |World Bank                  |https://doi.org/10.1257/app.20170566             |
|American Economic Journal: Applied Economics |2018-01-01      |10.1257/app.20130480             |Together We Will: Experimental Evidence on Female Voting Behavior in Pakistan                                                                     |World Bank                  |https://doi.org/10.1257/app.20130480             |
|American Economic Journal: Applied Economics |2017-01-01      |10.1257/app.20150512             |Politics and Local Economic Growth: Evidence from India                                                                                           |World Bank                  |https://doi.org/10.1257/app.20150512             |
|American Economic Journal: Applied Economics |2011-04-01      |10.1257/app.3.2.167              |Improving the Design of Conditional Transfer Programs: Evidence from a Randomized Education Experiment in Colombia                                |World Bank                  |https://doi.org/10.1257/app.3.2.167              |
|American Economic Journal: Applied Economics |2013-01-01      |10.1257/app.5.2.29               |School Inputs, Household Substitution, and Test Scores                                                                                            |World Bank                  |https://doi.org/10.1257/app.5.2.29               |
|American Economic Journal: Applied Economics |2014-04-01      |10.1257/app.6.2.49               |Distortions in the International Migrant Labor Market: Evidence from Filipino Migration and Wage Responses to Destination Country Economic Shocks |World Bank                  |https://doi.org/10.1257/app.6.2.49               |
|American Economic Journal: Applied Economics |2013-01-01      |10.1257/app.5.2.58               |The Effect of Absenteeism and Clinic Protocol on Health Outcomes: The Case of Mother-to-Child Transmission of HIV in Kenya                        |World Bank                  |https://doi.org/10.1257/app.5.2.58               |
|American Economic Journal: Applied Economics |2009-01-01      |10.1257/app.1.1.112              |Many Children Left Behind? Textbooks and Test Scores in Kenya                                                                                     |World Bank                  |https://doi.org/10.1257/app.1.1.112              |
|American Economic Journal: Applied Economics |2012-04-01      |10.1257/app.4.2.247              |Cash Transfers, Behavioral Changes, and Cognitive Development in Early Childhood: Evidence from a Randomized Experiment                           |World Bank                  |https://doi.org/10.1257/app.4.2.247              |
|American Economic Journal: Applied Economics |2010-07-01      |10.1257/app.2.3.22               |Information, Direct Access to Farmers, and Rural Market Performance in Central India                                                              |World Bank                  |https://doi.org/10.1257/app.2.3.22               |
|American Economic Journal: Applied Economics |2011-04-01      |10.1257/app.3.2.137              |Purchasing Power Parity Exchange Rates for the Global Poor                                                                                        |World Bank                  |https://doi.org/10.1257/app.3.2.137              |
|American Economic Journal: Applied Economics |2018-07-01      |10.1257/app.20160183             |Exploiting Externalities to Estimate the Long-Term Effects of Early Childhood Deworming                                                           |World Bank                  |https://doi.org/10.1257/app.20160183             |
|American Economic Journal: Applied Economics |2011-07-01      |10.1257/app.3.3.29               |Do Value-Added Estimates Add Value? Accounting for Learning Dynamics                                                                              |World Bank                  |https://doi.org/10.1257/app.3.3.29               |
|American Economic Journal: Applied Economics |2022-01-01      |10.1257/app.20190722             |Does Patient Demand Contribute to the Overuse of Prescription Drugs?                                                                              |World Bank                  |https://doi.org/10.1257/app.20190722             |
|American Economic Journal: Applied Economics |2009-06-01      |10.1257/app.1.3.1                |Are Women More Credit Constrained? Experimental Evidence on Gender and Microenterprise Returns                                                    |World Bank                  |https://doi.org/10.1257/app.1.3.1                |
|American Economic Journal: Applied Economics |2022-10-01      |10.1257/app.20200306             |Using Individual-Level Randomized Treatment to Learn about Market Structure                                                                       |World Bank                  |https://doi.org/10.1257/app.20200306             |
|American Economic Journal: Applied Economics |2010-10-01      |10.1257/app.2.4.236              |The Importance of Being Wanted                                                                                                                    |World Bank                  |https://doi.org/10.1257/app.2.4.236              |
|American Economic Journal: Applied Economics |2010-04-01      |10.1257/app.2.2.179              |Disclosure by Politicians                                                                                                                         |World Bank                  |https://doi.org/10.1257/app.2.2.179              |
|American Economic Journal: Applied Economics |2017-01-01      |10.1257/app.20150027             |Experimental Evidence on the Long-Run Impact of Community-Based Monitoring                                                                        |World Bank                  |https://doi.org/10.1257/app.20150027             |
|American Economic Journal: Applied Economics |2018-07-01      |10.1257/app.20160469             |Incentivizing Safer Sexual Behavior: Evidence from a Lottery Experiment on HIV Prevention                                                         |World Bank                  |https://doi.org/10.1257/app.20160469             |
|American Economic Journal: Applied Economics |2020-01-01      |10.1257/app.20170416             |Women’s Empowerment in Action: Evidence from a Randomized Control Trial in Africa                                                                 |World Bank                  |https://doi.org/10.1257/app.20170416             |
|American Economic Journal: Economic Policy   |2015-08-01      |10.1257/pol.20130225             |Turning a Shove into a Nudge? A “Labeled Cash Transfer” for Education                                                                             |World Bank                  |https://doi.org/10.1257/pol.20130225             |
|American Economic Journal: Economic Policy   |2022-11-01      |10.1257/pol.20200778             |Adviser Value Added and Student Outcomes: Evidence from Randomly Assigned College Advisers                                                        |World Bank                  |https://doi.org/10.1257/pol.20200778             |
|American Economic Journal: Economic Policy   |2017-11-01      |10.1257/pol.20150293             |Beggar-Thy-Neighbor Effects of Exchange Rates: A Study of the Renminbi                                                                            |World Bank                  |https://doi.org/10.1257/pol.20150293             |
|American Economic Journal: Economic Policy   |2022-11-01      |10.1257/pol.20190628             |Health Care Rationing in Public Insurance Programs: Evidence from Medicaid                                                                        |World Bank                  |https://doi.org/10.1257/pol.20190628             |
|American Economic Journal: Economic Policy   |2022-02-01      |10.1257/pol.20200123             |Technology, Taxation, and Corruption: Evidence from the Introduction of Electronic Tax Filing                                                     |World Bank                  |https://doi.org/10.1257/pol.20200123             |
|American Economic Journal: Economic Policy   |2010-02-01      |10.1257/pol.2.1.1                |Pitfalls of Participatory Programs: Evidence from a Randomized Evaluation in Education in India                                                   |World Bank                  |https://doi.org/10.1257/pol.2.1.1                |
|American Economic Journal: Economic Policy   |2014-11-01      |10.1257/pol.6.4.207              |Cash for Coolers: Evaluating a Large-Scale Appliance Replacement Program in Mexico                                                                |World Bank                  |https://doi.org/10.1257/pol.6.4.207              |
|American Economic Journal: Economic Policy   |2009-01-01      |10.1257/pol.1.1.28               |A Theory of Urban Squatting and Land-Tenure Formalization in Developing Countries                                                                 |World Bank                  |https://doi.org/10.1257/pol.1.1.28               |
|American Economic Journal: Economic Policy   |2019-08-01      |10.1257/pol.20160589             |Casting a Wider Tax Net: Experimental Evidence from Costa Rica                                                                                    |World Bank                  |https://doi.org/10.1257/pol.20160589             |
|American Economic Journal: Economic Policy   |2009-01-01      |10.1257/pol.1.1.75               |Housing, Health, and Happiness                                                                                                                    |World Bank                  |https://doi.org/10.1257/pol.1.1.75               |
|American Economic Journal: Economic Policy   |2021-11-01      |10.1257/pol.20180564             |Corporate Taxation under Weak Enforcement                                                                                                         |World Bank                  |https://doi.org/10.1257/pol.20180564             |
|American Economic Journal: Economic Policy   |2021-08-01      |10.1257/pol.20200100             |Using Labor Supply Elasticities to Learn about Income Inequality: The Role of Productivities versus Preferences                                   |World Bank                  |https://doi.org/10.1257/pol.20200100             |
|American Economic Journal: Macroeconomics    |2016-04-01      |10.1257/mac.20140147             |Excessive Financing Costs in a Representative Agent Framework                                                                                     |World Bank                  |https://doi.org/10.1257/mac.20140147             |
|American Economic Journal: Macroeconomics    |2010-10-01      |10.1257/mac.2.4.46               |Understanding PPPs and PPP-based National Accounts: Comment                                                                                       |World Bank                  |https://doi.org/10.1257/mac.2.4.46               |
|American Economic Journal: Macroeconomics    |2014-10-01      |10.1257/mac.6.4.209              |Medium Term Business Cycles in Developing Countries                                                                                               |World Bank                  |https://doi.org/10.1257/mac.6.4.209              |
|American Economic Journal: Macroeconomics    |2010-07-01      |10.1257/mac.2.3.31               |The Effect of Corporate Taxes on Investment and Entrepreneurship                                                                                  |World Bank                  |https://doi.org/10.1257/mac.2.3.31               |
|American Economic Journal: Macroeconomics    |2022-04-01      |10.1257/mac.20200234             |Entry Barriers, Idiosyncratic Distortions, and the Firm Size Distribution                                                                         |World Bank                  |https://doi.org/10.1257/mac.20200234             |
|American Economic Journal: Macroeconomics    |2014-01-01      |10.1257/mac.6.1.102              |Wage Rigidity and Disinflation in Emerging Countries                                                                                              |World Bank                  |https://doi.org/10.1257/mac.6.1.102              |
|American Economic Journal: Macroeconomics    |2018-04-01      |10.1257/mac.20140075             |Entry and Exit, Multiproduct Firms, and Allocative Distortions                                                                                    |World Bank                  |https://doi.org/10.1257/mac.20140075             |
|American Economic Journal: Microeconomics    |2016-02-01      |10.1257/mic.20140103             |A Theory of Rational Demand for Index Insurance                                                                                                   |World Bank                  |https://doi.org/10.1257/mic.20140103             |
|American Economic Journal: Microeconomics    |2022-02-01      |10.1257/mic.20190166             |Relationships on the Rocks: Contract Evolution in a Market for Ice                                                                                |World Bank                  |https://doi.org/10.1257/mic.20190166             |
|American Economic Review                     |2017-02-01      |10.1257/aer.20150314             |Misallocation and the Distribution of Global Volatility                                                                                           |World Bank                  |https://doi.org/10.1257/aer.20150314             |
|American Economic Review                     |2008-04-01      |10.1257/aer.98.2.457             |Firm-Level Heterogeneous Productivity and Demand Shocks: Evidence from Bangladesh                                                                 |World Bank                  |https://doi.org/10.1257/aer.98.2.457             |
|American Economic Review                     |2010-05-01      |10.1257/aer.100.2.614            |Wage Subsidies for Microenterprises                                                                                                               |World Bank                  |https://doi.org/10.1257/aer.100.2.614            |
|American Economic Review                     |2010-09-01      |10.1257/aer.100.4.1804           |<i>Watta Satta</i>: Bride Exchange and Women's Welfare in Rural Pakistan                                                                          |World Bank                  |https://doi.org/10.1257/aer.100.4.1804           |
|American Economic Review                     |2017-04-01      |10.1257/aer.20150503             |Reducing Crime and Violence: Experimental Evidence from Cognitive Behavioral Therapy in Liberia                                                   |World Bank                  |https://doi.org/10.1257/aer.20150503             |
|American Economic Review                     |2021-07-01      |10.1257/aer.20191972             |Recruitment, Effort, and Retention Effects of Performance Contracts for Civil Servants: Experimental Evidence from Rwandan Primary Schools        |World Bank                  |https://doi.org/10.1257/aer.20191972             |
|American Economic Review                     |2013-05-01      |10.1257/aer.103.3.362            |Behavioral Biases and Firm Behavior: Evidence from Kenyan Retail Shops                                                                            |World Bank                  |https://doi.org/10.1257/aer.103.3.362            |
|American Economic Review                     |2017-06-01      |10.1257/aer.20140774             |Report Cards: The Impact of Providing School and Child Test Scores on Educational Markets                                                         |World Bank                  |https://doi.org/10.1257/aer.20140774             |
|American Economic Review                     |2021-05-01      |10.1257/aer.20190240             |Cross-Region Transfer Multipliers in a Monetary Union: Evidence from Social Security and Stimulus Payments                                        |World Bank                  |https://doi.org/10.1257/aer.20190240             |
|American Economic Review                     |2010-05-01      |10.1257/aer.100.2.619            |Why Do Firms in Developing Countries Have Low Productivity?                                                                                       |World Bank                  |https://doi.org/10.1257/aer.100.2.619            |
|American Economic Review                     |2016-12-01      |10.1257/aer.20151138             |Quality and Accountability in Health Care Delivery: Audit-Study Evidence from Primary Care in India                                               |World Bank                  |https://doi.org/10.1257/aer.20151138             |
|American Economic Review                     |2021-12-01      |10.1257/aer.20181801             |Prep School for Poor Kids: The Long-Run Impacts of Head Start on Human Capital and Economic Self-Sufficiency                                      |World Bank                  |https://doi.org/10.1257/aer.20181801             |
|American Economic Review                     |2000-03-01      |10.1257/aer.90.1.147             |Liberalization, Moral Hazard in Banking, and Prudential Regulation: Are Capital Requirements Enough?                                              |World Bank                  |https://doi.org/10.1257/aer.90.1.147             |
|American Economic Review                     |2012-02-01      |10.1257/aer.102.1.504            |Why Don't We See Poverty Convergence?                                                                                                             |World Bank                  |https://doi.org/10.1257/aer.102.1.504            |
|American Economic Review                     |2006-04-01      |10.1257/000282806777212611       |Discrimination, Social Identity, and Durable Inequalities                                                                                         |World Bank                  |https://doi.org/10.1257/000282806777212611       |
|American Economic Review                     |2007-04-01      |10.1257/aer.97.2.316             |Aid Effectiveness—Opening the Black Box                                                                                                           |World Bank                  |https://doi.org/10.1257/aer.97.2.316             |
|American Economic Review                     |2017-10-01      |10.1257/aer.20141070             |Exporter Dynamics and Partial-Year Effects                                                                                                        |World Bank                  |https://doi.org/10.1257/aer.20141070             |
|American Economic Review                     |2022-11-01      |10.1257/aer.20211616             |The Psychosocial Value of Employment: Evidence from a Refugee Camp                                                                                |World Bank                  |https://doi.org/10.1257/aer.20211616             |
|American Economic Review                     |2017-08-01      |10.1257/aer.20151404             |Identifying and Spurring High-Growth Entrepreneurship: Experimental Evidence from a Business Plan Competition                                     |World Bank                  |https://doi.org/10.1257/aer.20151404             |
|American Economic Review                     |2002-08-01      |10.1257/00028280260344588        |Terror as a Bargaining Instrument: A Case Study of Dowry Violence in Rural India                                                                  |World Bank                  |https://doi.org/10.1257/00028280260344588        |
|American Economic Review                     |2006-04-01      |10.1257/000282806777212387       |Who Are China's Entrepreneurs?                                                                                                                    |World Bank                  |https://doi.org/10.1257/000282806777212387       |
|American Economic Review                     |2017-05-01      |10.1257/aer.p20171053            |Heat Exposure and Youth Migration in Central America and the Caribbean                                                                            |World Bank                  |https://doi.org/10.1257/aer.p20171053            |
|American Economic Review                     |2022-04-01      |10.1257/aer.20200738             |Public Procurement in Law and Practice                                                                                                            |World Bank                  |https://doi.org/10.1257/aer.20200738             |
|American Economic Review                     |2013-04-01      |10.1257/aer.103.2.1071           |Self-Enforcing Trade Agreements: Evidence from Time-Varying Trade Policy                                                                          |World Bank                  |https://doi.org/10.1257/aer.103.2.1071           |
|American Economic Review                     |2017-08-01      |10.1257/aer.20150592             |Hayek, Local Information, and Commanding Heights: Decentralizing State-Owned Enterprises in China                                                 |World Bank                  |https://doi.org/10.1257/aer.20150592             |
|American Economic Review                     |2003-04-01      |10.1257/000282803321946787       |The Future of the IMF and World Bank: Panel Discussion                                                                                            |World Bank                  |https://doi.org/10.1257/000282803321946787       |
|American Economic Review                     |2008-08-01      |10.1257/aer.98.4.1675            |Trade Policy and Loss Aversion                                                                                                                    |World Bank                  |https://doi.org/10.1257/aer.98.4.1675            |
|American Economic Review                     |2008-04-01      |10.1257/aer.98.2.494             |Spite and Development                                                                                                                             |World Bank                  |https://doi.org/10.1257/aer.98.2.494             |
|American Economic Review                     |2021-06-01      |10.1257/aer.20190586             |The Selection of Talent: Experimental and Structural Evidence from Ethiopia                                                                       |World Bank                  |https://doi.org/10.1257/aer.20190586             |
|American Economic Review                     |2002-11-01      |10.1257/000282802762024575       |Hazards of Expropriation: Tenure Insecurity and Investment in Rural China                                                                         |World Bank                  |https://doi.org/10.1257/000282802762024575       |
|American Economic Review                     |2016-01-01      |10.1257/aer.20141301             |The Market Impacts of Pharmaceutical Product Patents in Developing Countries: Evidence from India                                                 |World Bank                  |https://doi.org/10.1257/aer.20141301             |
|American Economic Review                     |2012-12-01      |10.1257/aer.102.7.3406           |Exports, Export Destinations, and Skills                                                                                                          |World Bank                  |https://doi.org/10.1257/aer.102.7.3406           |
|American Economic Review                     |2012-05-01      |10.1257/aer.102.3.555            |Love and Money by Parental Matchmaking: Evidence from Urban Couples in China                                                                      |World Bank                  |https://doi.org/10.1257/aer.102.3.555            |
|American Economic Review                     |2005-08-01      |10.1257/0002828054825682         |Homeownership, Community Interactions, and Segregation                                                                                            |World Bank                  |https://doi.org/10.1257/0002828054825682         |
|American Economic Review                     |2013-05-01      |10.1257/aer.103.3.263            |Is Ignorance Bliss? The Effect of Asymmetric Information between Spouses on Intra-Household Allocations                                           |World Bank                  |https://doi.org/10.1257/aer.103.3.263            |
|American Economic Review                     |2014-05-01      |10.1257/aer.104.5.354            |Labor Supply and Household Dynamics                                                                                                               |World Bank                  |https://doi.org/10.1257/aer.104.5.354            |
|American Economic Review                     |2008-08-01      |10.1257/aer.98.4.1722            |A Note on Different Approaches to Index Number Theory                                                                                             |World Bank                  |https://doi.org/10.1257/aer.98.4.1722            |
|American Economic Review                     |2016-06-01      |10.1257/aer.20131455             |The Demand for Energy-Using Assets among the World's Rising Middle Classes                                                                        |World Bank                  |https://doi.org/10.1257/aer.20131455             |
|American Economic Review                     |2004-04-01      |10.1257/0002828041301524         |On the Measurement of Product Variety in Trade                                                                                                    |World Bank                  |https://doi.org/10.1257/0002828041301524         |
|American Economic Review                     |2010-03-01      |10.1257/aer.100.1.247            |Multinationals and Anti-Sweatshop Activism                                                                                                        |World Bank                  |https://doi.org/10.1257/aer.100.1.247            |
|American Economic Review                     |2022-07-01      |10.1257/aer.20210059             |Factor Market Failures and the Adoption of Irrigation in Rwanda                                                                                   |World Bank                  |https://doi.org/10.1257/aer.20210059             |
|American Economic Review                     |2016-07-01      |10.1257/aer.20140705             |Network Structure and the Aggregation of Information: Theory and Evidence from Indonesia                                                          |World Bank                  |https://doi.org/10.1257/aer.20140705             |
|American Economic Review                     |2002-08-01      |10.1257/00028280260344443        |Inequality Among World Citizens: 1820–1992                                                                                                        |World Bank                  |https://doi.org/10.1257/00028280260344443        |
|American Economic Review                     |2005-05-01      |10.1257/0002828054201468         |Ethnic Polarization, Potential Conflict, and Civil Wars                                                                                           |World Bank                  |https://doi.org/10.1257/0002828054201468         |
|American Economic Review                     |2016-06-01      |10.1257/aer.20131687             |Domestic Value Added in Exports: Theory and Firm Evidence from China                                                                              |World Bank                  |https://doi.org/10.1257/aer.20131687             |
|American Economic Review                     |2015-05-01      |10.1257/aer.p20151003            |The Impact of Ethnic Diversity in Bureaucracies: Evidence from the Nigerian Civil Service                                                         |World Bank                  |https://doi.org/10.1257/aer.p20151003            |
|American Economic Review                     |2010-05-01      |10.1257/aer.100.2.141            |Equilibrium Fictions: A Cognitive Approach to Societal Rigidity                                                                                   |World Bank                  |https://doi.org/10.1257/aer.100.2.141            |
|American Economic Review                     |2010-05-01      |10.1257/aer.100.2.629            |What Capital is Missing in Developing Countries?                                                                                                  |World Bank                  |https://doi.org/10.1257/aer.100.2.629            |
|American Economic Review                     |2012-10-01      |10.1257/aer.102.6.2923           |Credit Market Consequences of Improved Personal Identification: Field Experimental Evidence from Malawi                                           |World Bank                  |https://doi.org/10.1257/aer.102.6.2923           |
|American Economic Review                     |2004-05-01      |10.1257/0002828041464533         |After the Big Bang? Obstacles to the Emergence of the Rule of Law in Post-Communist Societies                                                     |World Bank                  |https://doi.org/10.1257/0002828041464533         |
|American Economic Review                     |2012-06-01      |10.1257/aer.102.4.1206           |Targeting the Poor: Evidence from a Field Experiment in Indonesia                                                                                 |World Bank                  |https://doi.org/10.1257/aer.102.4.1206           |
|American Economic Review                     |2015-05-01      |10.1257/aer.p20151120            |Can Alcohol Prohibition Reduce Violence Against Women?                                                                                            |World Bank                  |https://doi.org/10.1257/aer.p20151120            |
|American Economic Review                     |2014-05-01      |10.1257/aer.104.5.284            |Dynamics of Demand for Index Insurance: Evidence from a Long-Run Field Experiment                                                                 |World Bank                  |https://doi.org/10.1257/aer.104.5.284            |
|American Economic Review                     |2000-09-01      |10.1257/aer.90.4.847             |Aid, Policies, and Growth                                                                                                                         |World Bank                  |https://doi.org/10.1257/aer.90.4.847             |
|American Economic Review                     |2010-06-01      |10.1257/aer.100.3.1008           |Trade Shocks and Labor Adjustment: A Structural Empirical Approach                                                                                |World Bank                  |https://doi.org/10.1257/aer.100.3.1008           |
|American Economic Review                     |2006-11-01      |10.1257/aer.96.5.1477            |Estimating the Effects of Global Patent Protection in Pharmaceuticals: A Case Study of Quinolones in India                                        |World Bank                  |https://doi.org/10.1257/aer.96.5.1477            |
|American Economic Review                     |2004-05-01      |10.1257/0002828041464524         |Aid, Policies, and Growth: Reply                                                                                                                  |World Bank                  |https://doi.org/10.1257/0002828041464524         |
|American Economic Review                     |2002-11-01      |10.1257/000282802762024629       |Vouchers for Private Schooling in Colombia: Evidence from a Randomized Natural Experiment                                                         |World Bank                  |https://doi.org/10.1257/000282802762024629       |
|American Economic Review                     |2022-11-01      |10.1257/aer.20200961             |Job Search and Hiring with Limited Information about Workseekers’ Skills                                                                          |World Bank                  |https://doi.org/10.1257/aer.20200961             |
|American Economic Review                     |2018-02-01      |10.1257/aer.20140647             |Export Destinations and Input Prices                                                                                                              |World Bank                  |https://doi.org/10.1257/aer.20140647             |
|American Economic Review                     |2014-05-01      |10.1257/aer.104.5.586            |Why Are Power Plants in India Less Efficient than Power Plants in the United States?                                                              |World Bank                  |https://doi.org/10.1257/aer.104.5.586            |
|The Quarterly Journal of Economics           |2018-05-01      |10.1093/qje/qjx040               |Double for Nothing? Experimental Evidence on an Unconditional Teacher Salary Increase in Indonesia*                                               |World Bank                  |https://doi.org/10.1093/qje/qjx040               |
|The Quarterly Journal of Economics           |2022-09-20      |10.1093/qje/qjac020              |Valuing the Global Mortality Consequences of Climate Change Accounting for Adaptation Costs and Benefits                                          |World Bank                  |https://doi.org/10.1093/qje/qjac020              |
|The Quarterly Journal of Economics           |2020-02-01      |10.1093/qje/qjz036               |The Return to Protectionism*                                                                                                                      |World Bank                  |https://doi.org/10.1093/qje/qjz036               |
|The Quarterly Journal of Economics           |2018-08-01      |10.1093/qje/qjx048               |Status Goods: Experimental Evidence from Platinum Credit Cards*                                                                                   |World Bank                  |https://doi.org/10.1093/qje/qjx048               |
|The Quarterly Journal of Economics           |2022-12-15      |10.1093/qje/qjac032              |Corruption in Customs                                                                                                                             |World Bank                  |https://doi.org/10.1093/qje/qjac032              |
|The Review of Economic Studies               |2021-05-22      |10.1093/restud/rdaa057           |Anonymity or Distance? Job Search and Labour Market Exclusion in a Growing African City                                                           |World Bank                  |https://doi.org/10.1093/restud/rdaa057           |
|The Review of Economic Studies               |2022-01-10      |10.1093/restud/rdab005           |Improving Management with Individual and Group-Based Consulting: Results from a Randomized Experiment in Colombia                                 |World Bank                  |https://doi.org/10.1093/restud/rdab005           |
|The Economic Journal                         |2011-11-01      |10.1111/j.1468-0297.2011.02476.x |Caste and Punishment: The Legacy of Caste Culture in Norm Enforcement                                                                             |World Bank                  |https://doi.org/10.1111/j.1468-0297.2011.02476.x |
|The Economic Journal                         |2004-06-01      |10.1111/j.1468-0297.2004.00221.x |Development Effectiveness: What have We Learnt?                                                                                                   |World Bank                  |https://doi.org/10.1111/j.1468-0297.2004.00221.x |
|The Economic Journal                         |2012-03-01      |10.1111/j.1468-0297.2011.02475.x |Enterprise Recovery Following Natural Disasters                                                                                                   |World Bank                  |https://doi.org/10.1111/j.1468-0297.2011.02475.x |
|The Economic Journal                         |2011-12-01      |10.1111/j.1468-0297.2011.02452.x |Did Higher Inequality Impede Growth in Rural China?                                                                                               |World Bank                  |https://doi.org/10.1111/j.1468-0297.2011.02452.x |
|The Economic Journal                         |2012-05-01      |10.1111/j.1468-0297.2012.02498.x |The Economic Consequences of ‘Brain Drain’ of the Best and Brightest: Microeconomic Evidence from Five Countries                                  |World Bank                  |https://doi.org/10.1111/j.1468-0297.2012.02498.x |
|The Economic Journal                         |2011-03-01      |10.1111/j.1468-0297.2010.02403.x |Pre‐Industrial Inequality                                                                                                                         |World Bank                  |https://doi.org/10.1111/j.1468-0297.2010.02403.x |
|The Economic Journal                         |2000-10-01      |10.1111/1468-0297.00569          |What Explains the Success or Failure of Structural Adjustment Programmes?                                                                         |World Bank                  |https://doi.org/10.1111/1468-0297.00569          |
|The Economic Journal                         |2004-02-01      |10.1111/j.0013-0133.2004.00186.x |Trade, Growth, and Poverty                                                                                                                        |World Bank                  |https://doi.org/10.1111/j.0013-0133.2004.00186.x |
|The Economic Journal                         |2007-02-01      |10.1111/j.1468-0297.2007.02017.x |Financial performance and Outreach: A Global Analysis of Leading Microbanks                                                                       |World Bank                  |https://doi.org/10.1111/j.1468-0297.2007.02017.x |
|The Economic Journal                         |2023-01-13      |10.1093/ej/ueac058               |Long-Term and Intergenerational Effects of Education: Evidence from School Construction in Indonesia                                              |World Bank                  |https://doi.org/10.1093/ej/ueac058               |
|The Economic Journal                         |2019-01-01      |10.1111/ecoj.12594               |Tackling Social Exclusion: Evidence from Chile                                                                                                    |World Bank                  |https://doi.org/10.1111/ecoj.12594               |
|The Economic Journal                         |2000-03-01      |10.1111/1468-0297.00527          |Does Child Labour Displace Schooling? Evidence on Behavioural Responses to an Enrollment Subsidy                                                  |World Bank                  |https://doi.org/10.1111/1468-0297.00527          |
|The Economic Journal                         |2014-09         |10.1111/ecoj.12077               |The Labour Market Effects of Immigration and Emigration in OECD Countries                                                                         |World Bank                  |https://doi.org/10.1111/ecoj.12077               |
|The Economic Journal                         |2016-12         |10.1111/ecoj.12276               |The Persistence of (Subnational) Fortune                                                                                                          |World Bank                  |https://doi.org/10.1111/ecoj.12276               |
|The Economic Journal                         |2015-08-01      |10.1111/ecoj.12300               |Sovereign Debt and Joint Liability: An Economic Theory Model for Amending the Treaty of Lisbon                                                    |World Bank                  |https://doi.org/10.1111/ecoj.12300               |
|The Economic Journal                         |2005-04-01      |10.1111/j.1468-0297.2005.00997.x |Cities and Specialisation: Evidence from South Asia                                                                                               |World Bank                  |https://doi.org/10.1111/j.1468-0297.2005.00997.x |
|The Economic Journal                         |2003-04-01      |10.1111/1468-0297.00127          |The simultaneous evolution of growth and inequality                                                                                               |World Bank                  |https://doi.org/10.1111/1468-0297.00127          |
|The Economic Journal                         |2018-02         |10.1111/ecoj.12418               |Management of Bureaucrats and Public Service Delivery: Evidence from the Nigerian Civil Service                                                   |World Bank                  |https://doi.org/10.1111/ecoj.12418               |
|The Economic Journal                         |2018-02         |10.1111/ecoj.12378               |Revising Commitments: Field Evidence on the Adjustment of Prior Choices                                                                           |World Bank                  |https://doi.org/10.1111/ecoj.12378               |
|The Economic Journal                         |2014-05         |10.1111/ecoj.12145               |Changing Households' Investment Behaviour through Social Interactions with Local Leaders: Evidence from a Randomised Transfer Programme           |World Bank                  |https://doi.org/10.1111/ecoj.12145               |
|The Economic Journal                         |2022-09-19      |10.1093/ej/ueac018               |Transfers, Diversification and Household Risk Strategies: Can Productive Safety Nets Help Households Manage Climatic Variability?                 |World Bank                  |https://doi.org/10.1093/ej/ueac018               |
|The Economic Journal                         |2001-03-01      |10.1111/1468-0297.00609          |Trust and Growth                                                                                                                                  |World Bank                  |https://doi.org/10.1111/1468-0297.00609          |
|The Economic Journal                         |2021-11-08      |10.1093/ej/ueab023               |Does Democratisation Promote Competition? Evidence from Indonesia*                                                                                |World Bank                  |https://doi.org/10.1093/ej/ueab023               |
|The Economic Journal                         |2018-07-01      |10.1111/ecoj.12456               |Transit Migration: All Roads Lead to America                                                                                                      |World Bank                  |https://doi.org/10.1111/ecoj.12456               |
|The Economic Journal                         |2000-03-01      |10.1111/1468-0297.00520          |The Intriguing Relation Between Adult Minimum Wage and Child Labour                                                                               |World Bank                  |https://doi.org/10.1111/1468-0297.00520          |
|The Economic Journal                         |2020-10-16      |10.1093/ej/ueaa022               |Education Quality and Teaching Practices                                                                                                          |World Bank                  |https://doi.org/10.1093/ej/ueaa022               |
|The Economic Journal                         |2016-09         |10.1111/ecoj.12214               |Wage Adjustment and Productivity Shocks                                                                                                           |World Bank                  |https://doi.org/10.1111/ecoj.12214               |
|The Economic Journal                         |2007-04-01      |10.1111/j.1468-0297.2007.02053.x |Home Grown or Imported? Initial Conditions, External Anchors and the Determinants of Institutional Reform in the Transition Economies             |World Bank                  |https://doi.org/10.1111/j.1468-0297.2007.02053.x |
|The Economic Journal                         |2019-01-01      |10.1111/ecoj.12533               |Public-sector Employment in an Equilibrium Search and Matching Model                                                                              |World Bank                  |https://doi.org/10.1111/ecoj.12533               |
|The Economic Journal                         |2016-02-01      |10.1111/ecoj.12206               |Services Reform and Manufacturing Performance: Evidence from India                                                                                |World Bank                  |https://doi.org/10.1111/ecoj.12206               |
|The Economic Journal                         |2011-11-01      |10.1111/j.1468-0297.2011.02478.x |Introduction: Tastes, Castes and Culture: The Influence of Society on Preferences                                                                 |World Bank                  |https://doi.org/10.1111/j.1468-0297.2011.02478.x |
|The Economic Journal                         |2016-03         |10.1111/ecoj.12207               |Highway to Success: The Impact of the Golden Quadrilateral Project for the Location and Performance of Indian Manufacturing                       |World Bank                  |https://doi.org/10.1111/ecoj.12207               |
|The Economic Journal                         |2009-01-01      |10.1111/j.1468-0297.2008.02209.x |Estimating Trade Restrictiveness Indices                                                                                                          |World Bank                  |https://doi.org/10.1111/j.1468-0297.2008.02209.x |
|The Economic Journal                         |2005-04-01      |10.1111/j.1468-0297.2005.00992.x |Sargent‐Wallace Meets Krugman‐Flood‐Garber, or: Why Sovereign Debt Swaps do not Avert Macroeconomic Crises                                        |World Bank                  |https://doi.org/10.1111/j.1468-0297.2005.00992.x |
|The Economic Journal                         |2003-06-01      |10.1111/1468-0297.13913          |The Role of Annuity Markets in Financing Retirement.                                                                                              |World Bank                  |https://doi.org/10.1111/1468-0297.13913          |
|The Economic Journal                         |2000-01-01      |10.1111/1468-0297.00502          |Mexico's Financial Sector Crisis: Propagative Linkages to Devaluation                                                                             |World Bank                  |https://doi.org/10.1111/1468-0297.00502          |
|The Economic Journal                         |2018-07-01      |10.1111/ecoj.12536               |Cross‐country Perspectives on Migration and Development: Introduction                                                                             |World Bank                  |https://doi.org/10.1111/ecoj.12536               |
|The Economic Journal                         |2008-08-01      |10.1111/j.1468-0297.2008.02177.x |Exiting a Lawless State                                                                                                                           |World Bank                  |https://doi.org/10.1111/j.1468-0297.2008.02177.x |
|The Economic Journal                         |2010-08-01      |10.1111/j.1468-0297.2010.02373.x |The Impact of Diagnostic Feedback to Teachers on Student Learning: Experimental Evidence from India                                               |World Bank                  |https://doi.org/10.1111/j.1468-0297.2010.02373.x |
|The Economic Journal                         |2013-09-01      |10.1111/ecoj.12020               |Community Nurseries and the Nutritional Status of Poor Children. Evidence from Colombia                                                           |World Bank                  |https://doi.org/10.1111/ecoj.12020               |
|The Economic Journal                         |2022-01-07      |10.1093/ej/ueab035               |On the Quantity and Quality of Girls: Fertility, Parental Investments and Mortality                                                               |World Bank                  |https://doi.org/10.1093/ej/ueab035               |
|The Economic Journal                         |2000-07-01      |10.1111/1468-0297.00562          |Access to Markets and the Benefits of Rural Roads                                                                                                 |World Bank                  |https://doi.org/10.1111/1468-0297.00562          |
|The Economic Journal                         |2010-05-01      |10.1111/j.1468-0297.2010.02356.x |Multi‐Product Exporters: Product Churning, Uncertainty and Export Discoveries                                                                     |World Bank                  |https://doi.org/10.1111/j.1468-0297.2010.02356.x |
|The Economic Journal                         |2002-01-01      |10.1111/1468-0297.0j673          |True World Income Distribution, 1988 and 1993: First Calculation Based on Household Surveys Alone                                                 |World Bank                  |https://doi.org/10.1111/1468-0297.0j673          |
|The Economic Journal                         |2016-11         |10.1111/ecoj.12211               |The Impact of Vocational Training for the Unemployed: Experimental Evidence from Turkey                                                           |World Bank                  |https://doi.org/10.1111/ecoj.12211               |
|The Economic Journal                         |2020-07-01      |10.1093/ej/ueaa013               |The Ecological Impact of Transportation Infrastructure                                                                                            |World Bank                  |https://doi.org/10.1093/ej/ueaa013               |
|The Economic Journal                         |2007-10-01      |10.1111/j.1468-0297.2007.02082.x |Budget Support Versus Project Aid: A Theoretical Appraisal                                                                                        |World Bank                  |https://doi.org/10.1111/j.1468-0297.2007.02082.x |
|The Economic Journal                         |2006-10-01      |10.1111/j.1468-0297.2006.01117.x |Land Reallocation in an Agrarian Transition                                                                                                       |World Bank                  |https://doi.org/10.1111/j.1468-0297.2006.01117.x |
|The Economic Journal                         |2018-07-01      |10.1111/ecoj.12463               |Why Don't Remittances Appear to Affect Growth?                                                                                                    |World Bank                  |https://doi.org/10.1111/ecoj.12463               |
|The Economic Journal                         |2022-07-14      |10.1093/ej/ueac012               |Patterns of Labour Market Adjustment to Trade Shocks with Imperfect Capital Mobility                                                              |World Bank                  |https://doi.org/10.1093/ej/ueac012               |
|The Economic Journal                         |2002-01-01      |10.1111/1468-0297.0j679          |Is There an Intrahousehold ‘Flypaper Effect’? Evidence from a School Feeding Programme                                                            |World Bank                  |https://doi.org/10.1111/1468-0297.0j679          |
|The Economic Journal                         |2004-01-01      |10.1046/j.0013-0133.2003.0174.x  |The Economical Control of Infectious Diseases                                                                                                     |World Bank                  |https://doi.org/10.1046/j.0013-0133.2003.0174.x  |
|American Economic Journal: Applied Economics |2012-10-01      |10.1257/app.4.4.165              |The Power of Political Voice: Women's Political Representation and Crime in India                                                                 |IMF                         |https://doi.org/10.1257/app.4.4.165              |
|American Economic Journal: Macroeconomics    |2013-10-01      |10.1257/mac.5.4.179              |Democracy and Reforms: Evidence from a New Dataset                                                                                                |IMF                         |https://doi.org/10.1257/mac.5.4.179              |
|American Economic Journal: Macroeconomics    |2012-01-01      |10.1257/mac.4.1.22               |Effects of Fiscal Stimulus in Structural Models                                                                                                   |IMF                         |https://doi.org/10.1257/mac.4.1.22               |
|American Economic Journal: Macroeconomics    |2011-10-01      |10.1257/mac.3.4.53               |Exchange Rates and Wages in an Integrated World                                                                                                   |IMF                         |https://doi.org/10.1257/mac.3.4.53               |
|American Economic Review                     |2014-05-01      |10.1257/aer.104.5.342            |Unilateral Divorce, the Decreasing Gender Gap, and Married Women's Labor Force Participation                                                      |IMF                         |https://doi.org/10.1257/aer.104.5.342            |
|American Economic Review                     |2006-04-01      |10.1257/000282806777212170       |Modernizing China's Growth Paradigm                                                                                                               |IMF                         |https://doi.org/10.1257/000282806777212170       |
|American Economic Review                     |2009-05-01      |10.1257/aer.99.3.883             |Misselling through Agents                                                                                                                         |IMF                         |https://doi.org/10.1257/aer.99.3.883             |
|American Economic Review                     |2010-05-01      |10.1257/aer.100.2.41             |Debt Consolidation and Fiscal Stabilization of Deep Recessions                                                                                    |IMF                         |https://doi.org/10.1257/aer.100.2.41             |
|American Economic Review                     |2012-04-01      |10.1257/aer.102.2.780            |Competition through Commissions and Kickbacks                                                                                                     |IMF                         |https://doi.org/10.1257/aer.102.2.780            |
|The Review of Economic Studies               |2020-01-01      |10.1093/restud/rdy060            |The New Keynesian Transmission Mechanism: A Heterogeneous-Agent Perspective                                                                       |IMF                         |https://doi.org/10.1093/restud/rdy060            |
|The Economic Journal                         |2003-01-01      |10.1111/1468-0297.00093          |Identifying the Common Component of International Economic Fluctuations: A new Approach                                                           |IMF                         |https://doi.org/10.1111/1468-0297.00093          |
|The Economic Journal                         |2021-08-01      |10.1093/ej/ueab017               |Policies in Hard Times: Assessing the Impact of Financial Crises on Structural Reforms                                                            |IMF                         |https://doi.org/10.1093/ej/ueab017               |
|The Economic Journal                         |2007-10-01      |10.1111/j.1468-0297.2007.02082.x |Budget Support Versus Project Aid: A Theoretical Appraisal                                                                                        |IMF                         |https://doi.org/10.1111/j.1468-0297.2007.02082.x |
|American Economic Journal: Applied Economics |2010-10-01      |10.1257/app.2.4.1                |Factor Immobility and Regional Impacts of Trade Liberalization: Evidence on Poverty from India                                                    |International Monetary Fund |https://doi.org/10.1257/app.2.4.1                |
|American Economic Journal: Applied Economics |2012-10-01      |10.1257/app.4.4.165              |The Power of Political Voice: Women's Political Representation and Crime in India                                                                 |International Monetary Fund |https://doi.org/10.1257/app.4.4.165              |
|American Economic Journal: Applied Economics |2013-01-01      |10.1257/app.5.1.104              |Barriers to Household Risk Management: Evidence from India                                                                                        |International Monetary Fund |https://doi.org/10.1257/app.5.1.104              |
|American Economic Journal: Applied Economics |2010-10-01      |10.1257/app.2.4.42               |Trade Adjustment and Human Capital Investments: Evidence from Indian Tariff Reform                                                                |International Monetary Fund |https://doi.org/10.1257/app.2.4.42               |
|American Economic Journal: Economic Policy   |2014-11-01      |10.1257/pol.6.4.343              |The Dynamics of Firm Lobbying                                                                                                                     |International Monetary Fund |https://doi.org/10.1257/pol.6.4.343              |
|American Economic Journal: Economic Policy   |2023-05-01      |10.1257/pol.20210166             |Borrowing Costs after Sovereign Debt Relief                                                                                                       |International Monetary Fund |https://doi.org/10.1257/pol.20210166             |
|American Economic Journal: Economic Policy   |2013-02-01      |10.1257/pol.5.1.1                |The Iceberg Theory of Campaign Contributions: Political Threats and Interest Group Behavior                                                       |International Monetary Fund |https://doi.org/10.1257/pol.5.1.1                |
|American Economic Journal: Economic Policy   |2019-02-01      |10.1257/pol.20170403             |Effectiveness of Fiscal Incentives for R&amp;D: Quasi-experimental Evidence                                                                       |International Monetary Fund |https://doi.org/10.1257/pol.20170403             |
|American Economic Journal: Economic Policy   |2023-02-01      |10.1257/pol.20200212             |Exploring Residual Profit Allocation                                                                                                              |International Monetary Fund |https://doi.org/10.1257/pol.20200212             |
|American Economic Journal: Economic Policy   |2020-02-01      |10.1257/pol.20180592             |Where Does Multinational Investment Go with Territorial Taxation? Evidence from the United Kingdom                                                |International Monetary Fund |https://doi.org/10.1257/pol.20180592             |
|American Economic Journal: Economic Policy   |2013-05-01      |10.1257/pol.5.2.77               |Multi-Product Firms and Exchange Rate Fluctuations                                                                                                |International Monetary Fund |https://doi.org/10.1257/pol.5.2.77               |
|American Economic Journal: Macroeconomics    |2020-04-01      |10.1257/mac.20160023             |Did Unconventional Interventions Unfreeze the Credit Market?                                                                                      |International Monetary Fund |https://doi.org/10.1257/mac.20160023             |
|American Economic Journal: Macroeconomics    |2018-10-01      |10.1257/mac.20150379             |International Transmission with Heterogeneous Sectors                                                                                             |International Monetary Fund |https://doi.org/10.1257/mac.20150379             |
|American Economic Journal: Macroeconomics    |2010-04-01      |10.1257/mac.2.2.95               |Putting the Parts Together: Trade, Vertical Linkages, and Business Cycle Comovement                                                               |International Monetary Fund |https://doi.org/10.1257/mac.2.2.95               |
|American Economic Journal: Macroeconomics    |2020-10-01      |10.1257/mac.20180484             |Quantitative Easing, Collateral Constraints, and Financial Spillovers                                                                             |International Monetary Fund |https://doi.org/10.1257/mac.20180484             |
|American Economic Journal: Macroeconomics    |2020-01-01      |10.1257/mac.20170436             |The Agricultural Wage Gap: Evidence from Brazilian Micro-data                                                                                     |International Monetary Fund |https://doi.org/10.1257/mac.20170436             |
|American Economic Journal: Macroeconomics    |2013-10-01      |10.1257/mac.5.4.179              |Democracy and Reforms: Evidence from a New Dataset                                                                                                |International Monetary Fund |https://doi.org/10.1257/mac.5.4.179              |
|American Economic Journal: Macroeconomics    |2022-10-01      |10.1257/mac.20170479             |Fiscal Rules and the Sovereign Default Premium                                                                                                    |International Monetary Fund |https://doi.org/10.1257/mac.20170479             |
|American Economic Journal: Macroeconomics    |2022-01-01      |10.1257/mac.20190332             |On the Macroeconomic Consequences of Over-Optimism                                                                                                |International Monetary Fund |https://doi.org/10.1257/mac.20190332             |
|American Economic Journal: Macroeconomics    |2009-06-01      |10.1257/mac.1.2.155              |The International Diversification Puzzle When Goods Prices Are Sticky: It's Really about Exchange-Rate Hedging, Not Equity Portfolios             |International Monetary Fund |https://doi.org/10.1257/mac.1.2.155              |
|American Economic Journal: Macroeconomics    |2022-01-01      |10.1257/mac.20200084             |Knowledge Diffusion, Trade, and Innovation across Countries and Sectors                                                                           |International Monetary Fund |https://doi.org/10.1257/mac.20200084             |
|American Economic Journal: Macroeconomics    |2018-01-01      |10.1257/mac.20150355             |Firms and the Decline in Earnings Inequality in Brazil                                                                                            |International Monetary Fund |https://doi.org/10.1257/mac.20150355             |
|American Economic Journal: Macroeconomics    |2017-07-01      |10.1257/mac.20150293             |Free to Leave? A Welfare Analysis of Divorce Regimes                                                                                              |International Monetary Fund |https://doi.org/10.1257/mac.20150293             |
|American Economic Journal: Macroeconomics    |2022-07-01      |10.1257/mac.20180428             |The Term Structure of Growth-at-Risk                                                                                                              |International Monetary Fund |https://doi.org/10.1257/mac.20180428             |
|American Economic Journal: Macroeconomics    |2021-01-01      |10.1257/mac.20180227             |The Size Distribution of Firms and Industrial Water Pollution: A Quantitative Analysis of China                                                   |International Monetary Fund |https://doi.org/10.1257/mac.20180227             |
|American Economic Journal: Macroeconomics    |2020-07-01      |10.1257/mac.20180286             |Sticky Expectations and Consumption Dynamics                                                                                                      |International Monetary Fund |https://doi.org/10.1257/mac.20180286             |
|American Economic Journal: Macroeconomics    |2014-07-01      |10.1257/mac.6.3.102              |Growth and Capital Flows with Risky Entrepreneurship                                                                                              |International Monetary Fund |https://doi.org/10.1257/mac.6.3.102              |
|American Economic Journal: Macroeconomics    |2011-10-01      |10.1257/mac.3.4.53               |Exchange Rates and Wages in an Integrated World                                                                                                   |International Monetary Fund |https://doi.org/10.1257/mac.3.4.53               |
|American Economic Journal: Macroeconomics    |2012-10-01      |10.1257/mac.4.4.126              |Why Are Target Interest Rate Changes so Persistent?                                                                                               |International Monetary Fund |https://doi.org/10.1257/mac.4.4.126              |
|American Economic Journal: Macroeconomics    |2010-01-01      |10.1257/mac.2.1.93               |Why Are Saving Rates of Urban Households in China Rising?                                                                                         |International Monetary Fund |https://doi.org/10.1257/mac.2.1.93               |
|American Economic Journal: Microeconomics    |2022-02-01      |10.1257/mic.20180044             |Cultural Affinity, Regulation, and Market Structure: Evidence from the Canadian Retail Banking Industry                                           |International Monetary Fund |https://doi.org/10.1257/mic.20180044             |
|American Economic Review                     |2006-04-01      |10.1257/000282806777211720       |Asian Growth and African Development                                                                                                              |International Monetary Fund |https://doi.org/10.1257/000282806777211720       |
|American Economic Review                     |2002-04-01      |10.1257/000282802320191679       |The Wage Gap and Public Support for Social Security                                                                                               |International Monetary Fund |https://doi.org/10.1257/000282802320191679       |
|American Economic Review                     |2019-01-01      |10.1257/aer.20171338             |The Cyclicality of Sales, Regular and Effective Prices: Business Cycle and Policy Implications: Reply                                             |International Monetary Fund |https://doi.org/10.1257/aer.20171338             |
|American Economic Review                     |2000-06-01      |10.1257/aer.90.3.667             |The Role of a Variable Input in the Relationship Between Investment and Uncertainty                                                               |International Monetary Fund |https://doi.org/10.1257/aer.90.3.667             |
|American Economic Review                     |2006-11-01      |10.1257/aer.96.5.1706            |Storable Good Monopoly: The Role of Commitment                                                                                                    |International Monetary Fund |https://doi.org/10.1257/aer.96.5.1706            |
|American Economic Review                     |2007-04-01      |10.1257/aer.97.2.322             |Does Aid Affect Governance                                                                                                                        |International Monetary Fund |https://doi.org/10.1257/aer.97.2.322             |
|American Economic Review                     |2003-04-01      |10.1257/000282803321946804       |How Does Globalization Affect the Synchronization of Business Cycles?                                                                             |International Monetary Fund |https://doi.org/10.1257/000282803321946804       |
|American Economic Review                     |2013-05-01      |10.1257/aer.103.3.117            |Growth Forecast Errors and Fiscal Multipliers                                                                                                     |International Monetary Fund |https://doi.org/10.1257/aer.103.3.117            |
|American Economic Review                     |2012-05-01      |10.1257/aer.102.3.294            |Child Health and Conflict in Côte d'Ivoire                                                                                                        |International Monetary Fund |https://doi.org/10.1257/aer.102.3.294            |
|American Economic Review                     |2006-04-01      |10.1257/000282806777211621       |Has Government Investment Crowded Out Private Investment in India?                                                                                |International Monetary Fund |https://doi.org/10.1257/000282806777211621       |
|American Economic Review                     |2013-12-01      |10.1257/aer.103.7.3045           |News, Noise, and Fluctuations: An Empirical Exploration                                                                                           |International Monetary Fund |https://doi.org/10.1257/aer.103.7.3045           |
|American Economic Review                     |2016-05-01      |10.1257/aer.p20161015            |When Do Capital Inflow Surges End in Tears?                                                                                                       |International Monetary Fund |https://doi.org/10.1257/aer.p20161015            |
|American Economic Review                     |2011-06-01      |10.1257/aer.101.4.1436           |The Inflation-Output Trade-Off with Downward Wage Rigidities                                                                                      |International Monetary Fund |https://doi.org/10.1257/aer.101.4.1436           |
|American Economic Review                     |2009-02-01      |10.1257/aer.99.1.528             |Democracy and Foreign Education                                                                                                                   |International Monetary Fund |https://doi.org/10.1257/aer.99.1.528             |
|American Economic Review                     |2015-03-01      |10.1257/aer.20110683             |Inequality, Leverage, and Crises                                                                                                                  |International Monetary Fund |https://doi.org/10.1257/aer.20110683             |
|American Economic Review                     |2005-08-01      |10.1257/0002828054825565         |Effective Exchange Rates and the Classical Gold Standard Adjustment                                                                               |International Monetary Fund |https://doi.org/10.1257/0002828054825565         |
|American Economic Review                     |2006-04-01      |10.1257/000282806777212170       |Modernizing China's Growth Paradigm                                                                                                               |International Monetary Fund |https://doi.org/10.1257/000282806777212170       |
|American Economic Review                     |2012-05-01      |10.1257/aer.102.3.219            |Flight Home, Flight Abroad, and International Credit Cycles                                                                                       |International Monetary Fund |https://doi.org/10.1257/aer.102.3.219            |
|American Economic Review                     |2009-04-01      |10.1257/aer.99.2.494             |Trade Liberalization and New Imported Inputs                                                                                                      |International Monetary Fund |https://doi.org/10.1257/aer.99.2.494             |
|American Economic Review                     |2008-04-01      |10.1257/aer.98.2.327             |The Drivers of Financial Globalization                                                                                                            |International Monetary Fund |https://doi.org/10.1257/aer.98.2.327             |
|American Economic Review                     |2018-09-01      |10.1257/aer.20140443             |International Reserves and Rollover Risk                                                                                                          |International Monetary Fund |https://doi.org/10.1257/aer.20140443             |
|American Economic Review                     |2005-02-01      |10.1257/0002828053828699         |Financial Reform: What Shakes It? What Shapes It?                                                                                                 |International Monetary Fund |https://doi.org/10.1257/0002828053828699         |
|American Economic Review                     |2008-05-01      |10.1257/aer.98.3.808             |Income and Democracy                                                                                                                              |International Monetary Fund |https://doi.org/10.1257/aer.98.3.808             |
|American Economic Review                     |2004-04-01      |10.1257/0002828041301740         |Policy Options in a Liquidity Trap                                                                                                                |International Monetary Fund |https://doi.org/10.1257/0002828041301740         |
|American Economic Review                     |2004-02-01      |10.1257/000282804322970797       |Pareto-Efficient International Taxation                                                                                                           |International Monetary Fund |https://doi.org/10.1257/000282804322970797       |
|American Economic Review                     |2016-05-01      |10.1257/aer.p20161012            |Capital Flows: Expansionary or Contractionary?                                                                                                    |International Monetary Fund |https://doi.org/10.1257/aer.p20161012            |
|American Economic Review                     |2006-04-01      |10.1257/000282806777211676       |Lessons from the Debt-Deflation Theory of Sudden Stops                                                                                            |International Monetary Fund |https://doi.org/10.1257/000282806777211676       |
|American Economic Review                     |2017-05-01      |10.1257/aer.p20171141            |Taxman's Dilemma: Coercion or Persuasion? Evidence from a Randomized Field Experiment in Ethiopia                                                 |International Monetary Fund |https://doi.org/10.1257/aer.p20171141            |
|American Economic Review                     |2002-02-01      |10.1257/000282802760015784       |Does Federalism Lead to Excessively High Taxes?                                                                                                   |International Monetary Fund |https://doi.org/10.1257/000282802760015784       |
|American Economic Review                     |2012-05-01      |10.1257/aer.102.3.225            |From Financial Crisis to Great Recession: The Role of Globalized Banks                                                                            |International Monetary Fund |https://doi.org/10.1257/aer.102.3.225            |
|American Economic Review                     |2003-04-01      |10.1257/000282803321946822       |Sovereign Debt Restructuring: Messy or Messier?                                                                                                   |International Monetary Fund |https://doi.org/10.1257/000282803321946822       |
|American Economic Review                     |2015-03-01      |10.1257/aer.20121546             |The Cyclicality of Sales, Regular and Effective Prices: Business Cycle and Policy Implications                                                    |International Monetary Fund |https://doi.org/10.1257/aer.20121546             |
|American Economic Review                     |2000-06-01      |10.1257/aer.90.3.649             |Political Influence and the Dynamic Consistency of Policy                                                                                         |International Monetary Fund |https://doi.org/10.1257/aer.90.3.649             |
|American Economic Review                     |2000-05-01      |10.1257/aer.90.2.243             |Restricting the Trash Trade                                                                                                                       |International Monetary Fund |https://doi.org/10.1257/aer.90.2.243             |
|American Economic Review                     |2006-02-01      |10.1257/000282806776157759       |Money in a Theory of Banking                                                                                                                      |International Monetary Fund |https://doi.org/10.1257/000282806776157759       |
|American Economic Review                     |2007-02-01      |10.1257/aer.97.1.474             |Credible Commitment to Optimal Escape from a Liquidity Trap: The Role of the Balance Sheet of an Independent Central Bank                         |International Monetary Fund |https://doi.org/10.1257/aer.97.1.474             |
|American Economic Review                     |2011-05-01      |10.1257/aer.101.3.308            |Vertical Linkages and the Collapse of Global Trade                                                                                                |International Monetary Fund |https://doi.org/10.1257/aer.101.3.308            |
|American Economic Review                     |2003-04-01      |10.1257/000282803321947173       |Monetary Policy Under Imperfect Capital Markets in a Small Open Economy                                                                           |International Monetary Fund |https://doi.org/10.1257/000282803321947173       |
|American Economic Review                     |2002-04-01      |10.1257/000282802320191697       |Asset-Market Effects of the Baby Boom and Social-Security Reform                                                                                  |International Monetary Fund |https://doi.org/10.1257/000282802320191697       |
|American Economic Review                     |2003-04-01      |10.1257/000282803321946840       |Is Aggregation a Problem for Sovereign Debt Restructuring?                                                                                        |International Monetary Fund |https://doi.org/10.1257/000282803321946840       |
|American Economic Review                     |2009-02-01      |10.1257/aer.99.1.472             |Diversity in the Workplace                                                                                                                        |International Monetary Fund |https://doi.org/10.1257/aer.99.1.472             |
|American Economic Review                     |2019-06-01      |10.1257/aer.20140193             |A Macroeconomic Model of Price Swings in the Housing Market                                                                                       |International Monetary Fund |https://doi.org/10.1257/aer.20140193             |
|The Quarterly Journal of Economics           |2019-02-01      |10.1093/qje/qjy026               |Forward and Spot Exchange Rates in a Multi-Currency World*                                                                                        |International Monetary Fund |https://doi.org/10.1093/qje/qjy026               |
|The Quarterly Journal of Economics           |2017-11-01      |10.1093/qje/qjx020               |The Benefits of Forced Experimentation: Striking Evidence from the London Underground Network*                                                    |International Monetary Fund |https://doi.org/10.1093/qje/qjx020               |
|The Review of Economic Studies               |2022-11-07      |10.1093/restud/rdac008           |Subjective Models of the Macroeconomy: Evidence From Experts and Representative Samples                                                           |International Monetary Fund |https://doi.org/10.1093/restud/rdac008           |
|The Review of Economic Studies               |2019-10-01      |10.1093/restud/rdy062            |Growth Through Inter-sectoral Knowledge Linkages                                                                                                  |International Monetary Fund |https://doi.org/10.1093/restud/rdy062            |
|Review of Economic Studies                   |NA              |10.1093/restud/rdad052           |Bilateral Trade Imbalances                                                                                                                        |International Monetary Fund |https://doi.org/10.1093/restud/rdad052           |
|The Review of Economic Studies               |2023-05-05      |10.1093/restud/rdac053           |Sentimental Business Cycles                                                                                                                       |International Monetary Fund |https://doi.org/10.1093/restud/rdac053           |
|The Review of Economic Studies               |2014-04-01      |10.1093/restud/rdt040            |Retracted: Growing up in a Recession                                                                                                              |International Monetary Fund |https://doi.org/10.1093/restud/rdt040            |
|The Economic Journal                         |2012-03-01      |10.1111/j.1468-0297.2011.02460.x |Growth Empirics without Parameters                                                                                                                |International Monetary Fund |https://doi.org/10.1111/j.1468-0297.2011.02460.x |
|The Economic Journal                         |2014-05         |10.1111/ecoj.12136               |Divorce Risk, Wages and Working Wives: A Quantitative Life-Cycle Analysis of Female Labour Force Participation                                    |International Monetary Fund |https://doi.org/10.1111/ecoj.12136               |
|The Economic Journal                         |2019-01-01      |10.1111/ecoj.12600               |Transmission of Quantitative Easing: The Role of Central Bank Reserves                                                                            |International Monetary Fund |https://doi.org/10.1111/ecoj.12600               |
|The Economic Journal                         |2022-06-17      |10.1093/ej/ueac010               |Financial Frictions and Firm Informality: A General Equilibrium Perspective                                                                       |International Monetary Fund |https://doi.org/10.1093/ej/ueac010               |
|The Economic Journal                         |2023-01-13      |10.1093/ej/ueac067               |Investor Sentiment, Sovereign Debt Mispricing, and Economic Outcomes                                                                              |International Monetary Fund |https://doi.org/10.1093/ej/ueac067               |
|The Economic Journal                         |2019-01-01      |10.1111/ecoj.12579               |Friedman Redux: External Adjustment and Exchange Rate Flexibility                                                                                 |International Monetary Fund |https://doi.org/10.1111/ecoj.12579               |
|The Economic Journal                         |2013-02-01      |10.1111/ecoj.12013               |Sovereign Risk, Fiscal Policy, and Macroeconomic Stability                                                                                        |International Monetary Fund |https://doi.org/10.1111/ecoj.12013               |
|The Economic Journal                         |2001-07-01      |10.1111/1468-0297.00651          |Bargaining Over EMU Vs. EMS: Why Might the ECB be the Twin Sister of the Bundesbank?                                                              |International Monetary Fund |https://doi.org/10.1111/1468-0297.00651          |
|The Economic Journal                         |NA              |10.1093/ej/uead023               |Tax Revenues in Low-Income Countries                                                                                                              |International Monetary Fund |https://doi.org/10.1093/ej/uead023               |
|The Economic Journal                         |2014-12         |10.1111/ecoj.12076               |Local Government Spending Multipliers and Financial Distress: Evidence from Japanese Prefectures                                                  |International Monetary Fund |https://doi.org/10.1111/ecoj.12076               |
|The Economic Journal                         |2017-09-01      |10.1111/ecoj.12360               |Actively Learning by Pricing: A Model of an Experimenting Seller                                                                                  |International Monetary Fund |https://doi.org/10.1111/ecoj.12360               |
|The Economic Journal                         |2008-03-01      |10.1111/j.1468-0297.2007.02129.x |Smooth it Like the ‘Joneses’? Estimating Peer‐Group Effects in Intertemporal Consumption Choice                                                   |International Monetary Fund |https://doi.org/10.1111/j.1468-0297.2007.02129.x |
|The Economic Journal                         |2001-06-01      |10.1111/1468-0297.00629          |Economic Developments in the West Bank and Gaza Since Oslo                                                                                        |International Monetary Fund |https://doi.org/10.1111/1468-0297.00629          |
|The Economic Journal                         |2012-06-01      |10.1111/j.1468-0297.2012.02508.x |Commodity Windfalls, Democracy and External Debt                                                                                                  |International Monetary Fund |https://doi.org/10.1111/j.1468-0297.2012.02508.x |
|The Economic Journal                         |2006-07-01      |10.1111/j.1468-0297.2006.01114.x |Catalysing Private Capital Flows: Do IMF Programmes Work as Commitment Devices?                                                                   |International Monetary Fund |https://doi.org/10.1111/j.1468-0297.2006.01114.x |
|The Economic Journal                         |2018-11-01      |10.1111/ecoj.12538               |Inflation Targeting, Fiscal Rules and the Policy Mix: Cross‐effects and Interactions                                                              |International Monetary Fund |https://doi.org/10.1111/ecoj.12538               |
|The Economic Journal                         |2004-10-01      |10.1111/j.1468-0297.2004.00249.x |Does Insider Trading Raise Market Volatility?                                                                                                     |International Monetary Fund |https://doi.org/10.1111/j.1468-0297.2004.00249.x |
|The Economic Journal                         |2004-04-01      |10.1111/j.1468-0297.2004.00208.x |Do Collective Action Clauses Raise Borrowing Costs?                                                                                               |International Monetary Fund |https://doi.org/10.1111/j.1468-0297.2004.00208.x |
|The Economic Journal                         |2000-01-01      |10.1111/1468-0297.00501          |From Suez to Tequila: The IMF As Crisis Manager                                                                                                   |International Monetary Fund |https://doi.org/10.1111/1468-0297.00501          |
|The Economic Journal                         |2000-01-01      |10.1111/1468-0297.00490          |Tax Reform and Progressivity                                                                                                                      |International Monetary Fund |https://doi.org/10.1111/1468-0297.00490          |
|The Economic Journal                         |2017-06-01      |10.1111/ecoj.12353               |What Fuels the Boom Drives the Bust: Regulation and The Mortgage Crisis                                                                           |International Monetary Fund |https://doi.org/10.1111/ecoj.12353               |
|The Economic Journal                         |2018-06-01      |10.1111/ecoj.12473               |The Ponds Dilemma                                                                                                                                 |International Monetary Fund |https://doi.org/10.1111/ecoj.12473               |
|The Economic Journal                         |2015-09         |10.1111/ecoj.12169               |Demand for Slant: How Abstention Shapes Voters' Choice of News Media                                                                              |International Monetary Fund |https://doi.org/10.1111/ecoj.12169               |
|The Economic Journal                         |2018-03-01      |10.1111/ecoj.12452               |Monetary and Macroprudential Policies in a Leveraged Economy                                                                                      |International Monetary Fund |https://doi.org/10.1111/ecoj.12452               |
|The Economic Journal                         |2013-02-01      |10.1111/ecoj.12010               |Fiscal Fatigue, Fiscal Space and Debt Sustainability in Advanced Economies                                                                        |International Monetary Fund |https://doi.org/10.1111/ecoj.12010               |
|Journal of Political Economy                 |2008-04         |10.1086/588200                   |Consumption Strikes Back? Measuring Long‐Run Risk                                                                                                 |NA                          |https://doi.org/10.1086/588200                   |
|Journal of Political Economy                 |2001-10         |10.1086/322831                   |Globalization and the Rate of Technological Progress: What Track and Field Records Show                                                           |NA                          |https://doi.org/10.1086/322831                   |
|Journal of Political Economy                 |2016-10         |10.1086/688081                   |Debt Dilution and Sovereign Default Risk                                                                                                          |NA                          |https://doi.org/10.1086/688081                   |

## System info


```r
Sys.info()
```

```
##                                                        sysname 
##                                                        "Linux" 
##                                                        release 
##                                 "5.14.21-150400.24.63-default" 
##                                                        version 
## "#1 SMP PREEMPT_DYNAMIC Tue May 2 15:49:04 UTC 2023 (fd0cc4f)" 
##                                                       nodename 
##                                                 "b9e5e4b91d45" 
##                                                        machine 
##                                                       "x86_64" 
##                                                          login 
##                                                      "unknown" 
##                                                           user 
##                                                      "rstudio" 
##                                                 effective_user 
##                                                      "rstudio"
```
