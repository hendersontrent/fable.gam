#' Produce forecasts from the GAM
#'
#' If additional future information is required, such as exogenous variables,
#' then they should be included as variables of the `new_data` argument.
#'
#' @inheritParams fable::forecast.ARIMA
#' @param ... Additional arguments passed to [`stats::predict()`].
#'
#' @return A list of forecasts
#'
#' @author Trent Henderson
#'
#' @examples
#'
#' \donttest{
#' if (requireNamespace("tsibble")) {
#' library(tsibble)
#' tsibble::tourism %>%
#'   filter(Region == "Melbourne") %>%
#'   model(mygam = GAM(Trips ~ trend() + season(4))) %>%
#'   forecast(h = "5 years")
#' }
#' }
#'
#' @export
#'
forecast.fbl_gam <- function(object, new_data, specials = NULL, ...){
  model <- object$model
  idx_var <- tsibble::index_var(new_data)
  new_data$timevarnumeric <- as.numeric(new_data[[idx_var]])

  # Add any seasonal variables back

  for(season_spec in specials$season){
    period <- season_spec$period
    season_var <- paste0("season_", period)
    new_data[[season_var]] <- get_season_var(new_data, idx_var, period)
  }

  # Calculate predictions

  preds <- stats::predict(model, newdata = new_data, se.fit = TRUE, ...)
  distributional::dist_normal(preds$fit, preds$se.fit)
}

#-------------- Fitted values and residuals --------------

#' Extract fitted values
#'
#' Extracts the fitted values from an estimated GAM
#'
#' @inheritParams fable::fitted.ARIMA
#'
#' @return A vector of fitted values
#'
#' @author Trent Henderson
#'
#' @export
#'
fitted.fbl_gam <- function(object, ...){
  fitted(object$model)
}

#' Extract model residuals
#'
#' Extracts the residuals from an estimated GAM
#'
#' @inheritParams fable::residuals.ARIMA
#'
#' @return A vector of residuals
#'
#' @author Trent Henderson
#'
#' @export
#'
residuals.fbl_gam <- function(object, ...){
  residuals(object$model)
}

#-------------- Other methods --------------

#' @export
model_sum.fbl_gam <- function(x){
  "gam"
}

#' @export
format.fbl_gam <- function(x, ...){
  "GAM"
}

#' Glance a GAM
#'
#' Construct a single row summary of the GAM model.
#'
#' Contains a range of model fit statistics.
#'
#' @inheritParams generics::glance
#'
#' @return A one row tibble summarising the model's fit.
#'
#' @examples
#' if (requireNamespace("tsibble")) {
#' library(tsibble)
#' tsibble::tourism %>%
#'   filter(Region == "Melbourne") %>%
#'   model(mygam = GAM(Trips ~ trend() + season(4))) %>%
#'   glance()
#' }
#' @export
glance.fbl_gam <- function(x, ...){
  fit <- x$model
  tibble::tibble(
    r_squared = summary(fit)$r.sq,
    adj_r_squared = summary(fit)$r.sq,  # GAM doesn't always report adj R^2
    deviance = fit$deviance,
    df = fit$df.residual,
    log_lik = as.numeric(stats::logLik(fit)),
    AIC = stats::AIC(fit),
    BIC = stats::BIC(fit),
    edf = sum(fit$edf),
    GCV = fit$gcv.ubre,
    scale = fit$scale
  )
}

#' Present a tidy summary of a GAM
#'
#' @examples
#' if (requireNamespace("tsibble")) {
#' library(tsibble)
#' tsibble::tourism %>%
#'   filter(Region == "Melbourne") %>%
#'   model(mygam = GAM(Trips ~ trend() + season(4))) %>%
#'   tidy()
#' }
#' @export
tidy.fbl_gam <- function(x, ...){
  fit <- x$model
  summ <- summary(fit)
  coefs <- as.data.frame(summ$p.table)
  tibble::tibble(
    term = rownames(coefs),
    estimate = coefs[, "Estimate"],
    std.error = coefs[, "Std. Error"],
    statistic = coefs[, "t value"],
    p.value = coefs[, "Pr(>|t|)"]
  )
}

#' @export
report.fbl_gam <- function(object, digits = max(3, getOption("digits") - 3), ...){
  cat("\nGAM model report:\n")
  glance_obj <- glance(object)
  coef_tbl <- tidy(object)

  print(coef_tbl)

  cat(sprintf(
    "\nResidual deviance: %s on %s degrees of freedom\n",
    format(signif(glance_obj$deviance, digits)),
    format(glance_obj$df)
  ))
  cat(sprintf("AIC: %s\tBIC: %s\tLogLik: %s\n",
              format(signif(glance_obj$AIC, digits)),
              format(signif(glance_obj$BIC, digits)),
              format(signif(glance_obj$log_lik, digits))
  ))
  invisible(object)
}

#' @export
refit.fbl_gam <- function(object, new_data, specials = NULL, ...){
  train_gam(new_data, specials = specials, ...)
}
