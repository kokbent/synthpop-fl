rm(list=ls()[ls() != "lcfg"])

#### Assign Extracurricular places

#### Load Data ----
wp <- fread("synth/tmp/wp2.csv")
pers <- fread("synth/tmp/pers_w_wid.csv")
hh <- fread("synth/tmp/hh_coords.csv")
patterns <- fread(lcfg$path_pattern, keepLeadingZeros = T)
patterns$PUMA5CE <- str_pad(patterns$PUMA5CE, width = 5, side = "left", pad = "0")

cenacs <- st_read(lcfg$path_cenblock_shape)
ct_to_puma <- fread(lcfg$path_centract_puma, keepLeadingZeros = T)
cenacs <- cenacs %>%
  left_join(ct_to_puma, 
            by = c("STATEFP10" = "STATEFP", "COUNTYFP10" = "COUNTYFP", 
                   "TRACTCE10" = "TRACTCE"))
cenacs <- cenacs %>%
  st_transform(4326)

#### Find out relevant naics
naics_lookup <- patterns %>%
  select(grp, naics_code, top_category, sub_category) %>%
  distinct() %>%
  arrange(grp, top_category, sub_category)

#### Filter extracurricular locations and assign PUMA to them
set.seed(4326 + 11)
loc_extracurr <- wp %>%
  filter(NAICS %in% naics_lookup$naics_code)

loc_extracurr_sf <- st_as_sf(loc_extracurr, coords = c("x", "y"), crs = 4326)
loc_extracurr_sf <- st_join(loc_extracurr_sf, cenacs %>% select(PUMA5CE))
loc_extracurr$PUMA <- loc_extracurr_sf$PUMA5CE
loc_extracurr <- loc_extracurr %>%
  left_join(naics_lookup %>% select(TRANSMISSION = grp, NAICS = naics_code))

df <- data.frame()
for (puma in unique(loc_extracurr$PUMA)) {
  loc_subset <- loc_extracurr %>%
    filter(PUMA == puma)
  loc_subset_H <- loc_subset %>%
    filter(TRANSMISSION == "H")
  loc_subset_L <- loc_subset %>%
    filter(TRANSMISSION == "L")
  
  patterns_subset <- patterns %>%
    filter(PUMA5CE == puma)
  loc_subset_H$VISIT <- sample(patterns_subset$raw_visit_counts[patterns_subset$grp == "H"],
                               size = nrow(loc_subset_H),
                               replace = T)
  loc_subset_L$VISIT <- sample(patterns_subset$raw_visit_counts[patterns_subset$grp == "L"],
                               size = nrow(loc_subset_L),
                               replace = T)
  df <- bind_rows(df, loc_subset_H, loc_subset_L)
}

loc_extracurr <- df

#### Add coordinates to person file
pers <- pers %>%
  left_join(hh %>% select(HID, x, y))
pers <- pers %>%
  select(PID, HID, WID2, SID, NHID, x, y)
head(pers)

#### Assign time, potentially VERY LONG ----
loc_mat <- loc_extracurr[,c("x", "y")] %>% as.matrix
weights <- loc_extracurr$VISIT
weights <- ceiling(weights)
pts_mat <- pers[,c("x", "y")] %>% as.matrix

## Choose 6 instead of 5 (1 backup for in case overlapped with assigned workplace)
system.time(
  assign_mat <- assign_by_gravity2(pts = pts_mat, 
                                   locs = loc_mat, 
                                   weights = weights,
                                   num_loc_choose = 6, 
                                   num_loc_candidate = 1000, 
                                   seed = 4326 + 16, 
                                   steps = 1)
)

pid <- pers$PID[assign_mat[,1]]
wid_main <- pers$WID2[assign_mat[,1]]

ec_network_df <- data.frame(PID = pid,
                            WID_MAIN = wid_main)
ec_network_df[,paste0("WID_", 1:6)] <- NA
for (i in 1:6) {
  ec_network_df[,paste0("WID_", i)] <- loc_extracurr$WID2[assign_mat[,i+1]]
}


#### Manipulation of the extracurricular network
## Check if overlapped with assigned workplace, if yes, swap it out
for (i in 1:5) {
  cond <- ec_network_df$WID_MAIN == ec_network_df[,paste0("WID_", i)]
  ind <- which(cond)
  ec_network_df[ind,paste0("WID_", i:5)] <- ec_network_df[ind,paste0("WID_", (i+1):6)]
}

## Check if there's still overlap
tmp <- apply(ec_network_df[,2:7], 1, function (x) any(x[1] == x[2:6]))
summary(tmp)

## Drop sixth column
ec_network_df <- ec_network_df %>%
  select(-paste0("WID_", 6))
ec_network_df <- ec_network_df %>%
  select(-WID_MAIN)

ec_network_df <- ec_network_df %>%
  arrange(PID)

## Annotate WP
wp <- wp %>%
  left_join(naics_lookup %>% select(TRANSMISSION = grp, NAICS = naics_code))

## Export
fwrite(ec_network_df, "synth/tmp/extracurricular.csv")
fwrite(wp, "synth/tmp/wp2.csv")
