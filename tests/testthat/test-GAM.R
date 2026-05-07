library(dplyr)
library(fable)
library(fable.gam)

tourism_melb <- tsibble::tourism |>
  filter(Region == "Melbourne") |>
  filter(Purpose == "Business") |>
  dplyr::select(c(Quarter, Region, Trips)) |>
  as_tsibble(key = Region, index = Quarter)

test_that("GAM works", {

  fit <- tourism_melb |>
    model(mygam = GAM(Trips ~ trend() + season(4)))

  expect_equal(2, length(fit))
})
