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
