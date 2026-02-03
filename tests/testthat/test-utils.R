test_that("block_from_world calculates correct block coordinates", {
  # Test positive coordinates
  result <- block_from_world(2.5, 48.8)  # Paris
  expect_equal(result$block_lon, 0)
  expect_equal(result$block_lat, 45)

  # Test negative coordinates
  result <- block_from_world(-0.1, 51.5)  # London
  expect_equal(result$block_lon, -5)
  expect_equal(result$block_lat, 50)

  # Test at block boundary

  result <- block_from_world(5.0, 50.0)
  expect_equal(result$block_lon, 5)
  expect_equal(result$block_lat, 50)
})

test_that("tile_from_world calculates correct tile coordinates", {
  # Test typical coordinates
  result <- tile_from_world(0.12, 51.52)
  expect_equal(result$tile_lon, 0.15)
  expect_equal(result$tile_lat, 51.55)

  # Test negative coordinates
  result <- tile_from_world(-0.08, 51.48)
  expect_equal(result$tile_lon, -0.05)
  expect_equal(result$tile_lat, 51.45)
})

test_that("tile_to_bounds returns correct bounds", {
  bounds <- tile_to_bounds(0.15, 51.55)

  expect_equal(bounds$xmin, 0.10)
  expect_equal(bounds$xmax, 0.20)

  expect_equal(bounds$ymin, 51.50)
  expect_equal(bounds$ymax, 51.60)
})

test_that("tile_to_grid_name formats correctly", {
  name <- tile_to_grid_name(0.15, 51.55)
  expect_equal(name, "grid_0.15_51.55")

  # Negative coordinates
  name <- tile_to_grid_name(-0.05, -12.35)
  expect_equal(name, "grid_-0.05_-12.35")
})

test_that("parse_grid_name extracts coordinates", {
  coords <- parse_grid_name("grid_0.15_51.55")
  expect_equal(coords$lon, 0.15)
  expect_equal(coords$lat, 51.55)

  # With path and extension
  coords <- parse_grid_name("/path/to/grid_-0.05_-12.35.npy")
  expect_equal(coords$lon, -0.05)
  expect_equal(coords$lat, -12.35)

  # Scales file
  coords <- parse_grid_name("grid_0.15_51.55_scales.npy")
  expect_equal(coords$lon, 0.15)
  expect_equal(coords$lat, 51.55)
})

test_that("parse_grid_name fails on invalid format", {
  expect_error(parse_grid_name("invalid_name"))
  expect_error(parse_grid_name("grid_abc_123"))
})

test_that("blocks_in_bounds returns correct blocks", {
  bbox <- list(xmin = -1, ymin = 50, xmax = 4, ymax = 53)
  blocks <- blocks_in_bounds(bbox)

  expect_true(nrow(blocks) == 2)  # Should span 2 blocks in each dimension
  expect_true(-5 %in% blocks$block_lon)
  expect_true(0 %in% blocks$block_lon)
  expect_true(50 %in% blocks$block_lat)
})

test_that("get_utm_zone calculates correct zones", {
  # London (zone 30)
  expect_equal(get_utm_zone(-0.1), 30)

  # New York (zone 18)
  expect_equal(get_utm_zone(-74), 18)

  # Tokyo (zone 54)
  expect_equal(get_utm_zone(139.7), 54)
})

test_that("get_utm_epsg returns correct EPSG codes", {
  # Northern hemisphere
  expect_equal(get_utm_epsg(-0.1, 51.5), 32630)

  # Southern hemisphere
  expect_equal(get_utm_epsg(151.2, -33.9), 32756)
})

test_that("dequantize_embedding works correctly", {
  # Create test data
  quantized <- array(as.integer(c(1, 2, 3, 4)), dim = c(2, 2, 1))
  quantized <- abind::abind(replicate(128, quantized, simplify = FALSE), along = 3)
  scales <- rep(0.5, 128)

  result <- dequantize_embedding(quantized, scales)

  expect_equal(dim(result), c(2, 2, 128))
  expect_equal(result[1, 1, 1], 0.5)  # 1 * 0.5
  expect_equal(result[2, 2, 1], 2.0)  # 4 * 0.5
})

test_that("is_url correctly identifies URLs",
{
  expect_true(is_url("https://example.com/file.tif"))
  expect_true(is_url("http://example.com"))
  expect_false(is_url("/path/to/file"))
  expect_false(is_url("file.tif"))
})

test_that("format_bbox formats correctly", {
  bbox <- list(xmin = -0.2, ymin = 51.4, xmax = 0.1, ymax = 51.6)
  result <- format_bbox(bbox)
  expect_match(result, "-0.2000")
  expect_match(result, "51.4000")
})
