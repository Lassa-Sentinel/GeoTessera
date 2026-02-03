# Quantile Summary

Factory function to create a quantile summary function.

## Usage

``` r
summary_quantile(probs = c(0.25, 0.5, 0.75))
```

## Arguments

- probs:

  Numeric vector of probabilities (0-1)

## Value

A summary function that computes the specified quantiles

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a function for 25th and 75th percentiles
summary_q25_75 <- summary_quantile(c(0.25, 0.75))

gt <- geotessera()
result <- gt$summarize_region(
  region = bbox,
  year = 2024,
  summary_fns = list(quantiles = summary_q25_75)
)
} # }
```
