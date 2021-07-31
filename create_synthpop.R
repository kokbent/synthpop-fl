rm(list = ls())

library(sf)
library(raster)
library(data.table)
library(tidyverse)
library(stringr)
library(ipumsr)
library(doSNOW)
library(abmgravity)
library(dbplyr)
library(RSQLite)

options(datatable.na.strings=c("", "NA")) # Making sure data.table properly reads NA

lcfg <- jsonlite::read_json("synth/local_config.json", simplifyVector = T)
lcfg$vers <- "3.1"

cat(paste0("Creating dataset with name of: ", lcfg$target_county, "\n"))

#### Build synthetic population sqlite using files in data folder

dir.create("synth/tmp", showWarnings = F)

print("CHECKPOINT 1: IPUMS")
source("synth/code/extract_ipums.R")
print("CHECKPOINT 2: Nursing Homes")
source("synth/code/nh_dat_int.R")
print("CHECKPOINT 3: Households")
source("synth/code/allocate_hh.R")
print("CHECKPOINT 4: Schools")
source("synth/code/sch_dat_int.R")
print("CHECKPOINT 5: Health Facilities")
source("synth/code/hf_dat_int.R")
print("CHECKPOINT 6: Workplace sizes")
if(!file.exists("synth/data/reusable/naics_emp_wpar.csv")) source("synth/code/est_gpd_per_naics.R")
source("synth/code/wp_size_w_schnh.R")
print("CHECKPOINT 7: Workers")
source("synth/code/assign_worker.R")
print("CHECKPOINT 8: Household Networks")
source("synth/code/build_hh_network.R")
if (lcfg$extracurricular != 0) {
  print("CHECKPOINT 9: Extracurricular")
  source("synth/code/assign_extracurricular.R")
}
# source("cty-sim/code/build_neighbour_network.R")
print("CHECKPOINT 10: Comorbidity")
source("synth/code/assign_comorbidity.R")

rm(list=ls()[ls() != "lcfg"])
source("synth/code/export_gen_dat.R")
