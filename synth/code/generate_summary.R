summaryname <- paste0(dirname, "-summary.txt")
plotname <- paste0(dirname, "-plot.png")

#### Text summary
cat1 <- function (...) {
  cat(..., "\n", file = summaryname, append = T, sep = "")
}

cat("Summary for ", str_split(dirname, "/", simplify = T)[2], "\n",
    file = summaryname, sep = "")
cat1("================================================")
cat1("Numbers of locations by type:")
cat1("Households\t", nrow(hh_db))
cat1("Workplaces\t", nrow(wp_db))
cat1("Schools   \t", nrow(sch_db))
cat1("LTCFs     \t", nrow(nh_db))
cat1("Hospitals \t", nrow(hf))
cat1()

npers <- nrow(pers_db)
nschpers <- sum(movement_db$type == "s")
nworkpers <- sum(movement_db$type == "w")
cat1("There are ", npers, " people in the synthpop. ", 
     "Average size of household is ", round(npers/nrow(hh_db), 2), ".")
cat1("There are ", nschpers, " (", round(nschpers/npers*100, 1), "%) schoolgoers and ",
     nworkpers, " (", round(nworkpers/npers*100, 1), "%) workers.")
cat1()

cat1("Inter-household network: ", nrow(hh_edge), " edges.")
cat1("On average, each non-LTCF household engages in ", 
     round(nrow(hh_edge)/sum(hh_db$nh == "n"), 2), " interactions.")
cat1("================================================")

#### Plot (Locations)
nhh <- sum(loc$type == "h")
frac <- ifelse(nhh <= 200000, 1, 200000/nhh)

png(plotname, width = 2400, height = 2400, res = 300)
tmp <- loc %>%
  filter(type == "h") %>%
  sample_frac(size = frac)
plot(tmp$x, tmp$y, pch = ".", col = "#77777740", asp = 1,
     xlab = "", ylab = "",
     main = paste0("Locations in the synthpop (Subsample of ", round(frac*100, 1), "%)"))

tmp <- loc %>%
  filter(type == "w") %>%
  sample_frac(size = frac)
points(tmp$x, tmp$y, pch = ".", col = "#00005540")

tmp <- loc %>%
  filter(!type %in% c("h", "w")) %>%
  sample_frac(size = frac)
points(tmp$x, tmp$y, pch = ".", col = "#FF0000AA", cex = 2)
quiet(dev.off())

cat("Text summary of the synthetic population generated at", summaryname, "\n")
cat("Visualization of locations of the synthetic population generated at", plotname, 
    "(Gray = households, blue = workplaces, red = others.)\n")