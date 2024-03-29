rm(list=ls()[ls() != "lcfg"])

#### Build household network
pers <- fread("synth/tmp/pers_w_wid.csv")
hh <- fread("synth/tmp/hh_coords.csv")
nh <- fread("synth/tmp/nh.csv")

hh_nh <- inner_join(hh, nh %>% select(x, y))
hh_nonnh <- hh %>%
  filter(!HID %in% hh_nh$HID)

## Determine HH size
hh_count <- pers %>%
  group_by(HID) %>%
  count()

hh_nonnh <- hh_nonnh %>%
  left_join(hh_count)

sum(hh_nonnh$n)

## Determine the "capacity" of each household
## Rules: (1) Household mean = HH member size
set.seed(1849)
hh_nonnh$cap <- rpois(nrow(hh_nonnh), hh_nonnh$n * 2)
sum(hh_nonnh$cap == 0)
hh_wcap <- hh_nonnh %>%
  filter(cap != 0)

## Run away with it!
system.time(
  edges <- build_network_wcomp(locs = hh_wcap[,c("x", "y")] %>% as.matrix(),
                               weights = hh_wcap$cap, 
                               compliance = hh_wcap$compliance,
                               1000, seed = 4342024)
)

hid1 <- hh_wcap$HID[edges[,1]]
hid2 <- hh_wcap$HID[edges[,2]]

mean(hid1 == hid2)
edges_hid <- cbind(HID1 = hid1, HID2 = hid2) %>% as.data.table

## Export
# write_csv(as.data.frame(edges), "./tmp/edges.csv")
# write_delim(as.data.frame(edges_hid), "./tmp/network-florida.txt", col_names = F)
# file.copy("./tmp/network-florida.txt", "sim_pop-florida/network-florida.txt")
fwrite(edges_hid, "synth/tmp/hh_network.csv")
