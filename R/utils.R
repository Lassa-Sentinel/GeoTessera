#' @title Utility Functions for GeoTessera
#' @description Internal utility functions for coordinate conversion, file operations, and downloads.
#' @name utils
#' @keywords internal
NULL

# Constants
TILE_SIZE <- 0.1
TILE_OFFSET <- 0.05
BLOCK_SIZE <- 5
TILE_RESOLUTION <- 10  # meters
EMBEDDING_CHANNELS <- 128
TILE_PIXELS <- 1111  # pixels per tile dimension

#' Convert world coordinates to block coordinates
#'
#' Blocks are 5x5 degree regions used for registry organization.
#'
#' @param lon Longitude in decimal degrees
#' @param lat Latitude in decimal degrees
#' @return Named list with block_lon and block_lat
#' @keywords internal
block_from_world <- function(lon, lat) {
  block_lon <- floor(lon / BLOCK_SIZE) * BLOCK_SIZE
  block_lat <- floor(lat / BLOCK_SIZE) * BLOCK_SIZE
  list(block_lon = block_lon, block_lat = block_lat)
}

#' Convert world coordinates to tile coordinates
#'
#' Tiles are 0.1x0.1 degree regions containing the actual embedding data.
#' Tile centers are on 0.05-degree offsets (e.g., -0.05, 0.05, 0.15, etc.).
#'
#' @param lon Longitude in decimal degrees
#' @param lat Latitude in decimal degrees
#' @return Named list with tile_lon and tile_lat (center coordinates)
#' @keywords internal
#' @examples
#' \dontrun{
#' tile_from_world(0.17, 52.23)  # Returns (0.15, 52.25)
#' tile_from_world(-0.1, 51.3)   # Returns (-0.05, 51.35)
#' }
tile_from_world <- function(lon, lat) {
  # Use multiply-then-divide to avoid floating-point precision issues
  # (e.g., 51.3 / 0.1 can give 512.999... which floors to 512)
  tile_lon <- round(floor(lon * 10) / 10 + TILE_OFFSET, 2)
  tile_lat <- round(floor(lat * 10) / 10 + TILE_OFFSET, 2)
  list(tile_lon = tile_lon, tile_lat = tile_lat)
}

#' Get tile bounds from center coordinates
#'
#' @param lon Tile center longitude
#' @param lat Tile center latitude
#' @return Named list with xmin, ymin, xmax, ymax
#' @keywords internal
tile_to_bounds <- function(lon, lat) {
  list(
    xmin = lon - TILE_OFFSET,
    ymin = lat - TILE_OFFSET,
    xmax = lon + TILE_OFFSET,
    ymax = lat + TILE_OFFSET
  )
}

#' Create sf bounding box from tile coordinates
#'
#' @param lon Tile center longitude
#' @param lat Tile center latitude
#' @return sf bbox object
#' @keywords internal
tile_to_bbox <- function(lon, lat) {
  bounds <- tile_to_bounds(lon, lat)
  sf::st_bbox(c(
    xmin = bounds$xmin,
    ymin = bounds$ymin,
    xmax = bounds$xmax,
    ymax = bounds$ymax
  ), crs = sf::st_crs(4326))
}

#' Convert tile coordinates to grid name
#'
#' @param lon Tile center longitude
#' @param lat Tile center latitude
#' @return Character string grid name (e.g., "grid_0.15_52.05")
#' @keywords internal
tile_to_grid_name <- function(lon, lat) {
  sprintf("grid_%.2f_%.2f", lon, lat)
}

#' Parse grid name to coordinates
#'
#' @param grid_name Grid name string (e.g., "grid_0.15_52.05")
#' @return Named list with lon and lat
#' @keywords internal
parse_grid_name <- function(grid_name) {
  # Get just the filename
  base_name <- fs::path_file(grid_name)

  # Remove known file extensions (be explicit to avoid removing .55 etc.)
  base_name <- sub("\\.(npy|tif|tiff|zarr)$", "", base_name, ignore.case = TRUE)

  # Remove _scales suffix if present
  base_name <- sub("_scales$", "", base_name)

  pattern <- "^grid_(-?[0-9]+\\.?[0-9]*)_(-?[0-9]+\\.?[0-9]*)$"
  if (!grepl(pattern, base_name)) {
    cli::cli_abort("Invalid grid name format: {grid_name}")
  }

  matches <- regmatches(base_name, regexec(pattern, base_name))[[1]]
  list(
    lon = as.numeric(matches[2]),
    lat = as.numeric(matches[3])
  )
}

