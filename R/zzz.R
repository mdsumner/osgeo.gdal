# global reference to scipy (will be initialized in .onLoad)
gdal <- NULL

#' @importFrom  reticulate import
.onLoad <- function(libname, pkgname) {
  # use superassignment to update global reference to scipy
  gdal <<- reticulate::import("osgeo.gdal", delay_load = TRUE)
}
