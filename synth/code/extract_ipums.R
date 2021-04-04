rm(list=ls()[ls() != "lcfg"])

#### Extract IPUMS .dat file and store it into RDS file

#### Using ipumsr to extract IPUMS data ----
ddi <- read_ipums_ddi(lcfg$path_ipums_xml)
data <- read_ipums_micro(ddi)

data1 <- data[,c("YEAR", "SAMPLE", "SERIAL", "HHWT", "COUNTYFIP", "PUMA", "PERNUM", "PERWT", 
                 "SEX", "AGE", "SCHOOL", "EMPSTAT", "EMPSTATD", "PWSTATE2", "PWCOUNTY", 
                 "PWPUMA00", "TRANWORK", "TRANTIME", "GQ")]
data1$PUMA <- as.numeric(data1$PUMA)
head(data1)

tapply(data1$PERWT, data1$COUNTYFIP, sum)
length(tapply(data1$PERWT, data1$COUNTYFIP, sum))

#### Export ----
readr::write_rds(data1, "synth/data/ipums.rds")
