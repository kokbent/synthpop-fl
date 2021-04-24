## Take statewide dataset and filter to specific county
## Then supply the dataset to synth to generate synthpop
## Currently support state or one single county only
library(sf)
library(raster)
library(data.table)
library(tidyverse)
library(stringr)
source("utils.R")

options(datatable.na.strings=c("", "NA")) # Making sure data.table properly reads NA

#### Getting args from Rscript, and displaying basics
args <- commandArgs(trailingOnly=TRUE)
if(length(args) == 1) {
  cfg_file <- args
} else {
  cfg_file <- "config.json"
  cat("No config file supplied. Using default config.json.\n")
}

cat(paste0("Building foundation dataset based on config file from ", cfg_file, "\n"))

cfg <- jsonlite::read_json(cfg_file)
cfg <- make_full_path(cfg)
essential_col <- jsonlite::read_json("synth/data_check.json", simplifyVector = T)

if (cfg$target_county %in% c("Florida", "All")) {
  statewide_mode <- T
  cat("Creating statewide dataset...\n")
} else {
  statewide_mode <- F
  cat("Creating dataset for", cfg$target_county, "county...\n")
}

synth_paths <- list() # Collect "localized" paths
if (is.null(cfg$output_name)) {
  synth_paths$target_county <- ifelse(cfg$target_county == "All", "florida", 
                                      tolower(cfg$target_county))
} else {
  synth_paths$target_county <- cfg$output_name
}

tmp_f <- tempfile(tmpdir = ".")
quiet(dir.create("synth/data"))
lof <- list.files("synth/data", full.names = T)
lof <- lof[!str_detect(lof, "reusable")]
quiet(file.remove(lof))

## Useful function
load_check <- function (item, type = "table") load_and_check(item, cfg, essential_col, type)

#### Generate Dataset
## Starts with looking for the correct FIPS
cnt <- load_check("county_shape", "shape")
cnt <- st_set_geometry(cnt, NULL)
fwrite(cnt %>% select(TIGERNAME, FIPS), "synth/data/cnt.csv")
if (statewide_mode) {
  fips <- as.character(cnt[, "FIPS"]) %>% sort
} else {
  fips <- as.character(cnt[cnt$TIGERNAME == cfg$target_county, "FIPS"])
}

synth_paths$path_county_shape <- "synth/data/cnt.csv"

#### IPUMS ----
if (!require("ipumsr")) stop("Reading IPUMS data into R requires the ipumsr package. It can be installed using the following command: install.packages('ipumsr')")

## Load original
data <- load_check("ipums", "ipums") # .dat file needs to be in same folder as xml
data$COUNTYFIP1 <- str_pad(data$COUNTYFIP,
                           width = 3,
                           side = "left",
                           pad = "0")

## Identify the lines that are within target county
if (cfg$use_statewide_census != 1) {
  ind <- which(data$COUNTYFIP1 == fips)  
} else {
  ind <- 1:nrow(data)
}

dat_in <- read_lines(cfg$path_ipums_dat)
dat_out <- dat_in[ind]

## Write data
dat_fn <- basename(cfg$path_ipums_dat)
xml_fn <- basename(cfg$path_ipums_xml)
synth_paths$path_ipums_xml <- file.path("synth/data", xml_fn)
synth_paths$path_ipums_dat <- file.path("synth/data", dat_fn)

write_lines(dat_out, synth_paths$path_ipums_dat)
quiet(file.copy(cfg$path_ipums_xml, "synth/data/", overwrite = T))
cat("IPUMS data and xml files created in synth/data/\n")

## Test if it works
ddi <- read_ipums_ddi(synth_paths$path_ipums_xml)
quiet(data <- read_ipums_micro(ddi))


#### Census Tract Shape ----
cenacs <- load_check("cenblock_shape", "shape")

ct_to_puma_fn <- basename(cfg$path_centract_puma)
quiet(file.copy(cfg$path_centract_puma, "synth/data", overwrite = T))
cat("Census tract to PUMA lookup created in synth/data/\n")

