library(ggmap)
library(dplyr)
library(sf)
library(sp)

#### Area of interest
bbox <- c(left = -80.265, bottom = 25.739, right = -80.121, top = 25.790)
lonlat <- c(lon = mean(bbox[c('left', 'right')]),
            lat = mean(bbox[c('top', 'bottom')]))

#### Grab satellite image and plot
## Adjust `zoom` according to satellite image coverage extent
map <- get_googlemap(center = lonlat, zoom = 12, maptype = "satellite")
p1 <- ggmap(map) +
  coord_sf(xlim = bbox[c('left', 'right')],
           ylim = bbox[c('bottom', 'top')]) +
  theme_void(base_size = 12)

#### Grab Stamen map (OSM)
## Adjust `Zoom` according to level of details
map2 <- get_stamenmap(bbox = bbox, zoom = 13, maptype = "toner-background", color = "color")
ggmap(map2, darken = c(0.4, "white")) + theme_void()

#### Extract Household and Workplace coordinates
loc <- data.table::fread("synth/sim_pop-florida/locations-florida.txt")
set.seed(4326)
hh <- loc |>
  filter(type == "h") |>
  filter(x <= bbox['right'], x >= bbox['left']) |>
  filter(y <= bbox['top'], y >= bbox['bottom']) |>
  sample_frac(0.1)
wp <- loc |>
  filter(type == "w") |>
  filter(x <= bbox['right'], x >= bbox['left']) |>
  filter(y <= bbox['top'], y >= bbox['bottom']) |>
  sample_frac(0.1)
hh_wp_sf <- bind_rows(hh, wp) |>
  st_as_sf(coords = c("x", "y"))

#### Plot HH and WP on Stamen
p2 <- ggmap(map2, darken = c(0.55, "white")) +
  geom_sf(aes(colour=type, size=type), data = hh_wp_sf, alpha = 0.4,
          inherit.aes = FALSE) +
  scale_colour_manual(values = c("blue", "orange"),
                      labels = c("Household", "Workplace")) +
  scale_size_manual(values = c(0.25, 0.5),
                    labels = c("Household", "Workplace")) +
  theme_void(base_size = 12) +
  theme(legend.position = c(1, 1),
        legend.justification = c(1, 1),
        legend.margin = margin(4, 4, 4, 4),
        legend.direction = 'horizontal',
        legend.background = element_rect(fill = "white", colour = NA))

#### Extract other locations and plot
set.seed(4326)
oth <- loc |>
  filter(!type %in% c("h", "w")) |>
  filter(x <= bbox['right'], x >= bbox['left']) |>
  filter(y <= bbox['top'], y >= bbox['bottom'])
oth_sf <- st_as_sf(oth, coords = c("x", "y"))

p3 <- ggmap(map2, darken = c(0.55, "white")) +
  geom_sf(aes(colour=type, shape=type), data = oth_sf,
          inherit.aes = FALSE) +
  scale_colour_manual(values = c("red", "purple", "darkgreen"),
                      labels = c("Hospital", "LTCF", "School")) +
  scale_shape_manual(values = c("H", "N", "S"),
                     labels = c("Hospital", "LTCF", "School")) +
  theme_void(base_size = 12) +
  theme(legend.position = c(1, 1),
        legend.justification = c(1, 1),
        legend.margin = margin(4, 4, 4, 4),
        legend.direction = 'horizontal',
        legend.background = element_rect(fill = "white", colour = NA))

#### Assemble and output
g <- cowplot::plot_grid(p1, p2, p3, axis = "lr", ncol = 1)
ggsave("fig/output.png", g, width = 16, height = 24, units = "cm")