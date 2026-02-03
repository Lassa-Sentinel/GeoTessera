# Get bounding box for a country

Convenience function to get country bounding box without creating a
CountryLookup object.

## Usage

``` r
get_country_bbox(country_name, cache_dir = NULL)
```

## Arguments

- country_name:

  Country name

- cache_dir:

  Optional cache directory

## Value

sf bbox object

## Examples

``` r
if (FALSE) { # \dontrun{
bbox <- get_country_bbox("United Kingdom")
} # }
```
