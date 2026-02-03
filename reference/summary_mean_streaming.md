# Streaming Mean Summary (Memory Efficient)

Computes mean embedding using Welford's online algorithm, processing one
tile at a time without storing all embeddings in memory. Ideal for large
regions with many tiles.

## Usage

``` r
summary_mean_streaming(
  gt,
  tiles_df,
  year,
  region = NULL,
  sample_rate = 1,
  seed = NULL,
  progress = TRUE
)
```

## Arguments

- gt:

  GeoTessera object

- tiles_df:

  Data frame of tile metadata

- year:

  Integer year

- region:

  sf object for masking (optional)

- sample_rate:

  Fraction of pixels to sample (0-1). Default 1.0 (all pixels). Use
  lower values for faster processing of very large regions.

- seed:

  Random seed for sampling (if sample_rate \< 1)

- progress:

  Show progress

## Value

Named list with mean embedding and pixel count

## Examples

``` r
if (FALSE) { # \dontrun{
gt <- geotessera()
tiles_df <- gt$get_tiles(bbox, year = 2024)
result <- summary_mean_streaming(gt, tiles_df, 2024)
} # }
```
