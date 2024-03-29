rm(list=ls()[ls() != "lcfg"])

#### Integrate School data into the population

#### Data import ----
## PERS
gen_pers <- fread("synth/tmp/person_details.csv")
gen_hh <- fread("synth/tmp/hh_coords.csv")

## SCH
gc_sch <- st_read(lcfg$path_schools_shape)
gc_sch <- gc_sch %>%
  st_transform(4326)
table(gc_sch$FLAG, useNA = "ifany")
table(gc_sch$TYPE, useNA = "ifany")

#### Cleaning data ----
# Use GCSCH data for school locations (excl ADULT, SUPPORT SERVICES, UNKNOWN, UNASSIGNED)
# remove corresponding ncd entries based on naics
gc_sch1 <- gc_sch %>%
  filter(FLAG == "V") %>%
  filter(!TYPE %in% c("ADULT", "DISTRICT OFFICE (SCHOOL BOARD)",
                      "SUPPORT SERVICES", "UNASSIGNED", "UNKNOWN"))
table(gc_sch1$TYPE, useNA = "ifany")

# Assign the age range of schools based on type
gc_sch1 <- gc_sch1 %>%
  mutate(AGELO = case_when(
    TYPE == "COLLEGE/UNIVERSITY" ~ 19,
    TYPE == "COMBINATION ELEMENTARY & MIDDLE" ~ 6,
    TYPE == "COMBINATION ELEMENTARY & SECONDARY" ~ 6,
    TYPE == "COMBINATION JR. HIGH & SENIOR HIGH" ~ 12,
    TYPE == "ELEMENTARY" ~ 6,
    TYPE == "HEAD START" ~ 3,
    TYPE == "KINDERGARTEN" ~ 3,
    TYPE == "LEARNING CENTER" ~ 3,
    TYPE == "MIDDLE/JR. HIGH" ~ 12,
    TYPE == "PRE-KINDERGARTEN" ~ 3,
    TYPE == "PRE-KINDERGARTEN-KINDERGARTEN" ~ 3,
    TYPE == "SENIOR HIGH" ~ 16
  ))

gc_sch1 <- gc_sch1 %>%
  mutate(AGEHI = case_when(
    TYPE == "COLLEGE/UNIVERSITY" ~ 35,
    TYPE == "COMBINATION ELEMENTARY & MIDDLE" ~ 15,
    TYPE == "COMBINATION ELEMENTARY & SECONDARY" ~ 18,
    TYPE == "COMBINATION JR. HIGH & SENIOR HIGH" ~ 18,
    TYPE == "ELEMENTARY" ~ 12,
    TYPE == "HEAD START" ~ 5,
    TYPE == "KINDERGARTEN" ~ 5,
    TYPE == "LEARNING CENTER" ~ 5,
    TYPE == "MIDDLE/JR. HIGH" ~ 15,
    TYPE == "PRE-KINDERGARTEN" ~ 5,
    TYPE == "PRE-KINDERGARTEN-KINDERGARTEN" ~ 5,
    TYPE == "SENIOR HIGH" ~ 18
  ))

#### Special considerations made for college/university ----
# For college/university, disable some which are non "classrooms"
cu <- gc_sch1 %>%
  filter(TYPE == "COLLEGE/UNIVERSITY") %>%
  arrange(NAME)
# write_csv(cu, "tmp/cu.csv") # Uncomment if cu_wsize.csv is not available
# And good luck filling in the "Population" of each cu, only 601!
cu1 <- fread(lcfg$path_col_uni_size, keepLeadingZeros = T) %>%
  dplyr::select(AUTOID, Population)
cu <- cu %>%
  left_join(cu1)

gc_sch1 <- gc_sch1 %>%
  filter(TYPE != "COLLEGE/UNIVERSITY") %>%
  mutate(Population = NA) %>%
  select(AUTOID, AGELO, AGEHI, Population)
cu <- cu %>%
  select(AUTOID, AGELO, AGEHI, Population)
gc_sch1 <- rbind(gc_sch1, cu)
gc_sch1$SID <- 1:nrow(gc_sch1)

#### Assign students to schools ----
## Schools coordinates
gc_sch2 <- gc_sch1 %>%
  st_drop_geometry()
gc_sch2 <- gc_sch2 %>%
  bind_cols(st_coordinates(gc_sch1) %>% as.data.frame)

## Coordinates of people who go to schools
sch_pers <- gen_pers %>%
  filter(SCHOOL == 2)
sch_pers <- sch_pers %>%
  left_join(gen_hh %>% select(HID, x, y))

table(sch_pers$AGE) # People up to 95 years old claim they're in school...

# Set artificial boundary of 35 as upper age limit for schooling.
sch_pers <- sch_pers %>%
  filter(AGE <= 35)
nrow(sch_pers)

# For each person in the dataframe, find out schools that match their age range,
# and choose ~ 5 nearest ones (More should be used for "real" dataset). 
# Then assign them based on distance probability
sch_pers <- sch_pers %>%
  arrange(AGE, PID)
sch_pers1 <- as.data.frame(sch_pers[,c("x", "y", "AGE")]) %>% as.matrix
ages <- unique(sch_pers$AGE)
sid <- c()

for (a in 1:length(ages)) {
  age <- ages[a]
  print(age)
  
  xy_age <- sch_pers %>%
    filter(AGE == age) %>%
    select(x, y) %>%
    as.data.frame() %>%
    as.matrix()
  
  if (age >= 19) {
    sch_subs <- gc_sch2 %>%
      filter(AGELO <= age & AGEHI >= age) %>%
      filter(!is.na(Population))
    
    sch_subs_coord <- as.matrix(sch_subs[,c("X", "Y")])
    
    system.time(
      sid_age <- assign_by_gravity(xy_age,
                                   sch_subs_coord,
                                   sch_subs$Population,
                                   5, 4326, steps = 4)
    ) %>% print()
  } else {
    sch_subs <- gc_sch2 %>%
      filter(AGELO <= age, AGEHI >= age)
    
    sch_subs_coord <- as.matrix(sch_subs[,c("X", "Y")])
    
    system.time(
      sid_age <- assign_by_gravity(xy_age,
                                   sch_subs_coord,
                                   rep(1, nrow(sch_subs_coord)),
                                   5, 4326, steps = 4)
    ) %>% print()
    
    
  }
  
  sid_age2 <- sid_age[order(sid_age[,1]),]
  sid_age_v <- sch_subs$SID[sid_age2[,2]]
  
  sid <- c(sid, sid_age_v)
}

sch_pers$SID <- sid
sch_pers_simp <- sch_pers %>%
  select(PID, SID)


#### Harmonize back to PERS ----
gen_pers <- gen_pers %>% 
  left_join(sch_pers_simp)
gen_pers <- gen_pers %>%
  select(PID, HID, NHID, SID, SEX, AGE, SCHOOL, EMPSTATD, PWSTATE2, PWPUMA00, GQ)
table(is.na(gen_pers$SID))

tmp <- sch_pers_simp %>%
  count(SID)


#### Assign workers to SCH ----
gc_sch3 <- gc_sch2 %>%
  select(SID, x = X, y = Y) %>%
  left_join(tmp) %>%
  rename(STUDENT = n)
gc_sch3$WORKER <- ceiling(gc_sch3$STUDENT / 7)


#### Export ----
fwrite(gc_sch3, "synth/tmp/sch.csv")
fwrite(gen_pers, "synth/tmp/person_details.csv")
