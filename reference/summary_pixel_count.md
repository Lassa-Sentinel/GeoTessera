# Pixel Count Summary

Returns the count of valid (non-NA) pixels in the region.

## Usage

``` r
summary_pixel_count(embeddings, region = NULL, tiles_df = NULL)
```

## Arguments

- embeddings:

  List of 3D arrays (height, width, channels) from tiles

- region:

  sf object or bbox defining the region (used for masking)

- tiles_df:

  Data frame of tile metadata

## Value

Named integer with valid and total pixel counts
