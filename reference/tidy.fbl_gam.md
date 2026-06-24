# Present a tidy summary of a GAM

Present a tidy summary of a GAM

## Usage

``` r
# S3 method for class 'fbl_gam'
tidy(x, ...)
```

## Arguments

- x:

  `fbl_gam` object

- ...:

  arguments to be passed to methods

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
  tidy()
# }
```
