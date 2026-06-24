# Produce forecasts from the GAM

Produce forecasts from the GAM

## Usage

``` r
# S3 method for class 'fbl_gam'
forecast(object, new_data, specials = NULL, ...)
```

## Arguments

- object:

  A model for which forecasts are required.

- new_data:

  A tsibble containing the time points and exogenous regressors to
  produce forecasts for.

- specials:

  (passed by
  [`fabletools::forecast.mdl_df()`](https://generics.r-lib.org/reference/forecast.html)).

- ...:

  arguments passed to
  [`stats::predict()`](https://rdrr.io/r/stats/predict.html).

## Value

Vector of distributions

## Author

Trent Henderson

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
  model(mygam = GAM(Trips ~ trend() + season(4)))

# Analytic intervals

forecast(fit, h = "5 years")
#> # A fable: 20 x 5 [1Q]
#> # Key:     Region, .model [1]
#>    Region    .model Quarter
#>    <chr>     <chr>    <qtr>
#>  1 Melbourne mygam  2018 Q1
#>  2 Melbourne mygam  2018 Q2
#>  3 Melbourne mygam  2018 Q3
#>  4 Melbourne mygam  2018 Q4
#>  5 Melbourne mygam  2019 Q1
#>  6 Melbourne mygam  2019 Q2
#>  7 Melbourne mygam  2019 Q3
#>  8 Melbourne mygam  2019 Q4
#>  9 Melbourne mygam  2020 Q1
#> 10 Melbourne mygam  2020 Q2
#> 11 Melbourne mygam  2020 Q3
#> 12 Melbourne mygam  2020 Q4
#> 13 Melbourne mygam  2021 Q1
#> 14 Melbourne mygam  2021 Q2
#> 15 Melbourne mygam  2021 Q3
#> 16 Melbourne mygam  2021 Q4
#> 17 Melbourne mygam  2022 Q1
#> 18 Melbourne mygam  2022 Q2
#> 19 Melbourne mygam  2022 Q3
#> 20 Melbourne mygam  2022 Q4
#> # ℹ 2 more variables: Trips <dist>, .mean <dbl>

# Bootstrap intervals

forecast(fit, h = "5 years", bootstrap = TRUE)
#> # A fable: 20 x 5 [1Q]
#> # Key:     Region, .model [1]
#>    Region    .model Quarter        Trips .mean
#>    <chr>     <chr>    <qtr>       <dist> <dbl>
#>  1 Melbourne mygam  2018 Q1 sample[5000]  670.
#>  2 Melbourne mygam  2018 Q2 sample[5000]  729.
#>  3 Melbourne mygam  2018 Q3 sample[5000]  760.
#>  4 Melbourne mygam  2018 Q4 sample[5000]  716.
#>  5 Melbourne mygam  2019 Q1 sample[5000]  732.
#>  6 Melbourne mygam  2019 Q2 sample[5000]  788.
#>  7 Melbourne mygam  2019 Q3 sample[5000]  821.
#>  8 Melbourne mygam  2019 Q4 sample[5000]  776.
#>  9 Melbourne mygam  2020 Q1 sample[5000]  790.
#> 10 Melbourne mygam  2020 Q2 sample[5000]  849.
#> 11 Melbourne mygam  2020 Q3 sample[5000]  878.
#> 12 Melbourne mygam  2020 Q4 sample[5000]  837.
#> 13 Melbourne mygam  2021 Q1 sample[5000]  853.
#> 14 Melbourne mygam  2021 Q2 sample[5000]  910.
#> 15 Melbourne mygam  2021 Q3 sample[5000]  940.
#> 16 Melbourne mygam  2021 Q4 sample[5000]  898.
#> 17 Melbourne mygam  2022 Q1 sample[5000]  912.
#> 18 Melbourne mygam  2022 Q2 sample[5000]  970.
#> 19 Melbourne mygam  2022 Q3 sample[5000] 1001.
#> 20 Melbourne mygam  2022 Q4 sample[5000]  958.
# }
```