synth_paths$path_centract_puma <- file.path("synth/data", ct_to_puma_fn)
ct_to_puma <- load_check("centract_puma", "table")
ct_to_puma <- ct_to_puma %>%
  filter(STATEFP == "12")

quiet(cenacs <- left_join(cenacs,
                          ct_to_puma,
                          by = c("STATEFP10" = "STATEFP", "COUNTYFP10" = "COUNTYFP", "TRACTCE10" = "TRACTCE")))

cond <- cenacs$COUNTYFP10 == fips
cenacs1 <- cenacs[cond,]
cenacs1 <- cenacs1 %>% select(-PUMA5CE, -SHAPE_AREA, -SHAPE_LEN, -ALAND, -AWATER)
cenacs_fn <- basename(cfg$path_cenblock_shape)
cenacs_fn1 <- str_split(cenacs_fn, "[.]")[[1]][1]
quiet(st_write(cenacs1, dsn = "synth/data", layer = cenacs_fn1,
               driver = "ESRI Shapefile", delete_layer = TRUE))
cat("Census tract shape files created in synth/data/\n")

synth_paths$path_cenblock_shape <- file.path("synth/data", cenacs_fn)


## Test if it works
quiet(cenacs <- shapefile(synth_paths$path_cenblock_shape))

#### Population raster ----
fl_hh <- raster(cfg$path_hhdens_raster)

cenacs_wgs <- spTransform(cenacs, CRS("+init=epsg:4326"))
cenacs_wgs@data <- cenacs_wgs@data %>%
  select(STATEFP10, COUNTYFP10, TRACTCE10, GEOID10)
fl_hh <- crop(fl_hh, cenacs_wgs)
fl_hh <- mask(fl_hh, cenacs_wgs)

hh_fn <- basename(cfg$path_hhdens_raster)
synth_paths$path_hhdens_raster <- file.path("synth/data", hh_fn)

writeRaster(fl_hh, synth_paths$path_hhdens_raster, overwrite=T)
cat("Population density raster file created in synth/data/\n")

## Test if it works
fl_hh <- raster(synth_paths$path_hhdens_raster)
# plot(fl_hh)
# plot(cenacs_wgs, add=T)

#### Nursing home ----
nh_raw <- load_check("nh")
nh_sp <- SpatialPoints(nh_raw[,c("X", "Y")], CRS("+init=epsg:4326"))
cond <- !is.na(over(nh_sp, cenacs_wgs)$STATEFP10)
nh <- nh_raw[cond,]

nh_fn <- basename(cfg$path_nh)
synth_paths$path_nh <- file.path("synth/data", nh_fn)

data.table::fwrite(nh, synth_paths$path_nh)
cat("Nursing home table created in synth/data/\n")

## Test
quiet(nh <- read_csv(synth_paths$path_nh, col_types = cols()))

#### Schools ----
gc_sch <- load_check("schools_shape", "shape")

if (!statewide_mode) {
  gc_sch <- gc_sch[gc_sch$COUNTY == toupper(cfg$target_county),]
  if (nrow(gc_sch) == 0) stop("Something is wrong while subsetting school data. Possibly because mismatched county name.")
}

sch_fn <- basename(cfg$path_schools_shape)
sch_fn1 <- str_split(sch_fn, "[.]")[[1]][1]
synth_paths$path_schools_shape <- file.path("synth/data", sch_fn)

quiet(st_write(gc_sch, dsn = "synth/data", layer = sch_fn1,
               driver = "ESRI Shapefile", delete_layer = TRUE))
cat("Schools data table created in synth/data/\n")

## College and University category has additional file
cu <- load_check("col_uni_size")

if (!statewide_mode) {
  cu <- cu %>%
    filter(COUNTY == toupper(cfg$target_county))
  if (nrow(cu) == 0) warn("No college or university found in this county? Check if it is due to mismatched county name.")
}

cu_fn <- basename(cfg$path_col_uni_size)
synth_paths$path_col_uni_size <- file.path("synth/data", cu_fn)

