rm(list=ls()[ls() != "lcfg"])

#### Integrate School data into the population
#### Data import ----
## PERS
gen_pers <- fread("synth/tmp/person_details.csv")
gen_hh <- fread("synth/tmp/hh_coords.csv")

## HF
hf_dat <- fread(lcfg$path_hf)
hf_dat <- hf_dat %>%
  select(X, Y, AHCA_number, Name, Licensed_Beds) %>%
  filter(!is.na(X))

#### Assign households to HF ----
## HF coordinates
hf_dat$HFID <- 1:nrow(hf_dat)
hf_coords <- hf_dat[,c("X", "Y")] %>%
  as.matrix

## HH coordinates
hh_coords <- gen_hh[,c("x", "y")] %>%
  as.matrix

assign_mat <- assign_by_gravity(pts = hh_coords,
                                locs = hf_coords, 
                                weights = hf_dat$Licensed_Beds, 
                                num_loc = 3, 
                                seed = 4326 + 8)

gen_hh$HFID <- NA
gen_hh$HFID[assign_mat[,1]] <- assign_mat[,2]

#### Assign workers to HF (8 workers per 1 licensed bed) ----
hf_dat$WORKER <- hf_dat$Licensed_Beds * 8

#### Export ----
fwrite(hf_dat, "synth/tmp/hf.csv")
fwrite(gen_hh, "synth/tmp/hh_coords.csv")
