# GeoTessera

R interface to Tessera geofoundation model embeddings.

## Overview

The `GeoTessera` package provides access to 128-channel dense representation maps at 10m resolution derived from Sentinel-1 and Sentinel-2 satellite imagery via the Tessera foundation model.

## Installation

```r
# Install from GitHub (once published)
# remotes::install_github("lassa_sentinel/GeoTessera")

# Or install from local source
install.packages("path/to/GeoTessera", repos = NULL, type = "source")
```

## Quick Start

```r
library(GeoTessera)

# Create a GeoTessera client
gt <- geotessera()

# Get tiles for a region (London)
tiles <- gt$get_tiles(
  bbox = c(-0.2, 51.4, 0.1, 51.6),
  year = 2024
)

# Export as GeoTIFFs
gt$export_embedding_geotiffs(
  tiles = tiles,
  output_dir = "london_tiles"
)
```

## Key Features

- **Download Tessera tiles** for geographic bounding boxes
- **Export** as GeoTIFF, NumPy arrays, or Zarr archives
- **Sample embeddings** at specific point locations
- **Visualize coverage** globally or for specific regions
- **Country-level** data access support
- **SHA256 hash verification** for data integrity

## Main Classes

### GeoTessera

The main interface for downloading and exporting embeddings.

```r
gt <- geotessera()

# Count available tiles
count <- gt$embeddings_count(bbox = c(-0.2, 51.4, 0.1, 51.6), year = 2024)

# Download a single tile
tile <- gt$download_tile(lon = 0.1, lat = 51.5, year = 2024)

# Fetch embedding data
result <- gt$fetch_embedding(lon = 0.1, lat = 51.5, year = 2024)
embedding <- result$embedding  # 3D array (height, width, 128 channels)

# Sample at specific points
points <- data.frame(lon = c(0.1, 0.2), lat = c(51.5, 51.6))
samples <- gt$sample_embeddings_at_points(points, year = 2024)
```

### Registry

Manages tile metadata and downloads.

```r
registry <- Registry$new()

# Get available years
years <- registry$get_available_years()

# Count tiles by year
counts <- registry$get_tile_counts_by_year()

# Load tiles for a region
tiles <- registry$load_tiles_for_region(
  bbox = c(-0.2, 51.4, 0.1, 51.6),
  year = 2024
)
```

### Tile

Format-agnostic tile abstraction.
```r
# Create from GeoTIFF
tile <- tile_from_geotiff("path/to/grid_0.15_51.55.tif")

# Load embedding data
embedding <- tile$load_embedding()

# Sample at a point
values <- tile$sample_at_point(lon = 0.15, lat = 51.55)
```

## Visualization

```r
# Visualize global coverage
visualize_global_coverage(gt, output_path = "coverage.png", year = 2024)

# Create RGB mosaic from specific bands
tiff_files <- list.files("tiles/", pattern = "\\.tif$", full.names = TRUE)
create_rgb_mosaic(tiff_files, "mosaic_rgb.tif", bands = c(30, 60, 90))

# Create PCA visualization
create_pca_mosaic(tiff_files, "mosaic_pca.tif", n_components = 3)
```

## Country Support

```r
# Get bounding box for a country
bbox <- get_country_bbox("United Kingdom")

# Find which country contains a point
country <- find_country_for_point(lon = -0.1, lat = 51.5)
```

## Data Organization

Tessera data is organized hierarchically:

1. **Blocks** (5° x 5° degrees): Registry organization units
2. **Tiles** (0.1° x 0.1° degrees): Individual embedding files
3. **Pixels** (10m resolution): Within each tile

Each tile contains 128 embedding channels at 1111 x 1111 pixel resolution.

## Supported Formats

- **NPY**: Native numpy format with separate scales files
- **GeoTIFF**: Georeferenced raster format with compression
- **Zarr**: Chunked array format (experimental)

## Dependencies

Core dependencies:
- `R6`: Object-oriented programming
- `sf`: Spatial data handling
- `terra`: Raster operations
- `arrow`: Parquet file support
- `httr2`: HTTP requests
- `cli`: Progress bars and messages

Optional for visualization:
- `ggplot2`: Plotting
- `rnaturalearth`: Country boundaries

## License

MIT License

## Acknowledgments

This is an R port of the Python [geotessera](https://github.com/avsm/geotessera) package.