#' Get all blocks that intersect with a bounding box
#'
#' @param bbox sf bbox object or named vector with xmin, ymin, xmax, ymax
#' @return Data frame with block_lon and block_lat columns
#' @keywords internal
blocks_in_bounds <- function(bbox) {
  if (inherits(bbox, "bbox")) {
    xmin <- bbox["xmin"]
    xmax <- bbox["xmax"]
    ymin <- bbox["ymin"]
    ymax <- bbox["ymax"]
  } else {
    xmin <- bbox$xmin %||% bbox[["xmin"]]
    xmax <- bbox$xmax %||% bbox[["xmax"]]
    ymin <- bbox$ymin %||% bbox[["ymin"]]
    ymax <- bbox$ymax %||% bbox[["ymax"]]
  }

  min_block <- block_from_world(xmin, ymin)
  max_block <- block_from_world(xmax, ymax)

  block_lons <- seq(min_block$block_lon, max_block$block_lon, by = BLOCK_SIZE)
  block_lats <- seq(min_block$block_lat, max_block$block_lat, by = BLOCK_SIZE)

  expand.grid(block_lon = block_lons, block_lat = block_lats)
}

#' Generate embedding registry filename for a block
#'
#' @param year Integer year
#' @param block_lon Block longitude
#' @param block_lat Block latitude
#' @return Character string filename
#' @keywords internal
block_to_embeddings_registry_filename <- function(year, block_lon, block_lat) {
  sprintf("embeddings_%d_%d_%d.parquet", year, block_lon, block_lat)
}

#' Generate landmasks registry filename for a block
#'
#' @param block_lon Block longitude
#' @param block_lat Block latitude
#' @return Character string filename
#' @keywords internal
block_to_landmasks_registry_filename <- function(block_lon, block_lat) {
  sprintf("landmasks_%d_%d.parquet", block_lon, block_lat)
}

#' Generate embedding file paths for a tile
#'
#' @param lon Tile longitude
#' @param lat Tile latitude
#' @param year Integer year
#' @return Named list with embedding_path and scales_path
#' @keywords internal
tile_to_embedding_paths <- function(lon, lat, year) {

  grid_name <- tile_to_grid_name(lon, lat)
  base_path <- fs::path("global_0.1_degree_representation", year, grid_name)
  list(
    embedding_path = fs::path(base_path, paste0(grid_name, ".npy")),
    scales_path = fs::path(base_path, paste0(grid_name, "_scales.npy"))
  )
}

#' Generate GeoTIFF path for a tile
#'
#' @param lon Tile longitude
#' @param lat Tile latitude
#' @param year Integer year
#' @return Character string path
#' @keywords internal
tile_to_geotiff_path <- function(lon, lat, year) {
  grid_name <- tile_to_grid_name(lon, lat)
  fs::path(sprintf("geotessera_%d", year), paste0(grid_name, ".tif"))
}

#' Generate landmask filename for a tile
#'
#' @param lon Tile longitude
#' @param lat Tile latitude
#' @return Character string filename
#' @keywords internal
tile_to_landmask_filename <- function(lon, lat) {
  grid_name <- tile_to_grid_name(lon, lat)
  paste0(grid_name, ".tiff")
}

#' Calculate SHA256 hash of a file
#'
#' @param file_path Path to file
#' @return Character string hash
#' @keywords internal
calculate_file_hash <- function(file_path) {
  digest::digest(file_path, algo = "sha256", file = TRUE)
}

#' Download a file with progress and optional hash verification
#'
#' @param url URL to download from
#' @param dest_path Destination file path
#' @param expected_hash Optional expected SHA256 hash
#' @param progress Show progress bar
#' @param max_retries Maximum number of retry attempts
#' @param timeout Timeout in seconds
#' @return Path to downloaded file
#' @keywords internal
download_file <- function(url, dest_path, expected_hash = NULL,
                          progress = TRUE, max_retries = 3, timeout = 60) {
  attempt <- 1

  while (attempt <= max_retries) {
    tryCatch({
      req <- httr2::request(url) |>
        httr2::req_timeout(timeout) |>
        httr2::req_retry(max_tries = 1)

      if (progress) {
        req <- httr2::req_progress(req)
      }

      httr2::req_perform(req, path = dest_path)

      # Verify hash if provided
      if (!is.null(expected_hash)) {
        actual_hash <- calculate_file_hash(dest_path)
        if (actual_hash != expected_hash) {
          fs::file_delete(dest_path)
          cli::cli_abort(c(
            "Hash verification failed",
            "x" = "Expected: {expected_hash}",
            "x" = "Got: {actual_hash}"
          ))
        }
      }

      return(dest_path)
    }, error = function(e) {
      if (attempt == max_retries) {
        cli::cli_abort(c(
          "Download failed after {max_retries} attempts",
          "x" = conditionMessage(e)
        ))
      }
      attempt <<- attempt + 1
      Sys.sleep(1)
    })
  }
}

