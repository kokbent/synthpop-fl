rm(list=ls()[ls() != "lcfg"])

#### Nursing home and assisted living facilities

#### Setting up ----
cenacs <- st_read(lcfg$path_cenblock_shape, stringsAsFactors = F)
nh <- data.table::fread(lcfg$path_nh)

ct_to_puma <- data.table::fread(lcfg$path_centract_puma, keepLeadingZeros = T)
ct_to_puma <- ct_to_puma %>%
  filter(STATEFP == "12") # FL is 12

cenacs <- cenacs %>%
  left_join(ct_to_puma[,c("COUNTYFP", "TRACTCE", "PUMA5CE")],
            by = c("COUNTYFP10" = "COUNTYFP" ,"TRACTCE10" = "TRACTCE"))


#### Find out the PUMA of each NH ----
nh_sf <- st_as_sf(nh, coords = c("X", "Y")) %>%
  st_set_crs(4326) %>%
  st_transform(st_crs(cenacs))
nh_puma <- st_join(nh_sf, cenacs %>% select(PUMA5CE))

nh$PUMA5CE <- nh_puma$PUMA5CE
nh$NHID <- 1:nrow(nh)
nh1 <- nh %>%
  dplyr::select(NHID, X, Y, PUMA5CE, REP_POP = POPULATION)


#### Export ----
data.table::fwrite(nh1, "synth/tmp/nh.csv")
