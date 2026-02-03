# Convert world coordinates to tile coordinates

Tiles are 0.1x0.1 degree regions containing the actual embedding data.
Tile centers are on 0.05-degree offsets (e.g., -0.05, 0.05, 0.15, etc.).

## Usage

``` r
tile_from_world(lon, lat)
```

## Arguments

- lon:

  Longitude in decimal degrees

- lat:

  Latitude in decimal degrees

## Value

Named list with tile_lon and tile_lat (center coordinates)

## Examples

``` r
if (FALSE) { # \dontrun{
tile_from_world(0.17, 52.23)  # Returns (0.15, 52.25)
tile_from_world(-0.1, 51.3)   # Returns (-0.05, 51.35)
} # }
```