#' Download file to temporary location
#'
#' @param url URL to download from
#' @param expected_hash Optional expected SHA256 hash
#' @param cache_path Optional cache path to use instead of temp
#' @param progress Show progress bar
#' @return Path to downloaded file
#' @keywords internal
download_file_to_temp <- function(url, expected_hash = NULL, cache_path = NULL,
                                   progress = TRUE) {
  if (!is.null(cache_path) && fs::file_exists(cache_path)) {
    if (!is.null(expected_hash)) {
      actual_hash <- calculate_file_hash(cache_path)
      if (actual_hash == expected_hash) {
        return(cache_path)
      }
    } else {
      return(cache_path)
    }
  }

  dest_path <- cache_path %||% tempfile()
  download_file(url, dest_path, expected_hash, progress)
}

#' Get default cache directory
#'
#' @return Path to cache directory
#' @export
get_cache_dir <- function() {
  cache_dir <- Sys.getenv("GEOTESSERA_CACHE_DIR", unset = "")
  if (cache_dir == "") {
    cache_dir <- fs::path(rappdirs::user_cache_dir(), "geotessera")
  }
  fs::dir_create(cache_dir)
  cache_dir
}

#' Check if a URL is valid
#'
#' @param string String to check
#' @return Logical
#' @keywords internal
is_url <- function(string) {
  grepl("^https?://", string, ignore.case = TRUE)
}

#' Convert bbox to named list
#'
#' Converts various bbox formats to a named list with xmin, ymin, xmax, ymax.
#'
#' @param bbox Numeric vector (4 elements), named vector, list, or sf bbox
#' @return Named list with xmin, ymin, xmax, ymax
#' @keywords internal
format_bbox_to_list <- function(bbox) {
  if (inherits(bbox, "bbox")) {
    list(
      xmin = unname(bbox["xmin"]),
      ymin = unname(bbox["ymin"]),
      xmax = unname(bbox["xmax"]),
      ymax = unname(bbox["ymax"])
    )
  } else if (is.list(bbox)) {
    # Already a list with named elements
    list(
      xmin = bbox$xmin %||% bbox[["xmin"]],
      ymin = bbox$ymin %||% bbox[["ymin"]],
      xmax = bbox$xmax %||% bbox[["xmax"]],
      ymax = bbox$ymax %||% bbox[["ymax"]]
    )
  } else if (is.numeric(bbox) && length(bbox) == 4) {
    # Numeric vector: assume order is xmin, ymin, xmax, ymax
    if (!is.null(names(bbox))) {
      list(
        xmin = unname(bbox["xmin"]),
        ymin = unname(bbox["ymin"]),
        xmax = unname(bbox["xmax"]),
        ymax = unname(bbox["ymax"])
      )
    } else {
      list(xmin = bbox[1], ymin = bbox[2], xmax = bbox[3], ymax = bbox[4])
    }
  } else {
    cli::cli_abort("Invalid bbox format. Expected sf bbox, named list, or numeric vector of length 4")
  }
}

#' Format a bounding box for display
#'
#' @param bbox Named vector or sf bbox
#' @return Character string
#' @keywords internal
format_bbox <- function(bbox) {
  b <- format_bbox_to_list(bbox)
  sprintf("(%.4f, %.4f, %.4f, %.4f)", b$xmin, b$ymin, b$xmax, b$ymax)
}

#' Dequantize embedding data
#'
#' Convert int8 quantized embeddings back to float32 using scale factors.
#' Supports both per-channel scales (128 values) and per-pixel scales (H x W matrix).
#'
#' @param quantized_embedding Integer matrix/array of quantized values (H x W x C)
#' @param scales Numeric array of scale factors - either vector (128) or matrix (H x W)
#' @return Numeric array of dequantized embeddings
#' @keywords internal
dequantize_embedding <- function(quantized_embedding, scales) {
  # Get dimensions
  embed_dims <- dim(quantized_embedding)
  scales_dims <- dim(scales)

  if (length(embed_dims) != 3) {
    cli::cli_abort("Expected 3D embedding array (H x W x C), got {length(embed_dims)}D")
  }

  height <- embed_dims[1]
  width <- embed_dims[2]
  channels <- embed_dims[3]

  if (is.null(scales_dims)) {
    # scales is a vector - per-channel scaling
    if (length(scales) != channels) {
      cli::cli_abort("Per-channel scales must have {channels} elements, got {length(scales)}")
    }
    result <- array(0, dim = embed_dims)
    for (i in seq_len(channels)) {
      result[, , i] <- quantized_embedding[, , i] * scales[i]
    }
  } else if (length(scales_dims) == 2) {
    # scales is a matrix - per-pixel scaling
    # scales is (H, W), broadcast across channels
    if (scales_dims[1] != height || scales_dims[2] != width) {
      cli::cli_abort(
        "Per-pixel scales dimensions ({scales_dims[1]} x {scales_dims[2]}) ",
        "don't match embedding ({height} x {width})"
      )
    }
    result <- array(0, dim = embed_dims)
    for (i in seq_len(channels)) {
      result[, , i] <- quantized_embedding[, , i] * scales
    }
  } else {
    cli::cli_abort("Scales must be vector (per-channel) or matrix (per-pixel), got {length(scales_dims)}D")
  }

  result
}

