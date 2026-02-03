#' @title Registry Class for Tessera Tile Metadata
#' @description Manages Parquet registry and HTTP downloads of Tessera data.
#' @name Registry
#' @export
Registry <- R6::R6Class(

  "Registry",
  public = list(
    #' @field version Dataset version (e.g., "v1")
    version = NULL,
    #' @field cache_dir Directory for caching registry files
    cache_dir = NULL,
    #' @field embeddings_dir Directory for storing embeddings
    embeddings_dir = NULL,
    #' @field registry_url Base URL for registry files
    registry_url = NULL,
    #' @field landmasks_registry_url Base URL for landmask registry files
    landmasks_registry_url = NULL,
    #' @field verify_hashes Whether to verify file hashes
    verify_hashes = TRUE,

    #' @description Create a new Registry object
    #' @param version Dataset version (default "v1")
    #' @param cache_dir Directory for caching (default: user cache dir)
    #' @param embeddings_dir Directory for embeddings (default: current dir)
    #' @param registry_url Base URL for registry (default: Tessera server)
    #' @param registry_path Local path to registry file (overrides URL)
    #' @param registry_dir Local directory containing registry files
    #' @param landmasks_registry_url URL for landmask registry
    #' @param landmasks_registry_path Local path to landmask registry
    #' @param verify_hashes Verify SHA256 hashes on downloads
    #' @return A new Registry object
    initialize = function(version = "v1",
                          cache_dir = NULL,
                          embeddings_dir = NULL,
                          registry_url = NULL,
                          registry_path = NULL,
                          registry_dir = NULL,
                          landmasks_registry_url = NULL,
                          landmasks_registry_path = NULL,
                          verify_hashes = TRUE) {
      self$version <- version
      self$cache_dir <- cache_dir %||% get_cache_dir()
      self$embeddings_dir <- embeddings_dir %||% getwd()
      self$verify_hashes <- verify_hashes

      # Set URLs
      base_url <- "https://dl2.geotessera.org"
      self$registry_url <- registry_url %||% sprintf("%s/%s", base_url, version)
      self$landmasks_registry_url <- landmasks_registry_url %||%
        sprintf("%s/%s/landmasks", base_url, version)

      # Store paths for local registry
      private$registry_path <- registry_path
      private$registry_dir <- registry_dir
      private$landmasks_registry_path <- landmasks_registry_path

      fs::dir_create(self$cache_dir)
      fs::dir_create(self$embeddings_dir)
    },

    #' @description Get tiles in a geographic region
    #' @param bbox Bounding box (sf bbox, named vector, or list with xmin, ymin, xmax, ymax)
    #' @param year Integer year
    #' @param progress Show progress
    #' @return Data frame of tile metadata
    load_tiles_for_region = function(bbox, year, progress = TRUE) {
      if (inherits(bbox, "bbox")) {
        bounds <- list(
          xmin = as.numeric(bbox["xmin"]),
          ymin = as.numeric(bbox["ymin"]),
          xmax = as.numeric(bbox["xmax"]),
          ymax = as.numeric(bbox["ymax"])
        )
      } else if (is.list(bbox)) {
        bounds <- bbox
      } else {
        bounds <- list(
          xmin = bbox[1], ymin = bbox[2],
          xmax = bbox[3], ymax = bbox[4]
        )
      }

      # Load the main registry (cached)
      registry <- private$get_main_registry()
      if (is.null(registry)) {
        cli::cli_warn("Could not load registry")
        return(data.frame(
          lon = numeric(), lat = numeric(), year = integer(),
          grid_name = character(), embedding_hash = character(),
          scales_hash = character(), embedding_size = integer(),
          scales_size = integer()
        ))
      }

      # Filter to year first
      tiles_df <- registry[registry$year == year, ]

      # Filter to bounding box using tile overlap (not center containment)
      # A tile overlaps the bbox if its bounds intersect the bbox.
      # Tile at center (lon, lat) covers [lon - 0.05, lon + 0.05] x [lat - 0.05, lat + 0.05]
      # Overlap test: (tile_max >= bbox_min) AND (tile_min <= bbox_max)
      # Use >= and <= to include tiles that share edges with the bbox
      tiles_df <- tiles_df[
        (tiles_df$lon + TILE_OFFSET) >= bounds$xmin &
          (tiles_df$lon - TILE_OFFSET) <= bounds$xmax &
          (tiles_df$lat + TILE_OFFSET) >= bounds$ymin &
          (tiles_df$lat - TILE_OFFSET) <= bounds$ymax,
      ]

      if (nrow(tiles_df) == 0) {
        return(data.frame(
          lon = numeric(), lat = numeric(), year = integer(),
          grid_name = character(), embedding_hash = character(),
          scales_hash = character(), embedding_size = integer(),
          scales_size = integer()
        ))
      }

      # Rename columns to match expected output format
      result <- data.frame(
        lon = tiles_df$lon,
        lat = tiles_df$lat,
        year = tiles_df$year,
        grid_name = paste0("grid_", sprintf("%.2f", tiles_df$lon), "_", sprintf("%.2f", tiles_df$lat)),
        embedding_hash = tiles_df$hash,
        scales_hash = if ("scales_hash" %in% names(tiles_df)) tiles_df$scales_hash else NA_character_,
        embedding_size = if ("file_size" %in% names(tiles_df)) tiles_df$file_size else NA_integer_,
        scales_size = if ("scales_size" %in% names(tiles_df)) tiles_df$scales_size else NA_integer_
      )

      result
    },

    #' @description Iterate over tiles in a region (lazy evaluation)
    #' @param bbox Bounding box
    #' @param year Integer year
    #' @return Iterator/generator function
    iter_tiles_in_region = function(bbox, year) {
      tiles_df <- self$load_tiles_for_region(bbox, year, progress = FALSE)

      # Return a function that yields tiles one at a time
      i <- 0
      function() {
        i <<- i + 1
        if (i > nrow(tiles_df)) {
          return(NULL)
        }
        as.list(tiles_df[i, ])
      }
    },

    #' @description Get available years in the registry
    #' @return Integer vector of years
    get_available_years = function() {
      # Download main registry to check available years
      registry <- private$get_main_registry()
      if (is.null(registry)) {
        return(integer())
      }
      sort(unique(registry$year))
    },

    #' @description Get tile counts by year
    #' @return Named integer vector
    get_tile_counts_by_year = function() {
      registry <- private$get_main_registry()
      if (is.null(registry)) {
        return(integer())
      }
      table(registry$year)
    },

    #' @description Count embeddings in a bounding box
    #' @param bbox Bounding box
    #' @param year Integer year
    #' @return Integer count
    embeddings_count = function(bbox, year) {
      tiles <- self$load_tiles_for_region(bbox, year, progress = FALSE)
      nrow(tiles)
    },

    #' @description Fetch an embedding file
    #' @param year Integer year
    #' @param lon Tile longitude
    #' @param lat Tile latitude
    #' @param is_scales Fetch scales file instead of embedding
    #' @param expected_hash Expected SHA256 hash
    #' @param progress Show progress
    #' @return Path to downloaded file
    fetch = function(year, lon, lat, is_scales = FALSE, expected_hash = NULL,
                     progress = TRUE) {
      grid_name <- tile_to_grid_name(lon, lat)
      suffix <- if (is_scales) "_scales.npy" else ".npy"
      filename <- paste0(grid_name, suffix)

      # Check local cache first
      local_path <- fs::path(
        self$embeddings_dir,
        "global_0.1_degree_representation",
        year,
        grid_name,
        filename
      )

      if (fs::file_exists(local_path)) {
        if (self$verify_hashes && !is.null(expected_hash)) {
          actual_hash <- calculate_file_hash(local_path)
          if (actual_hash == expected_hash) {
            return(local_path)
          }
        } else {
          return(local_path)
        }
      }

      # Download from remote
      url <- sprintf(
        "%s/global_0.1_degree_representation/%d/%s/%s",
        self$registry_url, year, grid_name, filename
      )

      fs::dir_create(fs::path_dir(local_path))

      hash_to_verify <- if (self$verify_hashes) expected_hash else NULL
      download_file(url, local_path, hash_to_verify, progress)
    },

    #' @description Fetch a landmask file
    #' @param lon Tile longitude
    #' @param lat Tile latitude
    #' @param expected_hash Expected SHA256 hash
    #' @param progress Show progress
    #' @return Path to downloaded file
    fetch_landmask = function(lon, lat, expected_hash = NULL, progress = TRUE) {
      filename <- tile_to_landmask_filename(lon, lat)

      # Check local cache
      local_path <- fs::path(
        self$embeddings_dir,
        "global_0.1_degree_tiff_all",
        filename
      )

      if (fs::file_exists(local_path)) {
        if (self$verify_hashes && !is.null(expected_hash)) {
          actual_hash <- calculate_file_hash(local_path)
          if (actual_hash == expected_hash) {
            return(local_path)
          }
        } else {
          return(local_path)
        }
      }

      # Download from remote
      url <- sprintf("%s/%s", self$landmasks_registry_url, filename)

      fs::dir_create(fs::path_dir(local_path))

      hash_to_verify <- if (self$verify_hashes) expected_hash else NULL
      download_file(url, local_path, hash_to_verify, progress)
    },

    #' @description Get file size for an embedding tile
    #' @param year Integer year
    #' @param lon Tile longitude
    #' @param lat Tile latitude
    #' @return Integer file size in bytes
    get_tile_file_size = function(year, lon, lat) {
      tiles <- self$load_tiles_for_region(
        list(xmin = lon - 0.01, ymin = lat - 0.01,
             xmax = lon + 0.01, ymax = lat + 0.01),
        year, progress = FALSE
      )
      if (nrow(tiles) == 0) return(NA_integer_)
      tiles$embedding_size[1]
    },

    #' @description Get file size for scales file
    #' @param year Integer year
    #' @param lon Tile longitude
    #' @param lat Tile latitude
    #' @return Integer file size in bytes
    get_scales_file_size = function(year, lon, lat) {
      tiles <- self$load_tiles_for_region(
        list(xmin = lon - 0.01, ymin = lat - 0.01,
             xmax = lon + 0.01, ymax = lat + 0.01),
        year, progress = FALSE
      )
      if (nrow(tiles) == 0) return(NA_integer_)
      tiles$scales_size[1]
    },

    #' @description Calculate download requirements for tiles

    #' @param tiles Data frame of tiles
    #' @param output_dir Output directory
    #' @param format Output format ("tiff", "zarr", "npy")
    #' @return Named list with total_size, tiles_to_download, tiles_existing
    calculate_download_requirements = function(tiles, output_dir, format = "tiff") {
      total_size <- 0
      tiles_to_download <- 0
      tiles_existing <- 0

      for (i in seq_len(nrow(tiles))) {
        tile <- tiles[i, ]

        # Check if output exists
        output_path <- switch(
          format,
          "tiff" = fs::path(output_dir, sprintf("grid_%.2f_%.2f.tif", tile$lon, tile$lat)),
          "zarr" = fs::path(output_dir, sprintf("grid_%.2f_%.2f.zarr", tile$lon, tile$lat)),
          "npy" = fs::path(output_dir, sprintf("grid_%.2f_%.2f.npy", tile$lon, tile$lat))
        )

        if (fs::file_exists(output_path)) {
          tiles_existing <- tiles_existing + 1
        } else {
          tiles_to_download <- tiles_to_download + 1
          total_size <- total_size +
            (tile$embedding_size %||% 0) +
            (tile$scales_size %||% 0)
        }
      }

      list(
        total_size = total_size,
        tiles_to_download = tiles_to_download,
        tiles_existing = tiles_existing
      )
    },

    #' @description Get manifest info (git hash and repo URL)
    #' @return Named list with git_hash and repo_url
    get_manifest_info = function() {
      manifest_url <- sprintf("%s/manifest.json", self$registry_url)
      manifest_path <- fs::path(self$cache_dir, "manifest.json")

      tryCatch({
        download_file(manifest_url, manifest_path, progress = FALSE)
        manifest <- jsonlite::read_json(manifest_path)
        list(
          git_hash = manifest$git_hash %||% NA_character_,
          repo_url = manifest$repo_url %||% NA_character_
        )
      }, error = function(e) {
        list(git_hash = NA_character_, repo_url = NA_character_)
      })
    },

    #' @description Get count of available landmasks
    #' @return Integer count
    get_landmask_count = function() {
      registry <- private$get_landmasks_registry()
      if (is.null(registry)) return(0L)
      nrow(registry)
    }
  ),

  private = list(
    registry_path = NULL,
    registry_dir = NULL,
    landmasks_registry_path = NULL,
    main_registry_cache = NULL,
    landmasks_registry_cache = NULL,

    # Get the main registry file
    get_main_registry = function() {
      if (!is.null(private$main_registry_cache)) {
        return(private$main_registry_cache)
      }

      # Try local path first
      if (!is.null(private$registry_path) && fs::file_exists(private$registry_path)) {
        private$main_registry_cache <- arrow::read_parquet(private$registry_path)
        return(private$main_registry_cache)
      }

      # Download from remote
      registry_file <- fs::path(self$cache_dir, "registry.parquet")

      if (!fs::file_exists(registry_file)) {
        registry_url <- sprintf("%s/registry.parquet", self$registry_url)
        tryCatch({
          download_file(registry_url, registry_file, progress = TRUE)
        }, error = function(e) {
          cli::cli_warn("Could not download main registry: {conditionMessage(e)}")
          return(NULL)
        })
      }

      if (fs::file_exists(registry_file)) {
        private$main_registry_cache <- arrow::read_parquet(registry_file)
      }

      private$main_registry_cache
    },

    # Get block-level registry
    get_block_registry = function(year, block_lon, block_lat) {
      filename <- block_to_embeddings_registry_filename(year, block_lon, block_lat)

      # Try local directory first
      if (!is.null(private$registry_dir)) {
        local_path <- fs::path(private$registry_dir, filename)
        if (fs::file_exists(local_path)) {
          return(local_path)
        }
      }

      # Check cache
      cache_path <- fs::path(self$cache_dir, "blocks", filename)
      if (fs::file_exists(cache_path)) {
        return(cache_path)
      }

      # Download from remote
      url <- sprintf("%s/blocks/%s", self$registry_url, filename)

      fs::dir_create(fs::path_dir(cache_path))

      tryCatch({
        download_file(url, cache_path, progress = FALSE)
        cache_path
      }, error = function(e) {
        # Block might not exist (no data in that region)
        NULL
      })
    },

    # Get landmasks registry
    get_landmasks_registry = function() {
      if (!is.null(private$landmasks_registry_cache)) {
        return(private$landmasks_registry_cache)
      }

      # Try local path first
      if (!is.null(private$landmasks_registry_path) &&
          fs::file_exists(private$landmasks_registry_path)) {
        private$landmasks_registry_cache <- arrow::read_parquet(private$landmasks_registry_path)
        return(private$landmasks_registry_cache)
      }

      # Download from remote
      registry_file <- fs::path(self$cache_dir, "landmasks.parquet")

      if (!fs::file_exists(registry_file)) {
        registry_url <- sprintf("%s/landmasks.parquet", self$landmasks_registry_url)
        tryCatch({
          download_file(registry_url, registry_file, progress = TRUE)
        }, error = function(e) {
          cli::cli_warn("Could not download landmasks registry: {conditionMessage(e)}")
          return(NULL)
        })
      }

      if (fs::file_exists(registry_file)) {
        private$landmasks_registry_cache <- arrow::read_parquet(registry_file)
      }

      private$landmasks_registry_cache
    }
  )
)
