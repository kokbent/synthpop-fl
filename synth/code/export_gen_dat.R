#### Post processing of data
source("utils.R")

#### Data import
wp <- fread("synth/tmp/wp2.csv")
head(wp)
colnames(wp) <- tolower(colnames(wp))

hh <- fread("synth/tmp/hh_coords.csv")
head(hh)
colnames(hh) <- tolower(colnames(hh))

nh <- fread("synth/tmp/nh.csv")
head(nh)
colnames(nh) <- tolower(colnames(nh))
nh <- nh %>%
  select(nhid, pop, rep_pop) %>%
  left_join(wp %>% filter(type == "n"),
            by = c("nhid" = "serial")) %>%
  select(nhid, wid2, x, y, pop, worker, rep_pop)

sch <- fread("synth/tmp/sch.csv")
head(sch)
colnames(sch) <- tolower(colnames(sch))
sch <- sch %>%
  select(sid, student) %>%
  left_join(wp %>% filter(type == "s"),
            by = c("sid" = "serial")) %>%
  select(sid, x, y, student, worker, wid2)

hf <- fread("synth/tmp/hf.csv")
head(hf)
colnames(hf) <- tolower(colnames(hf))
hf <- hf %>%
  select(hfid, licensed_beds, ahca_number) %>%
  left_join(wp %>% filter(type == "hf"),
            by = c("hfid" = "serial")) %>%
  select(hfid, x, y, licensed_beds, ahca_number, worker, wid2)

pers <- fread("synth/tmp/pers_w_wid.csv")
head(pers)
colnames(pers) <- tolower(colnames(pers))

#### Build big location table
## Remove households in NH (for location file)
pers_nh <- pers %>%
  filter(!is.na(nhid))
hh_nonnh <- hh %>%
  filter(!hid %in% pers_nh$hid)

## Bind WP with HH_NONNH (WP already contains SCH, NH and HF)
table(wp$type)
loc <- wp %>%
  select(wid2, x, y, type)
loc <- bind_rows(loc, hh_nonnh %>% mutate(type = "h") %>% select(hid, x, y, type))
table(loc$type)

loc$locid <- 1:nrow(loc)

# LOC acts as the "Master Table" here; keeping WID2 for now
table(is.na(loc$wid2))

#### Table for each location type; connect them with LOC keep original ID for reference
## SCH
sch <- sch %>%
  left_join(loc %>% 
              filter(type == "s") %>%
              select(wid2, locid))
sch_db <- sch %>%
  select(locid, pop = student, worker, sid) %>%
  mutate(essential = "n")

## NH
nh <- nh %>%
  left_join(loc %>% 
              filter(type == "n") %>%
              select(wid2, locid))
nh_db <- nh %>%
  select(locid, pop, worker, nhid) %>%
  mutate(essential = "y")

## HF
hf <- hf %>%
  left_join(loc %>% 
              filter(type == "hf") %>%
              select(wid2, locid))

## WP (exclude SCH & NH & HF)
wp <- wp %>%
  filter(type == "w") %>%
  left_join(loc %>% 
              filter(type == "w") %>%
              select(wid2, locid))

addtl_col <- ifelse(lcfg$extracurricular==0, "dummy", "transmission")
wp_db <- wp %>%
  select(locid, wid2, worker, naics, essential = ess_class, contains(addtl_col)) %>%
  mutate(essential = case_when(
    is.na(essential) ~ "n",
    essential == "" ~ "n",
    essential == "Essential" ~ "y",
    essential == "Essential*" ~ "y",
    essential == "Nonessential" ~ "n"
  ))

## HH
#* Nursing Home part
pers_nh <- pers_nh %>%
  left_join(nh_db %>% select(nhid, locid)) %>%
  left_join(hh %>% select(hid, serial, hfid, countyfp10))
hh_nh <- pers_nh %>%
  select(locid, nhid, hid, serial, hfid, countyfp10) %>%
  group_by(hid) %>%
  mutate(pop = n(),
         nh = "y") %>%
  ungroup

# In original assignment, HH inside an NH can have different HF
# Need to reconcile that by "majority vote"
hh_nh1 <- hh_nh %>%
  group_by(nhid) %>%
  count(hfid) %>%
  mutate(maxn = max(n)) %>%
  filter(n == maxn) %>% # Pick majority
  sample_n(1) # Break tie by sampling

hh_nh <- hh_nh %>% select(-hfid) %>%
  left_join(hh_nh1 %>% select(nhid, hfid))

# Make sure NH_DB captures the HF information
nh_db <- nh_db %>%
  left_join(hh_nh1 %>% select(nhid, hfid))

#* Non-nursing home part
hh_nonnh <- hh_nonnh %>%
  left_join(pers %>%
              group_by(hid) %>%
              summarise(pop = n()))
hh_nonnh <- hh_nonnh %>%
  left_join(loc %>% 
              filter(type == "h") %>%
              select(hid, locid)) %>%
  mutate(nh = "n")

hh_db <- bind_rows(hh_nh, hh_nonnh %>% select(locid, hid, serial, countyfp10, pop, nh, hfid, compliance)) %>%
  rename(ipums_serial = serial)

mean(hf$hfid == 1:nrow(hf)) # HFID is just row numbers
hh_db$hf_locid <- hf$locid[hh_db$hfid]
hh_db <- hh_db %>%
  select(-hfid)

nh_db$hf_locid <- hf$locid[nh_db$hfid]
nh_db <- nh_db %>%
  select(-hfid)

