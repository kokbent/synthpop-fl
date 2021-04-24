make_full_path <- function (cfg) {
  ## Add cfg$data_folder to the front of cfg$path_XXX
  ## And also check existence of files
  ind <- names(cfg) %>% 
    str_starts("path_") %>% 
    which
  
  cfg[ind] <- cfg[ind] %>%
    lapply(function (x) file.path(cfg$data_folder, x) %>%
             normalizePath(mustWork = T))
  
  return(cfg)
}

quiet <- function(x) { 
  options(warn=-1)
  sink(tempfile()) 
  on.exit({sink();options(warn=0)}) 
  invisible(force(x)) 
} 

load_and_check <- function (item, cfg, ess_col, type = "table") {
  path_item <- paste0("path_", item)
  if (type == "table") {
    quiet(obj <- fread(cfg[[path_item]], keepLeadingZeros = T))
    cond <- ess_col[[item]] %in% colnames(obj)
    if(!all(cond)) {
      ms_col <- paste(ess_col[[item]][!cond], collapse = ", ")
      stop("Incompatible ", item, ". Missing ", ms_col, " column.")
    }
  } else if (type == "shape") {
    quiet(obj <- st_read(cfg[[path_item]]))
    cond <- ess_col[[item]] %in% colnames(obj)
    if(!all(cond)) {
      ms_col <- paste(ess_col[[item]][!cond], collapse = ", ")
      stop("Incompatible ", item, ". Missing ", ms_col, " column.")
    }
  } else if (type == "ipums") {
    path_xml <- "path_ipums_xml"
    ddi <- read_ipums_ddi(cfg[[path_xml]])
    quiet(obj <- read_ipums_micro(ddi))
    cond <- ess_col[["ipums"]] %in% colnames(obj)
    if(!all(cond)) {
      ms_col <- paste(ess_col[[item]][!cond], collapse = ", ")
      stop("Incompatible ", item, ". Missing ", ms_col, " column.")
    }
  }
  
  return(obj)
}
