#' @title Tile Class for Embedding Data
#' @description Format-agnostic tile abstraction supporting NPY, GeoTIFF, and Zarr storage.
#' @name Tile
#' @export
Tile <- R6::R6Class(
  "Tile",
  public = list(
    #' @field lon Tile center longitude
    lon = NULL,
    #' @field lat Tile center latitude
    lat = NULL,
    #' @field year Data year
    year = NULL,
    #' @field format Storage format ("npy", "geotiff", or "zarr")
    format = NULL,
    #' @field path Path to the data file
    path = NULL,
    #' @field scales_path Path to scales file (for NPY format)
    scales_path = NULL,
    #' @field landmask_path Path to landmask file
    landmask_path = NULL,

    #' @description Create a new Tile object
    #' @param lon Tile center longitude
    #' @param lat Tile center latitude
    #' @param year Data year
    #' @param format Storage format
    #' @param path Path to data file
    #' @param scales_path Path to scales file (for NPY)
    #' @param landmask_path Path to landmask file
    #' @return A new Tile object
    initialize = function(lon, lat, year, format = "npy", path = NULL,
                          scales_path = NULL, landmask_path = NULL) {
      self$lon <- lon
      self$lat <- lat
      self$year <- year
      self$format <- format
      self$path <- path
      self$scales_path <- scales_path
      self$landmask_path <- landmask_path
    },

    #' @description Get the grid name for this tile
    #' @return Character string grid name
    get_grid_name = function() {
      tile_to_grid_name(self$lon, self$lat)
    },

    #' @description Get the bounding box for this tile
    #' @return Named list with xmin, ymin, xmax, ymax
    get_bounds = function() {
      tile_to_bounds(self$lon, self$lat)
    },

    #' @description Get the bounding box as an sf bbox object
    #' @return sf bbox object
    get_bbox = function() {
      tile_to_bbox(self$lon, self$lat)
    },

    #' @description Get the CRS (Coordinate Reference System)
    #' @return sf crs object (WGS84 for geographic, UTM for GeoTIFF)
    get_crs = function() {
      if (self$format == "geotiff" && !is.null(self$path) && fs::file_exists(self$path)) {
        r <- terra::rast(self$path)
        sf::st_crs(terra::crs(r))
      } else {
        sf::st_crs(4326)
      }
    },

    #' @description Get the affine transform
    #' @return Named list with resolution and origin info
    get_transform = function() {
      if (self$format == "geotiff" && !is.null(self$path) && fs::file_exists(self$path)) {
        r <- terra::rast(self$path)
        ext <- terra::ext(r)
        res <- terra::res(r)
        list(
          xres = res[1],
          yres = res[2],
          xmin = ext$xmin,
          ymax = ext$ymax
        )
      } else {
        bounds <- self$get_bounds()
        list(
          xres = TILE_SIZE / TILE_PIXELS,
          yres = TILE_SIZE / TILE_PIXELS,
          xmin = bounds$xmin,
          ymax = bounds$ymax
        )
      }
    },

    #' @description Get tile dimensions
    #' @return Named list with height, width, channels
    get_dimensions = function() {
      list(
        height = TILE_PIXELS,
        width = TILE_PIXELS,
        channels = EMBEDDING_CHANNELS
      )
    },

    #' @description Check if data files are available
    #' @param require_landmask Also require landmask to be available
    #' @return Logical
    is_available = function(require_landmask = FALSE) {
      available <- switch(
        self$format,
        "npy" = !is.null(self$path) && fs::file_exists(self$path) &&
          !is.null(self$scales_path) && fs::file_exists(self$scales_path),
        "geotiff" = !is.null(self$path) && fs::file_exists(self$path),
        "zarr" = !is.null(self$path) && fs::dir_exists(self$path),
        FALSE
      )

      if (available && require_landmask) {
        available <- available &&
          !is.null(self$landmask_path) && fs::file_exists(self$landmask_path)
      }

      available
    },

    #' @description Load the embedding data
    #' @return 3D array with dimensions (height, width, channels)
    load_embedding = function() {
      if (!self$is_available()) {
        cli::cli_abort("Tile data not available. Download first.")
      }

      switch(
        self$format,
        "npy" = private$load_npy_embedding(),
        "geotiff" = private$load_geotiff_embedding(),
        "zarr" = private$load_zarr_embedding(),
        cli::cli_abort("Unknown format: {self$format}")
      )
    },

    #' @description Check if a point is within this tile
    #' @param lon Longitude
    #' @param lat Latitude
    #' @return Logical
    contains_point = function(lon, lat) {
      bounds <- self$get_bounds()
      lon >= bounds$xmin && lon < bounds$xmax &&
        lat >= bounds$ymin && lat < bounds$ymax
    },

    #' @description Sample embedding at a specific point
    #' @param lon Longitude
    #' @param lat Latitude
    #' @return Numeric vector of embedding values (128 channels)
    sample_at_point = function(lon, lat) {
      if (!self$contains_point(lon, lat)) {
        cli::cli_abort("Point ({lon}, {lat}) is outside tile bounds")
      }

      embedding <- self$load_embedding()
      bounds <- self$get_bounds()
      dims <- self$get_dimensions()

      # Calculate pixel indices
      x_frac <- (lon - bounds$xmin) / TILE_SIZE
      y_frac <- (bounds$ymax - lat) / TILE_SIZE  # Y is inverted

      col <- min(floor(x_frac * dims$width) + 1, dims$width)
      row <- min(floor(y_frac * dims$height) + 1, dims$height)

      embedding[row, col, ]
    },

    #' @description Convert tile info to a list
    #' @return Named list
    to_list = function() {
      list(
        lon = self$lon,
        lat = self$lat,
        year = self$year,
        grid_name = self$get_grid_name(),
        format = self$format,
        path = self$path,
        scales_path = self$scales_path,
        landmask_path = self$landmask_path,
        available = self$is_available()
      )
    },

    #' @description Print tile summary
    print = function() {
      cli::cli_h1("Tile: {self$get_grid_name()}")
      cli::cli_text("Location: ({self$lon}, {self$lat})")
      cli::cli_text("Year: {self$year}")
      cli::cli_text("Format: {self$format}")
      cli::cli_text("Available: {self$is_available()}")
      invisible(self)
    }
  ),

  private = list(
    load_npy_embedding = function() {
      # Load quantized embedding
      quantized <- read_npy(self$path)
      scales <- read_npy(self$scales_path)

      # Dequantize - scales can be per-channel (128-vector) or per-pixel (H x W matrix)
      dequantize_embedding(quantized, scales)
    },

    load_geotiff_embedding = function() {
      r <- terra::rast(self$path)
      values <- terra::values(r)

      # Reshape to (height, width, channels)
      dims <- c(terra::nrow(r), terra::ncol(r), terra::nlyr(r))
      array(values, dim = dims)
    },

    load_zarr_embedding = function() {
      # Note: Full zarr support in R is limited; this is a basic implementation
      # For production use, consider using reticulate to call Python zarr
      cli::cli_warn("Zarr support is experimental in R")

      zarr_array_path <- fs::path(self$path, "embedding", ".zarray")
      if (!fs::file_exists(zarr_array_path)) {
        cli::cli_abort("Invalid Zarr archive: missing .zarray")
      }

      # Read metadata
      meta <- jsonlite::read_json(zarr_array_path)
      shape <- unlist(meta$shape)
      dtype <- meta$dtype
      chunks <- unlist(meta$chunks)

      # Read chunk file (assuming single chunk for embedding data)
      chunk_file <- fs::path(self$path, "embedding", "0.0.0")
      if (!fs::file_exists(chunk_file)) {
        chunk_file <- fs::path(self$path, "embedding", "0")
      }

      if (fs::file_exists(chunk_file)) {
        raw_data <- readBin(chunk_file, "raw", fs::file_size(chunk_file))
        # Decompress if needed and convert based on dtype
        # This is simplified; full implementation would handle compression
        data <- readBin(raw_data, "double", prod(shape))
        array(data, dim = shape)
      } else {
        cli::cli_abort("Could not find Zarr chunk data")
      }
    }
  )
)

