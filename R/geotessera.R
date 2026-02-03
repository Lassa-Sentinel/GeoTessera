#' @title GeoTessera Class
#' @description Main interface for downloading and exporting Tessera embeddings.
#'   This R6 class provides methods for downloading tiles, exporting GeoTIFFs,
#'   and sampling embeddings at specific points.
#'   Use \code{GeoTessera$new()} to create a new instance, or the convenience
#'   function \code{\link{geotessera}}.
#' @name GeoTessera
#' @export
GeoTessera <- R6::R6Class(
  "GeoTessera",
  public = list(
    #' @field registry Registry object for metadata and downloads
    registry = NULL,
    #' @field version Dataset version
    version = NULL,

    #' @description Create a new GeoTessera object
    #' @param dataset_version Dataset version (default "v1")
    #' @param cache_dir Directory for caching
    #' @param embeddings_dir Directory for storing embeddings
    #' @param registry_url URL for registry
    #' @param registry_path Local registry path
    #' @param registry_dir Local registry directory
    #' @param verify_hashes Verify SHA256 hashes
    #' @return A new GeoTessera object
    initialize = function(dataset_version = "v1",
                          cache_dir = NULL,
                          embeddings_dir = NULL,
                          registry_url = NULL,
                          registry_path = NULL,
                          registry_dir = NULL,
                          verify_hashes = TRUE) {
      self$version <- dataset_version

      self$registry <- Registry$new(
        version = dataset_version,
        cache_dir = cache_dir,
        embeddings_dir = embeddings_dir,
        registry_url = registry_url,
        registry_path = registry_path,
        registry_dir = registry_dir,
        verify_hashes = verify_hashes
      )
    },

    #' @description Count embeddings available in a bounding box
    #' @param bbox Bounding box (sf bbox, list, or numeric vector)
    #' @param year Integer year
    #' @return Integer count
    embeddings_count = function(bbox, year) {
      self$registry$embeddings_count(bbox, year)
    },

    #' @description Get tiles for a region
    #' @param bbox Bounding box
    #' @param year Integer year
    #' @param progress Show progress
    #' @return Data frame of tile metadata
    get_tiles = function(bbox, year, progress = TRUE) {
      self$registry$load_tiles_for_region(bbox, year, progress)
    },

    #' @description Download a single tile
    #' @param lon Tile longitude
    #' @param lat Tile latitude
    #' @param year Integer year
    #' @param progress Show progress
    #' @return Tile object
    download_tile = function(lon, lat, year, progress = TRUE) {
      # Get tile metadata
      tile_coords <- tile_from_world(lon, lat)
      tiles_df <- self$get_tiles(
        list(
          xmin = tile_coords$tile_lon - 0.01,
          ymin = tile_coords$tile_lat - 0.01,
          xmax = tile_coords$tile_lon + 0.01,
          ymax = tile_coords$tile_lat + 0.01
        ),
        year,
        progress = FALSE
      )

      if (nrow(tiles_df) == 0) {
        cli::cli_abort("No tile found at ({lon}, {lat}) for year {year}")
      }

      tile_info <- tiles_df[1, ]

      # Download embedding and scales
      embedding_path <- self$registry$fetch(
        year = year,
        lon = tile_info$lon,
        lat = tile_info$lat,
        is_scales = FALSE,
        expected_hash = tile_info$embedding_hash,
        progress = progress
      )

      scales_path <- self$registry$fetch(
        year = year,
        lon = tile_info$lon,
        lat = tile_info$lat,
        is_scales = TRUE,
        expected_hash = tile_info$scales_hash,
        progress = progress
      )

      Tile$new(
        lon = tile_info$lon,
        lat = tile_info$lat,
        year = year,
        format = "npy",
        path = embedding_path,
        scales_path = scales_path
      )
    },

    #' @description Fetch embedding for a single location
    #' @param lon Longitude
    #' @param lat Latitude
    #' @param year Integer year
    #' @return Named list with embedding (array), crs, and transform
    fetch_embedding = function(lon, lat, year) {
      tile <- self$download_tile(lon, lat, year, progress = FALSE)
      embedding <- tile$load_embedding()

      list(
        embedding = embedding,
        crs = tile$get_crs(),
        transform = tile$get_transform()
      )
    },

    #' @description Fetch embeddings for multiple tiles
    #' @param tiles Data frame of tiles to fetch
    #' @param progress Show progress
    #' @return Generator function that yields Tile objects
    fetch_embeddings = function(tiles, progress = TRUE) {
      i <- 0
      n <- nrow(tiles)

      if (progress) {
        cli::cli_progress_bar("Fetching embeddings", total = n)
      }

      function() {
        i <<- i + 1
        if (i > n) {
          if (progress) cli::cli_progress_done()
          return(NULL)
        }

        tile_info <- tiles[i, ]
        tile <- self$download_tile(
          tile_info$lon,
          tile_info$lat,
          tile_info$year,
          progress = FALSE
        )

        if (progress) cli::cli_progress_update()
        tile
      }
    },

    #' @description Download tiles for a list of points
    #' @param points Data frame with lon and lat columns
    #' @param year Integer year
    #' @param progress Show progress
    #' @return List of Tile objects
    download_tiles_for_points = function(points, year, progress = TRUE) {
      # Get unique tiles for all points
      unique_tiles <- unique(lapply(seq_len(nrow(points)), function(i) {
        tile_from_world(points$lon[i], points$lat[i])
      }))

      tiles_df <- do.call(rbind, lapply(unique_tiles, function(t) {
        data.frame(lon = t$tile_lon, lat = t$tile_lat, year = year)
      }))
      tiles_df <- unique(tiles_df)

      if (progress) {
        cli::cli_progress_bar("Downloading tiles", total = nrow(tiles_df))
      }

      tiles <- list()
      for (i in seq_len(nrow(tiles_df))) {
        tile <- self$download_tile(
          tiles_df$lon[i],
          tiles_df$lat[i],
          tiles_df$year[i],
          progress = FALSE
        )
        tiles[[length(tiles) + 1]] <- tile

        if (progress) cli::cli_progress_update()
      }

      if (progress) cli::cli_progress_done()
      tiles
    },

    #' @description Check which tiles are present for a set of points
    #' @param points Data frame with lon and lat columns
    #' @param year Integer year
    #' @return Data frame with lon, lat, tile_lon, tile_lat, available columns
    check_tiles_present = function(points, year) {
      results <- lapply(seq_len(nrow(points)), function(i) {
        tile_coords <- tile_from_world(points$lon[i], points$lat[i])
        grid_name <- tile_to_grid_name(tile_coords$tile_lon, tile_coords$tile_lat)

        # Check if files exist locally
        embedding_path <- fs::path(
          self$registry$embeddings_dir,
          "global_0.1_degree_representation",
          year,
          grid_name,
          paste0(grid_name, ".npy")
        )

        data.frame(
          lon = points$lon[i],
          lat = points$lat[i],
          tile_lon = tile_coords$tile_lon,
          tile_lat = tile_coords$tile_lat,
          available = fs::file_exists(embedding_path)
        )
      })

      do.call(rbind, results)
    },

    #' @description Sample embeddings at specific points
    #' @param points Data frame with lon and lat columns
    #' @param year Integer year
    #' @param download Download missing tiles
    #' @param progress Show progress
    #' @return Data frame with lon, lat, and embedding_1 through embedding_128 columns
    sample_embeddings_at_points = function(points, year, download = TRUE,
                                            progress = TRUE) {
      if (download) {
        tiles <- self$download_tiles_for_points(points, year, progress)
      } else {
        # Use existing tiles
        tiles <- discover_tiles(self$registry$embeddings_dir, "npy")
      }

      # Create lookup by tile coordinates
      tile_lookup <- list()
      for (tile in tiles) {
        key <- sprintf("%.2f_%.2f", tile$lon, tile$lat)
        tile_lookup[[key]] <- tile
      }

      # Sample each point
      if (progress) {
        cli::cli_progress_bar("Sampling points", total = nrow(points))
      }

      results <- lapply(seq_len(nrow(points)), function(i) {
        pt_lon <- points$lon[i]
        pt_lat <- points$lat[i]
        tile_coords <- tile_from_world(pt_lon, pt_lat)
        key <- sprintf("%.2f_%.2f", tile_coords$tile_lon, tile_coords$tile_lat)

        tile <- tile_lookup[[key]]
        if (is.null(tile) || !tile$is_available()) {
          embedding <- rep(NA_real_, EMBEDDING_CHANNELS)
        } else {
          tryCatch({
            embedding <- tile$sample_at_point(pt_lon, pt_lat)
          }, error = function(e) {
            embedding <- rep(NA_real_, EMBEDDING_CHANNELS)
          })
        }

        if (progress) cli::cli_progress_update()
        c(lon = pt_lon, lat = pt_lat, embedding)
      })

      if (progress) cli::cli_progress_done()

      result_df <- as.data.frame(do.call(rbind, results))
      colnames(result_df) <- c("lon", "lat", paste0("embedding_", seq_len(EMBEDDING_CHANNELS)))
      result_df
    },

    #' @description Export a single tile as GeoTIFF
    #' @param lon Tile longitude
    #' @param lat Tile latitude
    #' @param year Integer year
    #' @param output_path Output file path
    #' @param bands Which bands to include (NULL for all 128)
    #' @param compress Compression type ("lzw", "deflate", "none")
    #' @return Output file path
    export_embedding_geotiff = function(lon, lat, year, output_path,
                                         bands = NULL, compress = "lzw") {
      tile <- self$download_tile(lon, lat, year, progress = FALSE)
      embedding <- tile$load_embedding()

      # Select bands
      if (!is.null(bands)) {
        embedding <- embedding[, , bands, drop = FALSE]
      }

      # Get UTM CRS for the tile
      epsg <- get_utm_epsg(lon, lat)
      utm_crs <- sf::st_crs(epsg)

      # Create raster
      bounds <- tile$get_bounds()
      dims <- dim(embedding)

      # Create SpatRaster from array
      # terra expects (nrow, ncol, nlyr) = (height, width, bands)
      r <- terra::rast(
        nrows = dims[1],
        ncols = dims[2],
        nlyrs = dims[3],
        xmin = bounds$xmin,
        xmax = bounds$xmax,
        ymin = bounds$ymin,
        ymax = bounds$ymax,
        crs = "EPSG:4326"
      )

      # Set values (terra expects column-major, so we need to handle the array correctly)
      for (lyr in seq_len(dims[3])) {
        terra::values(r[[lyr]]) <- as.vector(t(embedding[, , lyr]))
      }

      # Set band names
      if (!is.null(bands)) {
        names(r) <- paste0("band_", bands)
      } else {
        names(r) <- paste0("band_", seq_len(dims[3]))
      }

      # Project to UTM
      r_utm <- terra::project(r, paste0("EPSG:", epsg))

      # Write with compression
      gdal_opts <- switch(
        compress,
        "lzw" = c("COMPRESS=LZW"),
        "deflate" = c("COMPRESS=DEFLATE"),
        "none" = NULL,
        c("COMPRESS=LZW")
      )

      fs::dir_create(fs::path_dir(output_path))
      terra::writeRaster(r_utm, output_path, overwrite = TRUE, gdal = gdal_opts)
      output_path
    },

    #' @description Export multiple tiles as GeoTIFFs
    #' @param tiles Data frame of tiles to export
    #' @param output_dir Output directory
    #' @param bands Which bands to include (NULL for all)
    #' @param compress Compression type
    #' @param progress Show progress
    #' @return Character vector of output file paths
    export_embedding_geotiffs = function(tiles, output_dir, bands = NULL,
                                          compress = "lzw", progress = TRUE) {
      fs::dir_create(output_dir)

      if (progress) {
        cli::cli_progress_bar("Exporting GeoTIFFs", total = nrow(tiles))
      }

      paths <- character(nrow(tiles))
      for (i in seq_len(nrow(tiles))) {
        tile <- tiles[i, ]
        output_path <- fs::path(
          output_dir,
          paste0(tile_to_grid_name(tile$lon, tile$lat), ".tif")
        )

        paths[i] <- self$export_embedding_geotiff(
          tile$lon, tile$lat, tile$year,
          output_path, bands, compress
        )

        if (progress) cli::cli_progress_update()
      }

      if (progress) cli::cli_progress_done()
      paths
    },

    #' @description Fetch a mosaic of embeddings for a region
    #' @param bbox Bounding box
    #' @param year Integer year
    #' @param bands Which bands to include (NULL for all)
    #' @param progress Show progress
    #' @return SpatRaster object
    fetch_mosaic_for_region = function(bbox, year, bands = NULL, progress = TRUE) {
      tiles_df <- self$get_tiles(bbox, year, progress = FALSE)

      if (nrow(tiles_df) == 0) {
        cli::cli_abort("No tiles found in the specified region")
      }

      # Export to temp directory and merge
      temp_dir <- tempfile("geotessera_mosaic_")
      on.exit(unlink(temp_dir, recursive = TRUE))

      paths <- self$export_embedding_geotiffs(
        tiles_df, temp_dir, bands, "none", progress
      )

      # Create mosaic
      rasters <- lapply(paths, terra::rast)
      if (length(rasters) == 1) {
        return(rasters[[1]])
      }

      # Merge all rasters
      mosaic <- do.call(terra::merge, rasters)
      mosaic
    },

    #' @description Apply PCA to embeddings
    #' @param embeddings 3D array (height, width, channels) or 2D (pixels, channels)
    #' @param n_components Number of PCA components
    #' @return Array with reduced dimensions
    apply_pca_to_embeddings = function(embeddings, n_components = 3) {
      dims <- dim(embeddings)

      if (length(dims) == 3) {
        # Reshape to 2D
        data_2d <- matrix(embeddings, nrow = dims[1] * dims[2], ncol = dims[3])
      } else {
        data_2d <- embeddings
      }

      # Remove rows with NAs
      valid_rows <- complete.cases(data_2d)
      if (sum(valid_rows) < n_components) {
        cli::cli_abort("Not enough valid pixels for PCA")
      }

      # Run PCA
      pca_result <- prcomp(data_2d[valid_rows, ], center = TRUE, scale. = TRUE,
                           rank. = n_components)

      # Project all data
      pca_scores <- matrix(NA_real_, nrow = nrow(data_2d), ncol = n_components)
      pca_scores[valid_rows, ] <- predict(pca_result, data_2d[valid_rows, ])

      if (length(dims) == 3) {
        # Reshape back to 3D
        array(pca_scores, dim = c(dims[1], dims[2], n_components))
      } else {
        pca_scores
      }
    },

    #' @description Export tiles with PCA reduction
    #' @param tiles Data frame of tiles
    #' @param output_dir Output directory
    #' @param n_components Number of PCA components
    #' @param progress Show progress
    #' @return Character vector of output paths
    export_pca_geotiffs = function(tiles, output_dir, n_components = 3,
                                    progress = TRUE) {
      fs::dir_create(output_dir)

      if (progress) {
        cli::cli_progress_bar("Exporting PCA GeoTIFFs", total = nrow(tiles))
      }

      paths <- character(nrow(tiles))
      for (i in seq_len(nrow(tiles))) {
        tile_info <- tiles[i, ]
        tile <- self$download_tile(
          tile_info$lon, tile_info$lat, tile_info$year,
          progress = FALSE
        )
        embedding <- tile$load_embedding()

        # Apply PCA
        pca_embedding <- self$apply_pca_to_embeddings(embedding, n_components)

        # Create raster
        bounds <- tile$get_bounds()
        dims <- dim(pca_embedding)

        r <- terra::rast(
          nrows = dims[1],
          ncols = dims[2],
          nlyrs = dims[3],
          xmin = bounds$xmin,
          xmax = bounds$xmax,
          ymin = bounds$ymin,
          ymax = bounds$ymax,
          crs = "EPSG:4326"
        )

        for (lyr in seq_len(dims[3])) {
          terra::values(r[[lyr]]) <- as.vector(t(pca_embedding[, , lyr]))
        }
        names(r) <- paste0("PC", seq_len(dims[3]))

        output_path <- fs::path(
          output_dir,
          paste0(tile_to_grid_name(tile_info$lon, tile_info$lat), "_pca.tif")
        )

        terra::writeRaster(r, output_path, overwrite = TRUE)
        paths[i] <- output_path

        if (progress) cli::cli_progress_update()
      }

      if (progress) cli::cli_progress_done()
      paths
    },

    #' @description Merge GeoTIFFs into a single mosaic
    #' @param input_dir Directory containing GeoTIFFs
    #' @param output_path Output file path
    #' @param nodata_value NoData value (default 0)
    #' @return Output file path
    merge_geotiffs_to_mosaic = function(input_dir, output_path, nodata_value = 0) {
      tiff_files <- fs::dir_ls(input_dir, glob = "*.tif")
      if (length(tiff_files) == 0) {
        tiff_files <- fs::dir_ls(input_dir, glob = "*.tiff")
      }

      if (length(tiff_files) == 0) {
        cli::cli_abort("No GeoTIFF files found in {input_dir}")
      }

      rasters <- lapply(tiff_files, terra::rast)

      if (length(rasters) == 1) {
        terra::writeRaster(rasters[[1]], output_path, overwrite = TRUE)
      } else {
        mosaic <- do.call(terra::merge, rasters)
        terra::writeRaster(mosaic, output_path, overwrite = TRUE, NAflag = nodata_value)
      }

      output_path
    },

    #' @description Export coverage map
    #' @param output_file Output JSON file path
    #' @return Named list with coverage statistics
    export_coverage_map = function(output_file = NULL) {
      years <- self$registry$get_available_years()
      counts <- self$registry$get_tile_counts_by_year()

      coverage <- list(
        version = self$version,
        available_years = years,
        tile_counts = as.list(counts),
        total_tiles = sum(counts)
      )

      if (!is.null(output_file)) {
        jsonlite::write_json(coverage, output_file, auto_unbox = TRUE, pretty = TRUE)
      }

      coverage
    },

    #' @description Summarize embeddings for a geographic region

    #'
    #' Downloads embeddings for a region to a temporary location, applies

    #' summary functions, and cleans up automatically. Useful for processing
    #' large regions where only summary statistics are needed.
    #'
    #' @param region Bounding box (numeric vector, list, or sf bbox) or
    #'   sf/sfc object (e.g., from a shapefile). For sf objects, the bounding
    #'   box is used for tile selection, and pixels are masked to the geometry.
    #' @param year Integer year
    #' @param summary_fns Named list of summary functions. Each function should
    #'   accept parameters: embeddings (list of 3D arrays), region (the input
    #'   region), tiles_df (tile metadata). Some functions also accept gt and
    #'   year for sampling operations. Default includes mean, centroid, and
    #'   pixel_count summaries.
    #' @param mask_to_region Logical; if TRUE and region is an sf object,
    #'   pixels outside the geometry are set to NA before summarization.
    #'   Default TRUE.
    #' @param progress Show progress bars. Default TRUE.
    #' @param keep_tiles Logical; if TRUE, returns the downloaded Tile objects

    #'   along with summaries (tiles are NOT cleaned up). Default FALSE.
    #' @return Named list containing:
    #'   \itemize{
    #'     \item{summaries: Named list of summary results (one per summary_fn)}
    #'     \item{metadata: List with region info, year, n_tiles, processing time}
    #'     \item{tiles: (only if keep_tiles=TRUE) List of Tile objects}
    #'   }
    #' @examples
    #' \dontrun{
    #' gt <- geotessera()
    #'
    #' # Basic usage with bounding box
    #' result <- gt$summarize_region(
    #'   region = c(0.08, 52.18, 0.15, 52.21),
    #'   year = 2024
    #' )
    #' print(result$summaries$mean)
    #'
    #' # With sf object from shapefile
    #' library(sf)
    #' shape <- st_read("my_region.shp")
    #' result <- gt$summarize_region(region = shape, year = 2024)
    #'
    #' # Custom summary functions
    #' my_summary <- function(embeddings, region, tiles_df) {
    #'   # Custom computation
    #'   colMeans(do.call(rbind, lapply(embeddings, function(e) {
    #'     apply(e, 3, mean, na.rm = TRUE)
    #'   })))
    #' }
    #'
    #' result <- gt$summarize_region(
    #'   region = bbox,
    #'   year = 2024,
    #'   summary_fns = list(
    #'     mean = summary_mean,
    #'     custom = my_summary,
    #'     quantiles = summary_quantile(c(0.1, 0.9))
    #'   )
    #' )
    #' }
    summarize_region = function(region,
                                 year,
                                 summary_fns = NULL,
                                 mask_to_region = TRUE,
                                 progress = TRUE,
                                 keep_tiles = FALSE) {
      start_time <- Sys.time()

      # Default summary functions
      if (is.null(summary_fns)) {
        summary_fns <- list(
          mean = summary_mean,
          centroid = summary_centroid,
          coverage = summary_coverage
        )
      }

      # Extract bbox from region
      if (inherits(region, "sf") || inherits(region, "sfc")) {
        bbox <- sf::st_bbox(region)
        is_spatial <- TRUE
      } else {
        bbox <- region
        is_spatial <- FALSE
      }

      # Get tiles for the region
      tiles_df <- self$get_tiles(bbox, year, progress = FALSE)

      if (nrow(tiles_df) == 0) {
        cli::cli_abort("No tiles found for the specified region and year")
      }

      if (progress) {
        cli::cli_alert_info("Found {nrow(tiles_df)} tile{?s} for region")
      }

      # Create temp directory for downloads
      temp_dir <- withr::local_tempdir(pattern = "geotessera_summarize_")

      # Store original embeddings_dir and temporarily change it
      original_embeddings_dir <- self$registry$embeddings_dir
      self$registry$embeddings_dir <- temp_dir

      # Ensure cleanup on exit
      on.exit({
        self$registry$embeddings_dir <- original_embeddings_dir
        if (!keep_tiles) {
          # Temp dir is automatically cleaned by withr::local_tempdir
          if (progress) {
            cli::cli_alert_success("Cleaned up temporary files")
          }
        }
      }, add = TRUE)

      # Download tiles
      if (progress) {
        cli::cli_progress_bar("Downloading tiles", total = nrow(tiles_df))
      }

      tiles <- list()
      embeddings <- list()

      for (i in seq_len(nrow(tiles_df))) {
        tile_info <- tiles_df[i, ]

        tryCatch({
          tile <- self$download_tile(
            tile_info$lon,
            tile_info$lat,
            year,
            progress = FALSE
          )
          tiles[[length(tiles) + 1]] <- tile
          embeddings[[length(embeddings) + 1]] <- tile$load_embedding()
        }, error = function(e) {
          cli::cli_warn("Failed to download tile at ({tile_info$lon}, {tile_info$lat}): {e$message}")
        })

        if (progress) cli::cli_progress_update()
      }

      if (progress) cli::cli_progress_done()

      if (length(embeddings) == 0) {
        cli::cli_abort("No tiles could be downloaded successfully")
      }

      # Apply spatial mask if needed
      if (is_spatial && mask_to_region) {
        if (progress) {
          cli::cli_alert_info("Masking embeddings to region geometry")
        }
        embeddings <- mask_embeddings_to_region(embeddings, tiles, region)
      }

      # Apply summary functions
      if (progress) {
        cli::cli_alert_info("Computing {length(summary_fns)} summary statistic{?s}")
      }

      summaries <- list()
      for (name in names(summary_fns)) {
        fn <- summary_fns[[name]]

        # Check if function needs extra parameters (gt, year)
        fn_args <- names(formals(fn))

        tryCatch({
          if ("gt" %in% fn_args && "year" %in% fn_args) {
            summaries[[name]] <- fn(
              embeddings = embeddings,
              region = region,
              tiles_df = tiles_df,
              gt = self,
              year = year
            )
          } else {
            summaries[[name]] <- fn(
              embeddings = embeddings,
              region = region,
              tiles_df = tiles_df
            )
          }
        }, error = function(e) {
          cli::cli_warn("Summary function '{name}' failed: {e$message}")
          summaries[[name]] <<- NULL
        })
      }

      end_time <- Sys.time()

      # Build result
      # Convert bbox to standard format for metadata
      if (is_spatial) {
        region_bbox <- as.vector(sf::st_bbox(region))
      } else {
        bounds <- format_bbox_to_list(bbox)
        region_bbox <- c(bounds$xmin, bounds$ymin, bounds$xmax, bounds$ymax)
      }

      result <- list(
        summaries = summaries,
        metadata = list(
          region_bbox = region_bbox,
          year = year,
          n_tiles = length(tiles),
          n_tiles_requested = nrow(tiles_df),
          is_masked = is_spatial && mask_to_region,
          processing_time_secs = as.numeric(difftime(end_time, start_time, units = "secs")),
          summary_functions = names(summary_fns)
        )
      )

      if (keep_tiles) {
        result$tiles <- tiles
        # Prevent temp dir cleanup if keeping tiles
        self$registry$embeddings_dir <- temp_dir
      }

      if (progress) {
        cli::cli_alert_success(
          "Processed {length(tiles)} tiles in {round(result$metadata$processing_time_secs, 1)}s"
        )
      }

      result
    },

    #' @description Summarize a large region using streaming (memory efficient)
    #'
    #' Processes tiles one at a time using Welford's online algorithm for

    #' computing the mean, avoiding memory issues with large regions.
    #'
    #' @param region Bounding box or sf object
    #' @param year Integer year
    #' @param sample_rate Fraction of pixels to sample (0-1). Use lower values
    #'   for very large regions. Default 1.0.
    #' @param mask_to_region If TRUE and region is sf, only include pixels
    #'   inside the polygon. Default TRUE.
    #' @param seed Random seed for reproducible sampling
    #' @param progress Show progress. Default TRUE.
    #' @return Named list with mean embedding, pixel count, and metadata
    #' @examples
    #' \dontrun{
    #' gt <- geotessera()
    #' # For large regions, use streaming approach
    #' result <- gt$summarize_region_streaming(
    #'   region = large_polygon,
    #'   year = 2024,
    #'   sample_rate = 0.1
    #' )
    #' }
    summarize_region_streaming = function(region, year, sample_rate = 1.0,
                                           mask_to_region = TRUE, seed = NULL,
                                           progress = TRUE) {
      start_time <- Sys.time()

      # Extract bbox from region
      if (inherits(region, "sf") || inherits(region, "sfc")) {
        bbox <- sf::st_bbox(region)
        mask_region <- if (mask_to_region) region else NULL
      } else {
        bbox <- region
        mask_region <- NULL
      }

      # Get tiles
      tiles_df <- self$get_tiles(bbox, year, progress = FALSE)

      if (nrow(tiles_df) == 0) {
        cli::cli_abort("No tiles found for the specified region and year")
      }

      if (progress) {
        cli::cli_alert_info("Processing {nrow(tiles_df)} tiles with streaming algorithm")
        if (sample_rate < 1.0) {
          cli::cli_alert_info("Sampling {sample_rate * 100}% of pixels")
        }
      }

      # Use streaming mean computation
      result <- summary_mean_streaming(
        gt = self,
        tiles_df = tiles_df,
        year = year,
        region = mask_region,
        sample_rate = sample_rate,
        seed = seed,
        progress = progress
      )

      end_time <- Sys.time()

      list(
        mean = result$mean,
        n_pixels = result$n_pixels,
        metadata = list(
          year = year,
          n_tiles = nrow(tiles_df),
          sample_rate = sample_rate,
          is_masked = !is.null(mask_region),
          processing_time_secs = as.numeric(difftime(end_time, start_time, units = "secs"))
        )
      )
    },

    #' @description Print summary of GeoTessera object
    print = function() {
      cli::cli_h1("GeoTessera")
      cli::cli_text("Version: {self$version}")
      cli::cli_text("Cache directory: {self$registry$cache_dir}")
      cli::cli_text("Embeddings directory: {self$registry$embeddings_dir}")
      cli::cli_text("Hash verification: {self$registry$verify_hashes}")

      tryCatch({
        years <- self$registry$get_available_years()
        if (length(years) > 0) {
          cli::cli_text("Available years: {paste(years, collapse = ', ')}")
        }
      }, error = function(e) {
        cli::cli_text("Available years: (unable to load registry)")
      })

      invisible(self)
    }
  )
)

#' Create a GeoTessera client
#'
#' Convenience function to create a new GeoTessera object.
#'
#' @param ... Arguments passed to GeoTessera$new()
#' @return GeoTessera object
#' @rdname GeoTessera
#' @export
#' @examples
#' \dontrun{
#' gt <- geotessera()
#' tiles <- gt$get_tiles(bbox = c(-0.2, 51.4, 0.1, 51.6), year = 2024)
#' }
geotessera <- function(...) {
  GeoTessera$new(...)
}
