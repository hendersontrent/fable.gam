
# fable.gam

This package provides a tidy R interface to time-series modelling using
[generalised additive
models](https://en.wikipedia.org/wiki/Generalized_additive_model) (GAMs)
using [fable](https://github.com/tidyverts/fable). This package makes
use of the [mgcv package](https://cran.r-project.org/package=mgcv) for
R. While not particularly common, GAMs have shown incredible utility in
time-series modelling, such as in the context of [palaeoecological
data](https://www.frontiersin.org/journals/ecology-and-evolution/articles/10.3389/fevo.2018.00149/full).
This package aims to incorporate the broad conceptual approach of using
[structural time-series
models](https://blog.tensorflow.org/2019/03/structural-time-series-modeling-in.html)
(i.e., decomposing a time series into its trend, seasonality, error, and
other components and modelling them additively) within a GAM setup into
the incredible `fable` forecasting framework.

## Installation

You can install the development version of `fable.gam` from GitHub using
the following:

``` r
devtools::install_github("hendersontrent/fable.gam")
```

## Quick tour

``` r
library(tsibble)
library(dplyr)
library(fable)
library(fable.gam)
```

Just like in the [`fable`
vignette](https://fable.tidyverts.org/articles/fable.html) we are going
to try and forecast the number of domestic travellers to Melbourne,
Australia. In the
[`tsibble::tourism`](https://tsibble.tidyverts.org/reference/tourism.html)
data set, this can be further broken down into 4 reasons of travel:
`“business”`, `“holiday”`, `“visiting friends and relatives”` and
`“other reasons”`. The variable we are going to try and forecast is the
number of overnight trips (000s) represented by the `Trips` variable. We
can load the dataset and visualise the time series as follows:

``` r
tourism_melb <- tourism %>%
  filter(Region == "Melbourne")

tourism_melb %>%
  autoplot(Trips)
```

![](README_files/figure-gfm/unnamed-chunk-4-1.png)<!-- -->

Thanks to the excellent `tsibble` data structure for storing time-series
data in R we know that this data is sampled quarterly. With that in
mind, we are going to fit a simple time-series GAM using a (non)linear
trend term and a seasonal term with a periodicity of 4. This is made
easy in `fable.gam` through the usage of the `fabletools` ‘special’
functions `trend` and `season` which have been modified in `fable.gam`
for the purposes of GAMs. Under the hood, `fable.gam` parses a `trend()`
call as modelling a smooth function over time to capture temporal
effects and a `season()` call as a smooth function using a [cyclic cubic
basis
spline](https://fromthebottomoftheheap.net/2014/05/09/modelling-seasonal-data-with-gam/)
to ensure that over the duration of the time series, the start and end
of a seasonal term connects (e.g., for data measured on a monthly basis,
the end of final month – December – needs to connect continuously to the
start of the following January).

Here is how easy this is to do in `fable.gam` through the `GAM()`
function integrated into the `fable` interface:

``` r
fit <- tourism_melb %>%
  model(mygam = GAM(Trips ~ trend() + season(4)))
```

We can then easily pipe into the rest of the `fable` functionality, such
as the `forecast` to produce forecasts. Here are automatic forecasts
using the GAM for the next 5 years:

``` r
fc <- fit %>%
  forecast(h = "5 years")

fc %>%
  autoplot(tourism_melb)
```

![](README_files/figure-gfm/unnamed-chunk-6-1.png)<!-- -->

We could then quantify model accuracy using the `accuracy` function in
`fable`:

``` r
fit %>%
  accuracy() %>%
  arrange(MASE)
```

    # A tibble: 4 × 13
      Region    State   Purpose .model .type       ME  RMSE   MAE    MPE  MAPE  MASE
      <chr>     <chr>   <chr>   <chr>  <chr>    <dbl> <dbl> <dbl>  <dbl> <dbl> <dbl>
    1 Melbourne Victor… Busine… mygam  Trai… 1.28e-13  49.6  39.5 -1.28   8.67 0.636
    2 Melbourne Victor… Holiday mygam  Trai… 2.10e-13  46.7  36.3 -0.867  7.22 0.659
    3 Melbourne Victor… Other   mygam  Trai… 2.99e-14  19.1  15.8 -4.63  18.0  0.709
    4 Melbourne Victor… Visiti… mygam  Trai… 1.19e-13  62.1  50.5 -1.09   8.39 0.805
    # ℹ 2 more variables: RMSSE <dbl>, ACF1 <dbl>

Another common task is to extract point forecasts and confidence
intervals from the forecast distribution. The
[`hilo`](https://pkg.mitchelloharawild.com/distributional/reference/hilo.html)
function from the
[`distributional`](https://github.com/mitchelloharawild/distributional)
package knows how to automatically handle models fit in `fable`:

``` r
fc %>%
  hilo(level = c(80, 95))
```

    # A tsibble: 80 x 9 [1Q]
    # Key:       Region, State, Purpose, .model [4]
       Region    State    Purpose  .model Quarter
       <chr>     <chr>    <chr>    <chr>    <qtr>
     1 Melbourne Victoria Business mygam  2018 Q1
     2 Melbourne Victoria Business mygam  2018 Q2
     3 Melbourne Victoria Business mygam  2018 Q3
     4 Melbourne Victoria Business mygam  2018 Q4
     5 Melbourne Victoria Business mygam  2019 Q1
     6 Melbourne Victoria Business mygam  2019 Q2
     7 Melbourne Victoria Business mygam  2019 Q3
     8 Melbourne Victoria Business mygam  2019 Q4
     9 Melbourne Victoria Business mygam  2020 Q1
    10 Melbourne Victoria Business mygam  2020 Q2
    # ℹ 70 more rows
    # ℹ 4 more variables: Trips <dist>, .mean <dbl>, `80%` <hilo>, `95%` <hilo>

Hopefully this is starting to highlight the power of why integrating new
methods into the `fable` framework rather than writing bespoke pipelines
is so powerful!

### Comparison to other common time-series methods

We can perform a quick sense-check of the approach against more
commonly-used forecasting methods such as [exponential
smoothing](https://otexts.com/fpp3/expsmooth.html). Here we will just
specify an additive trend for the ETS model and let the other components
be determined automatically. We will also log-transform the response
variable to show that `fable.gam` handles these transformations
automatically as well, just like all models in `fable`.

``` r
tourism_melb %>%
  model(
    mygam = GAM(log(Trips) ~ trend() + season(4)),
    ets = ETS(log(Trips) ~ trend("A"))
  ) %>%
  forecast(h = "5 years") %>%
  autoplot(tourism_melb)
```

![](README_files/figure-gfm/unnamed-chunk-9-1.png)<!-- -->

Or maybe we want to compare against an [ARIMA
model](https://otexts.com/fpp3/arima.html):

``` r
tourism_melb %>%
  model(
    mygam = GAM(Trips ~ trend() + season(4)),
    arima = ARIMA(Trips)
  ) %>%
  forecast(h = "5 years") %>%
  autoplot(tourism_melb)
```

![](README_files/figure-gfm/unnamed-chunk-10-1.png)<!-- -->

## Development notes

`fable.gam` is very much a work in progress. Not all current `fable`
model functionality has been integrated yet and there may be issues with
model estimation until further testing and validation is performed.
