# Country Lookup Class

Country Lookup Class

Country Lookup Class

## Details

Provides country name to geometry and bounding box lookup using Natural
Earth data.

## Public fields

- `cache_dir`:

  Directory for caching country data

## Methods

### Public methods

- [`CountryLookup$new()`](#method-CountryLookup-new)

- [`CountryLookup$get_country_geometry()`](#method-CountryLookup-get_country_geometry)

- [`CountryLookup$get_country_bbox()`](#method-CountryLookup-get_country_bbox)

- [`CountryLookup$find_country_for_point()`](#method-CountryLookup-find_country_for_point)

- [`CountryLookup$list_countries()`](#method-CountryLookup-list_countries)

- [`CountryLookup$clone()`](#method-CountryLookup-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new CountryLookup object

#### Usage

    CountryLookup$new(cache_dir = NULL)

#### Arguments

- `cache_dir`:

  Directory for caching (default: user cache)

#### Returns

A new CountryLookup object

------------------------------------------------------------------------

### Method `get_country_geometry()`

Get the geometry for a country

#### Usage

    CountryLookup$get_country_geometry(country_name)

#### Arguments

- `country_name`:

  Country name (case-insensitive)

#### Returns

sf geometry object

------------------------------------------------------------------------

### Method [`get_country_bbox()`](https://lassa-sentinel.github.io/GeoTessera/reference/get_country_bbox.md)

Get the bounding box for a country

#### Usage

    CountryLookup$get_country_bbox(country_name)

#### Arguments

- `country_name`:

  Country name

#### Returns

sf bbox object

------------------------------------------------------------------------

### Method [`find_country_for_point()`](https://lassa-sentinel.github.io/GeoTessera/reference/find_country_for_point.md)

Find which country contains a point

#### Usage

    CountryLookup$find_country_for_point(lon, lat)

#### Arguments

- `lon`:

  Longitude

- `lat`:

  Latitude

#### Returns

Country name or NA if not found

------------------------------------------------------------------------

### Method `list_countries()`

List all available countries

#### Usage

    CountryLookup$list_countries()

#### Returns

Character vector of country names

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CountryLookup$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