data.table::fwrite(cu, synth_paths$path_col_uni_size)
cat("College/University data table created in synth/data/\n")

#### Workplace Area Characteristics ----
wac <- load_check("wac_shape", "shape")
wac <- wac[wac$COUNTYFP10 == fips,]
wac <- wac %>% dplyr::select(-SHAPE_AREA, -SHAPE_LEN)

wac_fn <- basename(cfg$path_wac_shape)
wac_fn1 <- str_split(wac_fn, "[.]")[[1]][1]
synth_paths$path_wac_shape <- file.path("synth/data", wac_fn)

quiet(st_write(wac, dsn = "synth/data", layer = wac_fn1,
               driver = "ESRI Shapefile", delete_layer = TRUE))
cat("Work area characteristics shape files created in synth/data/\n")

## Test if it works
quiet(wac <- st_read(synth_paths$path_wac_shape))

#### NAICS Workplace dataset ----
naics_wp_fn <- basename(cfg$path_naics_size)
quiet(file.copy(cfg$path_naics_size, "synth/data/", overwrite = T))
synth_paths$path_naics_size <- file.path("synth/data", naics_wp_fn)

#### NAICS Number Lookup (2017 vs 2012) ----
naics_lkup_fn <- basename(cfg$path_naics_lookup)
quiet(file.copy(cfg$path_naics_lookup, "synth/data/", overwrite = T))
synth_paths$path_naics_lookup <- file.path("synth/data", naics_lkup_fn)

naics_wp <- load_check("naics_size")
naics_lkup <- load_check("naics_lookup")
cat("NAICS lookup and size data created in synth/data/\n")

#### NCD Workplace data ----
wp_coords <- load_check("workplace")

wp_sp <- wp_coords[,c("x", "y")] %>%
  as.data.frame %>% 
  as.matrix %>%
  SpatialPoints(proj4string = CRS("+init=epsg:4326"))
tmp <- over(wp_sp, cenacs_wgs)
cond <- !is.na(tmp$STATEFP10)
wp_coords <- wp_coords[cond,]

wp_fn <- basename(cfg$path_workplace)
synth_paths$path_workplace <- file.path("synth/data", wp_fn)

data.table::fwrite(wp_coords, synth_paths$path_workplace)
cat("Workplace data created in synth/data/\n")

#### HF data ----
hf <- load_check("hf")
if (!statewide_mode) {
  hf <- hf %>%
    filter(County == cfg$target_county)
  if (nrow(hf) == 0) warn("No HF found in this county? Check if it is due to mismatched county name.")
}

hf_fn <- basename(cfg$path_hf)
synth_paths$path_hf <- file.path("synth/data", hf_fn)

data.table::fwrite(hf, synth_paths$path_hf)
cat("Hospital data created in synth/data/\n")

#### BRFSS ----
brfss_fn <- basename(cfg$path_brfss)
synth_paths$path_brfss <- file.path("synth/data", brfss_fn)

quiet(file.copy(cfg$path_brfss, synth_paths$path_brfss, overwrite = T))
brfss <- load_check("brfss")
cat("BRFSS data created in synth/data/\n")

#### Passing additional parameters - Extracurricular ----
synth_paths$extracurricular <- cfg$extracurricular
if (cfg$extracurricular != 0) {
  patterns_fn <- basename(cfg$path_patterns)
  synth_paths$path_patterns <- file.path("synth/data", patterns_fn)
  
  quiet(file.copy(cfg$path_patterns, synth_paths$path_patterns, overwrite = T))
  patterns <- load_check("patterns")
  cat("Extracurricular mode on, mobility pattern data created in synth/data\n")
}

#### Passing additional parameters 2  ----
synth_paths$use_statewide_census <- cfg$use_statewide_census

#### Export synth_path as JSON
quiet(jsonlite::write_json(synth_paths, "synth/local_config.json"))
cat("Localized configuration written to synth/\n")
cat("Datasets required to create specified synthetic population are now ready.\n")
cat("To generate the synthetic population, run 'Rscript create_synthpop.R'\n")