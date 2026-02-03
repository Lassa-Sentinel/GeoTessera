# Median Embedding Summary

Computes the median embedding across all valid pixels in the region.

## Usage

``` r
summary_median(embeddings, region = NULL, tiles_df = NULL)
```

## Arguments

- embeddings:

  List of 3D arrays (height, width, channels) from tiles

- region:

  sf object or bbox defining the region (used for masking)

- tiles_df:

  Data frame of tile metadata

## Value

Named numeric vector of length 128 (median embedding)
