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

source("synth/code/extract_ipums.R")
source("synth/code/nh_dat_int.R")
source("synth/code/allocate_hh.R")
source("synth/code/sch_dat_int.R")
source("synth/code/hf_dat_int.R")
if(!file.exists("synth/data/reusable/naics_emp_wpar.csv")) source("synth/code/est_gpd_per_naics.R")
source("synth/code/wp_size_w_schnh.R")
source("synth/code/assign_worker.R")
source("synth/code/build_hh_network.R")
if (lcfg$extracurricular != 0) {
  source("synth/code/assign_extracurricular.R")
}
# source("cty-sim/code/build_neighbour_network.R")
source("synth/code/assign_comorbidity.R")

rm(list=ls()[ls() != "lcfg"])
source("synth/code/export_gen_dat.R")