#' Create Tile from NPY files
#'
#' @param embedding_path Path to embedding .npy file
#' @param base_dir Base directory containing the tile structure
#' @return Tile object
#' @export
tile_from_npy <- function(embedding_path, base_dir = NULL) {
  # Parse coordinates from path
  coords <- parse_grid_name(embedding_path)

  # Extract year from path
  path_parts <- fs::path_split(embedding_path)[[1]]
  year_idx <- which(grepl("^[0-9]{4}$", path_parts))
  year <- if (length(year_idx) > 0) as.integer(path_parts[year_idx[1]]) else NA_integer_

  # Find scales file
  scales_path <- sub("\\.npy$", "_scales.npy", embedding_path)
  if (!fs::file_exists(scales_path)) {
    scales_path <- NULL
  }

  # Find landmask
  landmask_path <- NULL
  if (!is.null(base_dir)) {
    landmask_file <- tile_to_landmask_filename(coords$lon, coords$lat)
    potential_path <- fs::path(base_dir, "global_0.1_degree_tiff_all", landmask_file)
    if (fs::file_exists(potential_path)) {
      landmask_path <- potential_path
    }
  }

  Tile$new(
    lon = coords$lon,
    lat = coords$lat,
    year = year,
    format = "npy",
    path = embedding_path,
    scales_path = scales_path,
    landmask_path = landmask_path
  )
}

