#' GeoTessera: Access Tessera Geofoundation Model Embeddings
#'
#' The GeoTessera package provides an R interface to Tessera geofoundation model
#' embeddings. It enables downloading 128-channel dense representation maps at
#' 10m resolution derived from Sentinel-1 and Sentinel-2 satellite imagery.
#'
#' @section Main Classes:
#' \describe{
#'   \item{GeoTessera}{Main interface for downloading and exporting embeddings}
#'   \item{Registry}{Registry management for tile metadata and downloads}
#'   \item{Tile}{Format-agnostic tile abstraction}
#'   \item{CountryLookup}{Country name to geometry lookup}
#' }
#'
#' @section Quick Start:
#' \preformatted{
#' # Create a GeoTessera client
#' gt <- geotessera()
#'
#' # Get tiles for a region (London)
#' tiles <- gt$get_tiles(
#'   bbox = c(-0.2, 51.4, 0.1, 51.6),
#'   year = 2024
#' )
#'
#' # Export as GeoTIFFs
#' gt$export_embedding_geotiffs(
#'   tiles = tiles,
#'   output_dir = "london_tiles"
#' )
#'
#' # Sample embeddings at specific points
#' points <- data.frame(
#'   lon = c(-0.1, 0.0),
#'   lat = c(51.5, 51.5)
#' )
#' embeddings <- gt$sample_embeddings_at_points(points, year = 2024)
#' }
#'
#' @section Data Organization:
#' Tessera data is organized in a hierarchical system:
#' \itemize{
#'   \item Blocks: 5x5 degree regions for registry organization
#'   \item Tiles: 0.1x0.1 degree regions containing embedding data
#'   \item Pixels: 10m resolution within each tile
#' }
#'
#' @section Supported Formats:
#' \itemize{
#'   \item NPY: Native numpy format with separate scales files
#'   \item GeoTIFF: Georeferenced raster format
#'   \item Zarr: Chunked array format (experimental)
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom sf st_bbox st_crs st_geometry st_sfc st_point st_polygon st_sf st_intersects st_read st_write st_centroid st_union st_coordinates st_as_sf st_transform
#' @importFrom terra rast ext res crs nlyr nrow ncol values writeRaster project merge subset
#' @importFrom arrow read_parquet
#' @importFrom httr2 request req_timeout req_retry req_progress req_perform
#' @importFrom cli cli_abort cli_warn cli_alert_info cli_alert_success cli_progress_bar cli_progress_update cli_progress_done cli_h1 cli_text
#' @importFrom digest digest
#' @importFrom jsonlite read_json write_json
#' @importFrom fs path path_file path_ext path_ext_remove path_dir path_split file_exists file_delete file_size dir_exists dir_create dir_ls
#' @importFrom glue glue
#' @importFrom rlang `%||%`
#' @importFrom withr local_tempfile local_tempdir
#' @keywords internal
"_PACKAGE"
