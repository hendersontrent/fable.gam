
#-------------- Forecasts --------------

forecast.fbl_gam <- function(object, new_data, specials = NULL, ...) {
  model <- object$model
  idx_var <- tsibble::index_var(new_data)
  new_data$..time <- as.numeric(new_data[[idx_var]])

  # Add any seasonal variables back

  for (season_spec in specials$season) {
    period <- season_spec$period
    season_var <- paste0("..season_", period)
    new_data[[season_var]] <- cycle_id(new_data, period)
  }

  preds <- predict(model, newdata = new_data, se.fit = TRUE)
  distributional::dist_normal(preds$fit, preds$se.fit)
}

#-------------- Fitted values and residuals --------------

fitted.fbl_gam <- function(object, ...) {
  fitted(object$model)
}

residuals.fbl_gam <- function(object, ...) {
  residuals(object$model)
}
