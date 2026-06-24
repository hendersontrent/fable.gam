# Glance a GAM

Construct a single row summary of the GAM model. Contains a range of
model fit statistics.

## Usage

``` r
# S3 method for class 'fbl_gam'
glance(x, ...)
```

## Arguments

- x:

  model or other R object to convert to single-row data frame

- ...:

  other arguments passed to methods

## Value

\`tibble\` summarising the model fit.

## Examples

``` r
# \donttest{
library(dplyr)
library(tsibble)

tourism_melb <- tsibble::tourism |>
  filter(Region == "Melbourne") |>
  filter(Purpose == "Business") |>
  dplyr::select(c(Quarter, Region, Trips)) |>
  as_tsibble(key = Region, index = Quarter)

fit <- tourism_melb |>
  model(mygam = GAM(Trips ~ trend() + season(4))) |>
  glance()
# }
```
