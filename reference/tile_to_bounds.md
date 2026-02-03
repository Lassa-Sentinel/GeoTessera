# Get tile bounds from center coordinates

Given the center coordinates of a GeoTessera tile, returns the bounding
box. Each tile is 0.1 x 0.1 degrees.

## Usage

``` r
tile_to_bounds(lon, lat)
```

## Arguments

- lon:

  Tile center longitude

- lat:

  Tile center latitude

## Value

Named list with xmin, ymin, xmax, ymax

## Examples

``` r
tile_to_bounds(0.15, 52.25)  # Returns xmin=0.1, ymin=52.2, xmax=0.2, ymax=52.3
#> $xmin
#> [1] 0.1
#> 
#> $ymin
#> [1] 52.2
#> 
#> $xmax
#> [1] 0.2
#> 
#> $ymax
#> [1] 52.3
#> 
```
