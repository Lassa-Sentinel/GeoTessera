# GeoTessera: Access Tessera Geofoundation Model Embeddings

The GeoTessera package provides an R interface to Tessera geofoundation
model embeddings. It enables downloading 128-channel dense
representation maps at 10m resolution derived from Sentinel-1 and
Sentinel-2 satellite imagery.

## Main Classes

- GeoTessera:

  Main interface for downloading and exporting embeddings

- Registry:

  Registry management for tile metadata and downloads

- Tile:

  Format-agnostic tile abstraction

- CountryLookup:

  Country name to geometry lookup

## Quick Start

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

    # Sample embeddings at specific points
    points <- data.frame(
      lon = c(-0.1, 0.0),
      lat = c(51.5, 51.5)
    )
    embeddings <- gt$sample_embeddings_at_points(points, year = 2024)

## Data Organization

Tessera data is organized in a hierarchical system:

- Blocks: 5x5 degree regions for registry organization

- Tiles: 0.1x0.1 degree regions containing embedding data

- Pixels: 10m resolution within each tile

## Supported Formats

- NPY: Native numpy format with separate scales files

- GeoTIFF: Georeferenced raster format

- Zarr: Chunked array format (experimental)

## See also

Useful links:

- <https://github.com/lassa_sentinel/GeoTessera>

- Report bugs at <https://github.com/lassa_sentinel/GeoTessera/issues>

## Author

**Maintainer**: Sentinel Team <sentinel@example.com> \[copyright
holder\]
