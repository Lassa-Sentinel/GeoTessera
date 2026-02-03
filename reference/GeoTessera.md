# GeoTessera Class

Main interface for downloading and exporting Tessera embeddings. This R6
class provides methods for downloading tiles, exporting GeoTIFFs, and
sampling embeddings at specific points. Use `GeoTessera$new()` to create
a new instance, or the convenience function `geotessera`.

Convenience function to create a new GeoTessera object.

## Usage

``` r
geotessera(...)
```

## Arguments

- ...:

  Arguments passed to GeoTessera\$new()

## Value

GeoTessera object

## Public fields

- `registry`:

  Registry object for metadata and downloads

- `version`:

  Dataset version

## Methods

### Public methods

- [`GeoTessera$new()`](#method-GeoTessera-new)

- [`GeoTessera$embeddings_count()`](#method-GeoTessera-embeddings_count)

- [`GeoTessera$get_tiles()`](#method-GeoTessera-get_tiles)

- [`GeoTessera$download_tile()`](#method-GeoTessera-download_tile)

- [`GeoTessera$fetch_embedding()`](#method-GeoTessera-fetch_embedding)

- [`GeoTessera$fetch_embeddings()`](#method-GeoTessera-fetch_embeddings)

- [`GeoTessera$download_tiles_for_points()`](#method-GeoTessera-download_tiles_for_points)

- [`GeoTessera$check_tiles_present()`](#method-GeoTessera-check_tiles_present)

- [`GeoTessera$sample_embeddings_at_points()`](#method-GeoTessera-sample_embeddings_at_points)

- [`GeoTessera$export_embedding_geotiff()`](#method-GeoTessera-export_embedding_geotiff)

- [`GeoTessera$export_embedding_geotiffs()`](#method-GeoTessera-export_embedding_geotiffs)

- [`GeoTessera$fetch_mosaic_for_region()`](#method-GeoTessera-fetch_mosaic_for_region)

- [`GeoTessera$apply_pca_to_embeddings()`](#method-GeoTessera-apply_pca_to_embeddings)

- [`GeoTessera$export_pca_geotiffs()`](#method-GeoTessera-export_pca_geotiffs)

- [`GeoTessera$merge_geotiffs_to_mosaic()`](#method-GeoTessera-merge_geotiffs_to_mosaic)

- [`GeoTessera$export_coverage_map()`](#method-GeoTessera-export_coverage_map)

- [`GeoTessera$summarize_region()`](#method-GeoTessera-summarize_region)

- [`GeoTessera$summarize_region_streaming()`](#method-GeoTessera-summarize_region_streaming)

- [`GeoTessera$print()`](#method-GeoTessera-print)

- [`GeoTessera$clone()`](#method-GeoTessera-clone)

------------------------------------------------------------------------

### Method [`new()`](https://rdrr.io/r/methods/new.html)

Create a new GeoTessera object

#### Usage

    GeoTessera$new(
      dataset_version = "v1",
      cache_dir = NULL,
      embeddings_dir = NULL,
      registry_url = NULL,
      registry_path = NULL,
      registry_dir = NULL,
      verify_hashes = TRUE
    )

#### Arguments

- `dataset_version`:

  Dataset version (default "v1")

- `cache_dir`:

  Directory for caching

- `embeddings_dir`:

  Directory for storing embeddings

- `registry_url`:

  URL for registry

- `registry_path`:

  Local registry path

- `registry_dir`:

  Local registry directory

- `verify_hashes`:

  Verify SHA256 hashes

#### Returns

A new GeoTessera object

------------------------------------------------------------------------

### Method `embeddings_count()`

Count embeddings available in a bounding box

#### Usage

    GeoTessera$embeddings_count(bbox, year)

#### Arguments

- `bbox`:

  Bounding box (sf bbox, list, or numeric vector)

- `year`:

  Integer year

#### Returns

Integer count

------------------------------------------------------------------------

### Method `get_tiles()`

Get tiles for a region

#### Usage

    GeoTessera$get_tiles(bbox, year, progress = TRUE)

#### Arguments

- `bbox`:

  Bounding box

- `year`:

  Integer year

- `progress`:

  Show progress

#### Returns

Data frame of tile metadata

------------------------------------------------------------------------

### Method `download_tile()`

Download a single tile

#### Usage

    GeoTessera$download_tile(lon, lat, year, progress = TRUE)

#### Arguments

- `lon`:

  Tile longitude

- `lat`:

  Tile latitude

- `year`:

  Integer year

- `progress`:

  Show progress

#### Returns

Tile object

------------------------------------------------------------------------

### Method `fetch_embedding()`

Fetch embedding for a single location

#### Usage

    GeoTessera$fetch_embedding(lon, lat, year)

#### Arguments

- `lon`:

  Longitude

- `lat`:

  Latitude

- `year`:

  Integer year

#### Returns

Named list with embedding (array), crs, and transform

------------------------------------------------------------------------

### Method `fetch_embeddings()`

Fetch embeddings for multiple tiles

#### Usage

    GeoTessera$fetch_embeddings(tiles, progress = TRUE)

#### Arguments

- `tiles`:

  Data frame of tiles to fetch

- `progress`:

  Show progress

#### Returns

Generator function that yields Tile objects

------------------------------------------------------------------------

### Method `download_tiles_for_points()`

Download tiles for a list of points

#### Usage

    GeoTessera$download_tiles_for_points(points, year, progress = TRUE)

#### Arguments

- `points`:

  Data frame with lon and lat columns

- `year`:

  Integer year

- `progress`:

  Show progress

#### Returns

List of Tile objects

------------------------------------------------------------------------

### Method `check_tiles_present()`

Check which tiles are present for a set of points

#### Usage

    GeoTessera$check_tiles_present(points, year)

#### Arguments

- `points`:

  Data frame with lon and lat columns

- `year`:

  Integer year

#### Returns

Data frame with lon, lat, tile_lon, tile_lat, available columns

------------------------------------------------------------------------

### Method `sample_embeddings_at_points()`

Sample embeddings at specific points

#### Usage

    GeoTessera$sample_embeddings_at_points(
      points,
      year,
      download = TRUE,
      progress = TRUE
    )

#### Arguments

- `points`:

  Data frame with lon and lat columns

- `year`:

  Integer year

- `download`:

  Download missing tiles

- `progress`:

  Show progress

#### Returns

Data frame with lon, lat, and embedding_1 through embedding_128 columns

------------------------------------------------------------------------

### Method `export_embedding_geotiff()`

Export a single tile as GeoTIFF

#### Usage

    GeoTessera$export_embedding_geotiff(
      lon,
      lat,
      year,
      output_path,
      bands = NULL,
      compress = "lzw"
    )

#### Arguments

- `lon`:

  Tile longitude

- `lat`:

  Tile latitude

- `year`:

  Integer year

- `output_path`:

  Output file path

- `bands`:

  Which bands to include (NULL for all 128)

- `compress`:

  Compression type ("lzw", "deflate", "none")

#### Returns

Output file path

------------------------------------------------------------------------

### Method `export_embedding_geotiffs()`

Export multiple tiles as GeoTIFFs

#### Usage

    GeoTessera$export_embedding_geotiffs(
      tiles,
      output_dir,
      bands = NULL,
      compress = "lzw",
      progress = TRUE
    )

#### Arguments

- `tiles`:

  Data frame of tiles to export

- `output_dir`:

  Output directory

- `bands`:

  Which bands to include (NULL for all)

- `compress`:

  Compression type

- `progress`:

  Show progress

#### Returns

Character vector of output file paths

------------------------------------------------------------------------

### Method `fetch_mosaic_for_region()`

Fetch a mosaic of embeddings for a region

#### Usage

    GeoTessera$fetch_mosaic_for_region(bbox, year, bands = NULL, progress = TRUE)

#### Arguments

- `bbox`:

  Bounding box

- `year`:

  Integer year

- `bands`:

  Which bands to include (NULL for all)

- `progress`:

  Show progress

#### Returns

SpatRaster object

------------------------------------------------------------------------

### Method `apply_pca_to_embeddings()`

Apply PCA to embeddings

#### Usage

    GeoTessera$apply_pca_to_embeddings(embeddings, n_components = 3)

#### Arguments

- `embeddings`:

  3D array (height, width, channels) or 2D (pixels, channels)

- `n_components`:

  Number of PCA components

#### Returns

Array with reduced dimensions

------------------------------------------------------------------------

### Method `export_pca_geotiffs()`

Export tiles with PCA reduction

#### Usage

    GeoTessera$export_pca_geotiffs(
      tiles,
      output_dir,
      n_components = 3,
      progress = TRUE
    )

#### Arguments

- `tiles`:

  Data frame of tiles

- `output_dir`:

  Output directory

- `n_components`:

  Number of PCA components

- `progress`:

  Show progress

#### Returns

Character vector of output paths

------------------------------------------------------------------------

### Method `merge_geotiffs_to_mosaic()`

Merge GeoTIFFs into a single mosaic

#### Usage

    GeoTessera$merge_geotiffs_to_mosaic(input_dir, output_path, nodata_value = 0)

#### Arguments

- `input_dir`:

  Directory containing GeoTIFFs

- `output_path`:

  Output file path

- `nodata_value`:

  NoData value (default 0)

#### Returns

Output file path

------------------------------------------------------------------------

### Method `export_coverage_map()`

Export coverage map

#### Usage

    GeoTessera$export_coverage_map(output_file = NULL)

#### Arguments

- `output_file`:

  Output JSON file path

#### Returns

Named list with coverage statistics

------------------------------------------------------------------------

### Method `summarize_region()`

Summarize embeddings for a geographic region

Downloads embeddings for a region to a temporary location, applies
summary functions, and cleans up automatically. Useful for processing
large regions where only summary statistics are needed.

#### Usage

    GeoTessera$summarize_region(
      region,
      year,
      summary_fns = NULL,
      mask_to_region = TRUE,
      progress = TRUE,
      keep_tiles = FALSE
    )

#### Arguments

- `region`:

  Bounding box (numeric vector, list, or sf bbox) or sf/sfc object
  (e.g., from a shapefile). For sf objects, the bounding box is used for
  tile selection, and pixels are masked to the geometry.

- `year`:

  Integer year

- `summary_fns`:

  Named list of summary functions. Each function should accept
  parameters: embeddings (list of 3D arrays), region (the input region),
  tiles_df (tile metadata). Some functions also accept gt and year for
  sampling operations. Default includes mean, centroid, and pixel_count
  summaries.

- `mask_to_region`:

  Logical; if TRUE and region is an sf object, pixels outside the
  geometry are set to NA before summarization. Default TRUE.

- `progress`:

  Show progress bars. Default TRUE.

- `keep_tiles`:

  Logical; if TRUE, returns the downloaded Tile objects along with
  summaries (tiles are NOT cleaned up). Default FALSE.

#### Returns

Named list containing:

- summaries: Named list of summary results (one per summary_fn)

- metadata: List with region info, year, n_tiles, processing time

- tiles: (only if keep_tiles=TRUE) List of Tile objects

#### Examples

    \dontrun{
    gt <- geotessera()

    # Basic usage with bounding box
    result <- gt$summarize_region(
      region = c(0.08, 52.18, 0.15, 52.21),
      year = 2024
    )
    print(result$summaries$mean)

    # With sf object from shapefile
    library(sf)
    shape <- st_read("my_region.shp")
    result <- gt$summarize_region(region = shape, year = 2024)

    # Custom summary functions
    my_summary <- function(embeddings, region, tiles_df) {
      # Custom computation
      colMeans(do.call(rbind, lapply(embeddings, function(e) {
        apply(e, 3, mean, na.rm = TRUE)
      })))
    }

    result <- gt$summarize_region(
      region = bbox,
      year = 2024,
      summary_fns = list(
        mean = summary_mean,
        custom = my_summary,
        quantiles = summary_quantile(c(0.1, 0.9))
      )
    )
    }

------------------------------------------------------------------------

### Method `summarize_region_streaming()`

Summarize a large region using streaming (memory efficient)

Processes tiles one at a time using Welford's online algorithm for
computing the mean, avoiding memory issues with large regions.

#### Usage

    GeoTessera$summarize_region_streaming(
      region,
      year,
      sample_rate = 1,
      mask_to_region = TRUE,
      seed = NULL,
      progress = TRUE
    )

#### Arguments

- `region`:

  Bounding box or sf object

- `year`:

  Integer year

- `sample_rate`:

  Fraction of pixels to sample (0-1). Use lower values for very large
  regions. Default 1.0.

- `mask_to_region`:

  If TRUE and region is sf, only include pixels inside the polygon.
  Default TRUE.

- `seed`:

  Random seed for reproducible sampling

- `progress`:

  Show progress. Default TRUE.

#### Returns

Named list with mean embedding, pixel count, and metadata

#### Examples

    \dontrun{
    gt <- geotessera()
    # For large regions, use streaming approach
    result <- gt$summarize_region_streaming(
      region = large_polygon,
      year = 2024,
      sample_rate = 0.1
    )
    }

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print summary of GeoTessera object

#### Usage

    GeoTessera$print()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    GeoTessera$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
## ------------------------------------------------
## Method `GeoTessera$summarize_region`
## ------------------------------------------------

if (FALSE) { # \dontrun{
gt <- geotessera()

# Basic usage with bounding box
result <- gt$summarize_region(
  region = c(0.08, 52.18, 0.15, 52.21),
  year = 2024
)
print(result$summaries$mean)

# With sf object from shapefile
library(sf)
shape <- st_read("my_region.shp")
result <- gt$summarize_region(region = shape, year = 2024)

# Custom summary functions
my_summary <- function(embeddings, region, tiles_df) {
  # Custom computation
  colMeans(do.call(rbind, lapply(embeddings, function(e) {
    apply(e, 3, mean, na.rm = TRUE)
  })))
}

result <- gt$summarize_region(
  region = bbox,
  year = 2024,
  summary_fns = list(
    mean = summary_mean,
    custom = my_summary,
    quantiles = summary_quantile(c(0.1, 0.9))
  )
)
} # }

## ------------------------------------------------
## Method `GeoTessera$summarize_region_streaming`
## ------------------------------------------------

if (FALSE) { # \dontrun{
gt <- geotessera()
# For large regions, use streaming approach
result <- gt$summarize_region_streaming(
  region = large_polygon,
  year = 2024,
  sample_rate = 0.1
)
} # }
if (FALSE) { # \dontrun{
gt <- geotessera()
tiles <- gt$get_tiles(bbox = c(-0.2, 51.4, 0.1, 51.6), year = 2024)
} # }
```