## PERS
pers_db <- pers %>%
  select(pid, hid, sex, age, school, undlycond, empstatd, pwstate2, pwpuma00, gq)

#### MOVEMENT
## STUDY
study_db <- pers %>%
  select(pid, sid) %>%
  filter(!is.na(sid))
study_db <- study_db %>% left_join(sch_db %>% select(sid, locid)) %>%
  select(pid, locid) %>%
  mutate(type = "s")

## WORK
work_db <- pers %>%
  select(pid, wid2) %>%
  filter(!is.na(wid2)) %>%
  left_join(loc %>% select(wid2, locid)) %>%
  select(pid, locid) %>%
  mutate(type = "w")

## Combined movement
movement_db <- bind_rows(study_db, work_db)
rm(study_db)
rm(work_db)

#### RESIDENCE
## RESIDE_NH
reside_nh_db <- pers_nh %>%
  select(pid, locid) %>%
  mutate(type = "n")

## RESIDE_HH
reside_hh_db <- pers_nh %>%
  select(pid, locid) %>%
  mutate(type = "n")

reside_hh_db <- inner_join(pers %>% filter(is.na(nhid)), 
                           hh_db %>% select(locid, hid)) %>%
  select(pid, locid) %>%
  mutate(type = "h")

## Combine Reside
reside_db <- bind_rows(reside_nh_db, reside_hh_db)
rm(reside_nh_db)
rm(reside_hh_db)

#### Build DB

## Find cty name
# fips <- unique(hh_db$countyfp10)
# cnt <- fread("synth/data/cnt.csv")
# cnt_name <- cnt[cnt$FIPS == fips,"TIGERNAME"] %>% as.matrix %>% as.vector
# cnt_name <- str_replace_all(cnt_name, " ", "-")
# cnt_name <- tolower(cnt_name)

dirname <- paste0("synth/sim_pop-", lcfg$target_county, "-", lcfg$vers)
sqlitename <- paste0(dirname, paste0("/sim_pop-", lcfg$target_county, 
                                     "-", lcfg$vers, ".sqlite"))
dir.create(dirname)
mydb <- dbConnect(RSQLite::SQLite(), sqlitename)
dbWriteTable(mydb, "loc", loc)
dbWriteTable(mydb, "pers", pers_db)
dbWriteTable(mydb, "hh", hh_db)
dbWriteTable(mydb, "sch", sch_db)
dbWriteTable(mydb, "nh", nh_db)
dbWriteTable(mydb, "wp", wp_db)
dbWriteTable(mydb, "movement", movement_db)
dbWriteTable(mydb, "reside", reside_db)

#### Incorporate HH network and Extracurricular data
## Remove stuff from RAM to reduce stress...
rm(pers, pers_nh)
rm(hh, hh_nh, hh_nonnh)
rm(sch)
rm(nh)
rm(wp)
gc()

## HH Network
hh_edge <- fread("synth/tmp/hh_network.csv")
hh_loc <- loc %>%
  filter(type == "h") %>%
  select(locid, hid)

hh_edge1 <- hh_edge %>%
  select(HID1) %>%
  left_join(hh_loc, by = c("HID1" = "hid"))
hh_edge1 <- hh_edge1$locid

hh_edge2 <- hh_edge %>%
  select(HID2) %>%
  left_join(hh_loc, by = c("HID2" = "hid"))
hh_edge2 <- hh_edge2$locid

hh_edge <- data.frame(locid1 = hh_edge1, locid2 = hh_edge2)
dbWriteTable(mydb, "hh_network", hh_edge)

rm(hh_edge1, hh_edge2)

## Neighbour Network
# nb_edge <- fread("synth/tmp/neighbour_network.csv")

# nb_edge1 <- nb_edge %>%
#   select(hid1) %>%
#   left_join(hh_loc, by = c("hid1" = "hid"))
# nb_edge1 <- nb_edge1$locid
# 
# nb_edge2 <- nb_edge %>%
#   select(hid2) %>%
#   left_join(hh_loc, by = c("hid2" = "hid"))
# nb_edge2 <- nb_edge2$locid
# 
# nb_edge <- data.frame(locid1 = nb_edge1, locid2 = nb_edge2)
# dbWriteTable(mydb, "nb_network", nb_edge)

# rm(nb_edge, nb_edge1, nb_edge2, hh_loc)

## Extracurricular (WID2 is the same as locid)
if (lcfg$extracurricular != 0) {
  ec <- fread("synth/tmp/extracurricular.csv")
  if (na.omit(loc$wid2 - loc$locid != 0) %>% any()) stop("some locid not equal to wid2, extracurricular output will be affected.")
  colnames(ec) <- c("pid", paste0("dest_locid_", 1:5))
  dbWriteTable(mydb, "extracurr", ec)
}

dbDisconnect(mydb)

cat("=================================================\n")
source("synth/code/generate_summary.R")

cat("Synthetic population data written into SQLite database ", sqlitename, "\n")

tgzname <- paste0("sim_pop-", lcfg$target_county, "-", lcfg$vers, ".tgz")
filesname <- str_split(dirname, "/")[[1]][2]
setwd("synth/")
tar(tgzname, files = filesname, compression = "gzip")
cat("SQLite database compressed into synth/", tgzname, "\n")
unlink(filesname, recursive = T)
cat("SQLite database and its subfolder removed.\n")
setwd("../")

cat("Done.",
    paste0("To extract ABM input .txt files, go to synth/ subfolder and run 'Rscript extract_sqlite-", lcfg$vers, ".R ", tgzname, "'.\n"))