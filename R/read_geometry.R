#' @importFrom wk wkb
#' @name og_read_geometry
#' @export
og_read_geometry <- function(dsn = dsn::CGAZ(), ia = NULL, layer = 1L, simplify = NULL, localproject = FALSE) {
  ## CGAZ() is just a path to a zipped shapefile on the internet /vsizip//vsicurl/https://.....zip
  ## gdal is 'import from osgeo gdal' as per python
  ds <- gdal$OpenEx(dsn)
  if (layer < 1 ) stop("we can't read layer 0 or lower (one-based here)")
  if (layer > (ds$GetLayerCount()) ) stop(sprintf("no layer %i", layer))
  src <- ds$GetLayerByIndex(as.integer(layer - 1))
  cnt <- src$GetFeatureCount()

  if (is.null(ia)) ia <- seq_len(cnt)
  if (any(ia < 1) || any(ia > cnt) || anyNA(ia)) stop("invalid feature number")
  #features_to_read <- sort(ij)
  wkb0 <- vector("list", length(ia))
  for (i in seq_along(wkb0)) {
    feature <- src$GetFeature(ia[i] - 1)
    geom <- feature$GetGeometryRef()

    if (!is.null(simplify) && is.numeric(simplify) && !is.na(simplify[1L])) {
      geom <- geom$SimplifyPreserveTopology(simplify[1L])

    }

    if (localproject) {
      ## here's how to transform geometries
      template <- "+proj=laea +lon_0=%f +lat_0=%f"
      env <- geom$GetEnvelope()
      input <- sprintf(template, mean(unlist(env[1:2])), mean(unlist(env[3:4])))
      transformer <- gdal$osr$CoordinateTransformation(geom$GetSpatialReference(),
                                                       gdal$osr$SpatialReference(gdal$osr$GetUserInputAsWKT(input)))
      err <- geom$Transform(transformer)
    }
    wkb0[[i]] <- geom$ExportToWkb()
  }
  wk::wkb(wkb0)
}


#' @importFrom tibble as_tibble
#' @name og_read_fields
#' @export
og_read_fields <- function(dsn = dsn::CGAZ(), ia = NULL, layer = 1L) {
  ## CGAZ() is just a path to a zipped shapefile on the internet /vsizip//vsicurl/https://.....zip
  ## gdal is 'import from osgeo gdal' as per python
  ds <- gdal$OpenEx(dsn)
  if (layer < 1 ) stop("we can't read layer 0 or lower (one-based here)")
  if (layer > (ds$GetLayerCount()) ) stop(sprintf("no layer %i", layer))
  src <- ds$GetLayerByIndex(as.integer(layer - 1))
  cnt <- src$GetFeatureCount()

  if (is.null(ia)) ia <- seq_len(cnt)
  if (any(ia < 1) || any(ia > cnt) || anyNA(ia)) stop("invalid feature number")
  #features_to_read <- sort(ij)
  feat0 <- vector("list", length(ia))
  def <- src$GetLayerDefn()
  badlist <- vector("list", length(feat0))

  for (i in seq_along(feat0)) {
    feature <- src$GetFeature(ia[i] - 1)
    if (i == 1) {
      fcount <- feature$GetFieldCount()
      fnames <- unlist(lapply(seq_len(fcount), \(.x) def$GetFieldDefn(.x - 1L)$GetName()))
    }
    lst <- setNames(lapply(seq_len(fcount), \(.x) feature$GetField(.x - 1L)), fnames)
    bad <- which(unlist(lapply(lst, is.null)))

    badlist[[i]] <- bad
    feat0[[i]] <- lst
  }

  ## names in common that were bad
  bad <- sort(unique(unlist(badlist)))


  if (length(bad) > 0) {
    print(bad)
    message(sprintf("some feature fields had NULL values, not dealt with yet\n full field set names were: \n%s", paste(fnames, collapse = ",")))
    #stop()
  }
  tibble::as_tibble(do.call(rbind, lapply(feat0, tibble::as_tibble)))
}
