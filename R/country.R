#' @title Country Lookup Functions
#' @description Functions for looking up country geometries and bounding boxes.
#' @name country
NULL

#' Country Lookup Class
#'
#' Provides country name to geometry and bounding box lookup using Natural Earth data.
#'
#' @export
CountryLookup <- R6::R6Class(
  "CountryLookup",
  public = list(
    #' @field cache_dir Directory for caching country data
    cache_dir = NULL,

    #' @description Create a new CountryLookup object
    #' @param cache_dir Directory for caching (default: user cache)
    #' @return A new CountryLookup object
    initialize = function(cache_dir = NULL) {
      self$cache_dir <- cache_dir %||% get_cache_dir()
      fs::dir_create(self$cache_dir)
    },

    #' @description Get the geometry for a country
    #' @param country_name Country name (case-insensitive)
    #' @return sf geometry object
    get_country_geometry = function(country_name) {
      countries <- private$load_countries()

      # Try exact match first
      idx <- which(tolower(countries$NAME) == tolower(country_name))

      # Try partial match
      if (length(idx) == 0) {
        idx <- grep(country_name, countries$NAME, ignore.case = TRUE)
      }

      # Try alternative name fields if available
      if (length(idx) == 0 && "NAME_LONG" %in% names(countries)) {
        idx <- which(tolower(countries$NAME_LONG) == tolower(country_name))
        if (length(idx) == 0) {
          idx <- grep(country_name, countries$NAME_LONG, ignore.case = TRUE)
        }
      }

      if (length(idx) == 0) {
        cli::cli_abort("Country not found: {country_name}")
      }

      if (length(idx) > 1) {
        matches <- countries$NAME[idx]
        cli::cli_warn("Multiple matches found: {paste(matches, collapse = ', ')}. Using first match.")
        idx <- idx[1]
      }

      sf::st_geometry(countries[idx, ])
    },

    #' @description Get the bounding box for a country
    #' @param country_name Country name
    #' @return sf bbox object
    get_country_bbox = function(country_name) {
      geom <- self$get_country_geometry(country_name)
      sf::st_bbox(geom)
    },

    #' @description Find which country contains a point
    #' @param lon Longitude
    #' @param lat Latitude
    #' @return Country name or NA if not found
    find_country_for_point = function(lon, lat) {
      countries <- private$load_countries()

      point <- sf::st_point(c(lon, lat))
      point_sf <- sf::st_sfc(point, crs = 4326)

      intersects <- sf::st_intersects(point_sf, countries)
      idx <- intersects[[1]]

      if (length(idx) == 0) {
        return(NA_character_)
      }

      countries$NAME[idx[1]]
    },

    #' @description List all available countries
    #' @return Character vector of country names
    list_countries = function() {
      countries <- private$load_countries()
      sort(countries$NAME)
    }
  ),

  private = list(
    countries_cache = NULL,

    load_countries = function() {
      if (!is.null(private$countries_cache)) {
        return(private$countries_cache)
      }

      # Try to load from rnaturalearth if available
      if (requireNamespace("rnaturalearth", quietly = TRUE)) {
        tryCatch({
          private$countries_cache <- rnaturalearth::ne_countries(
            scale = "medium",
            returnclass = "sf"
          )
          return(private$countries_cache)
        }, error = function(e) {
          cli::cli_warn("Could not load from rnaturalearth: {conditionMessage(e)}")
        })
      }

      # Fallback: download from Natural Earth directly
      ne_url <- "https://naciscdn.org/naturalearth/110m/cultural/ne_110m_admin_0_countries.zip"
      cache_path <- fs::path(self$cache_dir, "ne_countries.gpkg")

      if (!fs::file_exists(cache_path)) {
        cli::cli_alert_info("Downloading Natural Earth countries data...")
        zip_path <- tempfile(fileext = ".zip")
        download_file(ne_url, zip_path, progress = TRUE)

        # Extract and convert to geopackage
        temp_dir <- tempfile()
        utils::unzip(zip_path, exdir = temp_dir)

        shp_file <- fs::dir_ls(temp_dir, glob = "*.shp", recurse = TRUE)[1]
        countries <- sf::st_read(shp_file, quiet = TRUE)
        sf::st_write(countries, cache_path, quiet = TRUE)

        unlink(zip_path)
        unlink(temp_dir, recursive = TRUE)
      }

      private$countries_cache <- sf::st_read(cache_path, quiet = TRUE)
      private$countries_cache
    }
  )
)

#' Get bounding box for a country
#'
#' Convenience function to get country bounding box without creating a CountryLookup object.
#'
#' @param country_name Country name
#' @param cache_dir Optional cache directory
#' @return sf bbox object
#' @export
#' @examples
#' \dontrun{
#' bbox <- get_country_bbox("United Kingdom")
#' }
get_country_bbox <- function(country_name, cache_dir = NULL) {
  lookup <- CountryLookup$new(cache_dir)
  lookup$get_country_bbox(country_name)
}

#' Find country for a point
#'
#' @param lon Longitude
#' @param lat Latitude
#' @param cache_dir Optional cache directory
#' @return Country name or NA
#' @export
find_country_for_point <- function(lon, lat, cache_dir = NULL) {
  lookup <- CountryLookup$new(cache_dir)
  lookup$find_country_for_point(lon, lat)
}
