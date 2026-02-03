# Standard Deviation Summary

Computes the standard deviation of embeddings across all valid pixels.

## Usage

``` r
summary_sd(embeddings, region = NULL, tiles_df = NULL)
```

## Arguments

- embeddings:

  List of 3D arrays (height, width, channels) from tiles

- region:

  sf object or bbox defining the region (used for masking)

- tiles_df:

  Data frame of tile metadata

## Value

Named numeric vector of length 128 (per-dimension std dev)