#' Read NPY file
#'
#' Simple reader for numpy .npy files (assumes C-order, little-endian).
#'
#' @param path Path to .npy file
#' @return Array with data
#' @keywords internal
read_npy <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))

  # Read magic number
  magic <- readBin(con, "raw", 6)
  if (!all(magic == charToRaw("\x93NUMPY"))) {
    cli::cli_abort("Not a valid NPY file")
  }

  # Read version
  major_version <- readBin(con, "integer", 1, size = 1, signed = FALSE)
  minor_version <- readBin(con, "integer", 1, size = 1, signed = FALSE)

  # Read header length
  if (major_version == 1) {
    header_len <- readBin(con, "integer", 1, size = 2, endian = "little", signed = FALSE)
  } else {
    header_len <- readBin(con, "integer", 1, size = 4, endian = "little", signed = FALSE)
  }

  # Read header
  header <- rawToChar(readBin(con, "raw", header_len))

  # Parse header for dtype and shape
  descr_match <- regmatches(header, regexec("'descr':\\s*'([^']+)'", header))[[1]]
  shape_match <- regmatches(header, regexec("'shape':\\s*\\(([^)]+)\\)", header))[[1]]
  fortran_match <- regmatches(header, regexec("'fortran_order':\\s*(True|False)", header))[[1]]

  descr <- descr_match[2]
  shape_str <- shape_match[2]
  fortran_order <- if (length(fortran_match) > 1) fortran_match[2] == "True" else FALSE

  # Parse shape
  shape <- as.integer(strsplit(gsub("\\s", "", shape_str), ",")[[1]])
  shape <- shape[!is.na(shape)]

  # Determine data type and size
  # Numpy dtype format: endian + type_char + size (e.g., "<f8", "|i1", ">u4")
  # endian: < (little), > (big), | (not applicable, for single-byte data)
  # type_char: f (float), i (int), u (uint), b (bool/byte)
  endian <- substr(descr, 1, 1)
  dtype_char <- substr(descr, 2, 2)
  dtype_size <- as.integer(substr(descr, 3, nchar(descr)))

  n_elements <- prod(shape)

  # Read data based on dtype
  if (dtype_char == "f") {
    # Float
    data <- readBin(con, "double", n_elements, size = dtype_size,
                    endian = if (endian == "<") "little" else "big")
  } else if (dtype_char == "i") {
    # Signed integer
    data <- readBin(con, "integer", n_elements, size = dtype_size,
                    endian = if (endian == "<") "little" else "big", signed = TRUE)
  } else if (dtype_char == "u") {
    # Unsigned integer (read as raw, convert)
    raw_data <- readBin(con, "raw", n_elements * dtype_size)
    if (dtype_size == 1) {
      data <- as.integer(raw_data)
    } else {
      data <- readBin(raw_data, "integer", n_elements, size = dtype_size,
                      endian = if (endian == "<") "little" else "big", signed = FALSE)
    }
  } else if (dtype_char == "b") {
    # Signed byte (int8)
    raw_data <- readBin(con, "raw", n_elements)
    data <- as.integer(raw_data)
    # Convert unsigned to signed
    data[data > 127] <- data[data > 127] - 256L
  } else {
    cli::cli_abort("Unsupported numpy dtype: {descr}")
  }

  # Reshape
  if (length(shape) > 1) {
    if (fortran_order) {
      data <- array(data, dim = shape)
    } else {
      # C order - need to reverse dimensions and transpose
      data <- array(data, dim = rev(shape))
      data <- aperm(data, rev(seq_along(shape)))
    }
  }

  data
}

#' Get UTM zone for a longitude
#'
#' @param lon Longitude in decimal degrees
#' @return Integer UTM zone number
#' @keywords internal
get_utm_zone <- function(lon) {
  floor((lon + 180) / 6) + 1
}

#' Get UTM EPSG code for coordinates
#'
#' @param lon Longitude
#' @param lat Latitude
#' @return Integer EPSG code
#' @keywords internal
get_utm_epsg <- function(lon, lat) {
  zone <- get_utm_zone(lon)
  if (lat >= 0) {
    32600 + zone  # Northern hemisphere
  } else {
    32700 + zone  # Southern hemisphere
  }
}

# Note: %||% operator is imported from rlang in GeoTessera-package.R
