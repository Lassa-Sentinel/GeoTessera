# Summarize Multiple Regions with Optimized Tile Scheduling

Efficiently summarizes embeddings for multiple regions by:

1.  Building a region-to-tile mapping

2.  Processing tiles in an order that minimizes redundant downloads

3.  Computing streaming statistics for each region

4.  Cleaning up tiles as soon as no regions need them

## Usage

``` r
summarize_regions_streaming(
  gt,
  regions,
  year,
  region_ids = NULL,
  sample_rate = 1,
  mask_to_region = TRUE,
  seed = NULL,
  progress = TRUE
)
```

## Arguments

- gt:

  GeoTessera object

- regions:

  List of sf objects, or a single sf/sfc with multiple features

- year:

  Integer year

- region_ids:

  Optional character vector of region identifiers. If NULL, uses row
  indices or names from the regions.

- sample_rate:

  Fraction of pixels to sample per tile (0-1). Default 1.0.

- mask_to_region:

  If TRUE, only include pixels inside each region's polygon. Default
  TRUE.

- seed:

  Random seed for reproducible sampling

- progress:

  Show progress. Default TRUE.

## Value

Named list with:

- summaries: Named list of mean embeddings per region

- pixel_counts: Named vector of pixel counts per region

- metadata: Processing statistics

## Details

This is much more efficient than processing regions independently when
regions share tiles (e.g., adjacent administrative units).

## Examples

``` r
if (FALSE) { # \dontrun{
library(sf)
gt <- geotessera()

# Load LGAs for a state
lgas <- st_read("nigeria_lgas.shp")
state_lgas <- lgas[lgas$state == "Abia", ]

# Summarize all LGAs efficiently
result <- summarize_regions_streaming(
  gt = gt,
  regions = state_lgas,
  year = 2024,
  region_ids = state_lgas$adminName,
  sample_rate = 0.1
)

# Access results
result$summaries[["Aba North"]]
} # }
```