#' Create Tile from GeoTIFF file
#'
#' @param geotiff_path Path to GeoTIFF file
#' @return Tile object
#' @export
tile_from_geotiff <- function(geotiff_path) {
  # Parse coordinates from filename
  filename <- fs::path_file(geotiff_path)
  coords <- parse_grid_name(filename)

  # Extract year from path or filename
  path_parts <- fs::path_split(geotiff_path)[[1]]
  year_match <- regmatches(path_parts, regexec("geotessera_([0-9]{4})", path_parts))
  year <- NA_integer_
  for (m in year_match) {
    if (length(m) > 1) {
      year <- as.integer(m[2])
      break
    }
  }

  Tile$new(
    lon = coords$lon,
    lat = coords$lat,
    year = year,
    format = "geotiff",
    path = geotiff_path
  )
}

#' Create Tile from Zarr archive
#'
#' @param zarr_path Path to Zarr directory
#' @return Tile object
#' @export
tile_from_zarr <- function(zarr_path) {
  # Parse coordinates from directory name
  dirname <- fs::path_file(zarr_path)
  dirname <- sub("\\.zarr$", "", dirname)
  coords <- parse_grid_name(dirname)

  # Extract year from path
  path_parts <- fs::path_split(zarr_path)[[1]]
  year_match <- regmatches(path_parts, regexec("geotessera_([0-9]{4})", path_parts))
  year <- NA_integer_
  for (m in year_match) {
    if (length(m) > 1) {
      year <- as.integer(m[2])
      break
    }
  }

  Tile$new(
    lon = coords$lon,
    lat = coords$lat,
    year = year,
    format = "zarr",
    path = zarr_path
  )
}

#' Discover tiles in a directory
#'
#' Auto-detects format and finds all tile files.
#'
#' @param directory Directory to search
#' @param format Specific format to look for (NULL for auto-detect)
#' @return List of Tile objects
#' @export
discover_tiles <- function(directory, format = NULL) {
  if (!fs::dir_exists(directory)) {
    cli::cli_abort("Directory does not exist: {directory}")
  }

  tiles <- list()

  # NPY format
  if (is.null(format) || format == "npy") {
    npy_files <- fs::dir_ls(directory, recurse = TRUE, glob = "*.npy")
    # Filter out scales files
    npy_files <- npy_files[!grepl("_scales\\.npy$", npy_files)]
    # Filter to only grid files
    npy_files <- npy_files[grepl("grid_-?[0-9]+\\.[0-9]+_-?[0-9]+\\.[0-9]+\\.npy$", npy_files)]

    for (f in npy_files) {
      tryCatch({
        tiles[[length(tiles) + 1]] <- tile_from_npy(f, directory)
      }, error = function(e) {
        cli::cli_warn("Could not parse NPY file: {f}")
      })
    }
  }

  # GeoTIFF format
  if (is.null(format) || format == "geotiff") {
    tiff_files <- fs::dir_ls(directory, recurse = TRUE, glob = "*.tif")
    tiff_files <- c(tiff_files, fs::dir_ls(directory, recurse = TRUE, glob = "*.tiff"))
    # Filter to grid files (exclude landmasks which are in global_0.1_degree_tiff_all)
    tiff_files <- tiff_files[grepl("grid_-?[0-9]+\\.[0-9]+_-?[0-9]+\\.[0-9]+\\.(tif|tiff)$", tiff_files)]
    tiff_files <- tiff_files[!grepl("global_0\\.1_degree_tiff_all", tiff_files)]

    for (f in tiff_files) {
      tryCatch({
        tiles[[length(tiles) + 1]] <- tile_from_geotiff(f)
      }, error = function(e) {
        cli::cli_warn("Could not parse GeoTIFF file: {f}")
      })
    }
  }

  # Zarr format
  if (is.null(format) || format == "zarr") {
    zarr_dirs <- fs::dir_ls(directory, recurse = TRUE, type = "directory")
    zarr_dirs <- zarr_dirs[grepl("\\.zarr$", zarr_dirs)]

    for (d in zarr_dirs) {
      tryCatch({
        tiles[[length(tiles) + 1]] <- tile_from_zarr(d)
      }, error = function(e) {
        cli::cli_warn("Could not parse Zarr archive: {d}")
      })
    }
  }

  tiles
}

#' Discover tiles by format
#'
#' Returns a named list with tiles organized by format.
#'
#' @param directory Directory to search
#' @return Named list with "npy", "geotiff", and "zarr" elements
#' @export
discover_formats <- function(directory) {
  list(
    npy = discover_tiles(directory, "npy"),
    geotiff = discover_tiles(directory, "geotiff"),
    zarr = discover_tiles(directory, "zarr")
  )
}
