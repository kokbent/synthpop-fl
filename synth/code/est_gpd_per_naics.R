rm(list=ls()[ls() != "lcfg"])

#### Estimate parameter for Generalized Pareto Distribution based on national data
library(tidyverse)
source("synth/code/target_func.R")

#### Loading & Manipulating data ----
## National NAICS workplace size
naics_emp <- read_csv(lcfg$path_naics_size) %>%
  select(-`Uncoded records`, -`Grand Total`)

# Set NAICS of Grand total to 999999 so uncoded workplaces use overall params
naics_emp$`NAICS 1 Code`[nrow(naics_emp)] <- 999999 

# Set cells with NA to 0
naics_emp[,3:ncol(naics_emp)] <- apply(naics_emp[,3:ncol(naics_emp)], 2, 
                                       function (x) ifelse(is.na(x), 0, x))
naics_emp <- as.data.frame(naics_emp)

#### Estimate MLE for GPD parameters ----
params <- matrix(NA, nrow(naics_emp), 2)
pb <- txtProgressBar(max = nrow(naics_emp), style = 3)
for (i in 1:nrow(naics_emp)) {
  setTxtProgressBar(pb, i)
  y <- naics_emp[i,3:ncol(naics_emp)] %>% as.matrix
  lgpd_target <- lgpd_target_(y)
  param <- optim(c(1, 1), lgpd_target)
  params[i,] <- param$par
}

colSums(is.na(params))
colMeans(params > 1) 
colnames(params) <- c("s", "xi")
naics_emp1 <- cbind(naics_emp, as.data.frame(params))

# Large portion of the sectors has no GPD without finite mean
# and even more without finite variance. Implication on drawing good
# quality numbers. Future problems to address...
dir.create("synth/data/reusable")
write_csv(naics_emp1, "synth/data/reusable/naics_emp_wpar.csv")
lcfg$path_wpsize_par <- "synth/data/reusable/naics_emp_wpar.csv"
