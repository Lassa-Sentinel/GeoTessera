# Test tile download functionality - matches Python CRAM test expectations
# Uses UK region tile (lon=-0.05, lat=51.35) as it's a verified test case

test_that("download_tile fetches a single tile correctly", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  # Use a point in the UK region that's verified to have data
  # Point (-0.05, 51.35) is inside tile grid_-0.05_51.35
  tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Verify tile object
  expect_s3_class(tile, "Tile")
  expect_equal(tile$lon, -0.05, tolerance = 0.001)
  expect_equal(tile$lat, 51.35)
  expect_equal(tile$year, 2024)
  expect_equal(tile$format, "npy")

  # Verify tile is available (files downloaded)
  expect_true(tile$is_available())

  # Verify file paths exist
  expect_true(fs::file_exists(tile$path))
  expect_true(fs::file_exists(tile$scales_path))
})

test_that("downloaded embedding has correct dimensions", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Load embedding
  embedding <- tile$load_embedding()

  # Verify dimensions: (height, width, channels)
  # Note: height and width vary by latitude due to projection
  # Typical values are around 1000-1200 pixels
  dims <- dim(embedding)
  expect_equal(length(dims), 3)
  expect_gt(dims[1], 500)   # height > 500
  expect_gt(dims[2], 500)   # width > 500
  expect_equal(dims[3], 128)   # channels always 128
})

test_that("embedding values are dequantized floats", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  tile <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Load embedding
  embedding <- tile$load_embedding()

  # Verify values are floats (not integers)
  expect_type(embedding, "double")

  # Verify values are in reasonable range (not all zeros, not huge)
  expect_false(all(embedding == 0))
  expect_true(all(is.finite(embedding)))

  # Check there's variation in the data
  expect_gt(sd(embedding), 0)
})

test_that("download_tile skips existing files (resume capability)", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  gt <- GeoTessera$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  # First download
  tile1 <- tryCatch(
    gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  # Get file modification time
  mtime1 <- file.mtime(tile1$path)

  # Small delay to ensure modification time would change if file were rewritten
  Sys.sleep(0.5)

  # Second download should skip (file already exists with correct hash)
  tile2 <- gt$download_tile(lon = -0.05, lat = 51.35, year = 2024, progress = FALSE)

  # File modification time should be unchanged
  mtime2 <- file.mtime(tile2$path)
  expect_equal(mtime1, mtime2)
})

test_that("Registry$fetch downloads embedding and scales files", {
  skip_on_cran()
  skip_if_offline()

  temp_cache <- tempfile("cache_")
  temp_emb <- tempfile("emb_")
  on.exit(unlink(c(temp_cache, temp_emb), recursive = TRUE))

  registry <- Registry$new(cache_dir = temp_cache, embeddings_dir = temp_emb)

  # Get tile metadata for a UK region tile
  # Use a small bbox that contains exactly 1 tile
  bbox <- list(xmin = -0.05, ymin = 51.35, xmax = -0.04, ymax = 51.36)
  tiles <- tryCatch(
    registry$load_tiles_for_region(bbox, 2024, progress = FALSE),
    error = function(e) {
      skip(paste("Registry unavailable:", conditionMessage(e)))
    }
  )

  if (nrow(tiles) == 0) {
    skip("No tiles found in test region")
  }

  tile_info <- tiles[1, ]

  # Download embedding file
  embedding_path <- tryCatch(
    registry$fetch(
      year = 2024,
      lon = tile_info$lon,
      lat = tile_info$lat,
      is_scales = FALSE,
      expected_hash = tile_info$embedding_hash,
      progress = FALSE
    ),
    error = function(e) {
      skip(paste("Download failed:", conditionMessage(e)))
    }
  )

  expect_true(fs::file_exists(embedding_path))

  # Download scales file
  scales_path <- registry$fetch(
    year = 2024,
    lon = tile_info$lon,
    lat = tile_info$lat,
    is_scales = TRUE,
    expected_hash = tile_info$scales_hash,
    progress = FALSE
  )

  expect_true(fs::file_exists(scales_path))
})
