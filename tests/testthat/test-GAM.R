library(dplyr)
library(fable)
library(fable.gam)

tourism_melb <- tourism %>%
  filter(Region == "Melbourne")

test_that("GAM works", {

  fit <- tourism_melb %>%
    model(mygam = GAM(Trips ~ trend() + season(4)))

  expect_equal(4, length(fit))
})
