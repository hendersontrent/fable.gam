#' Generate future sample paths from a GAM
#'
#' Generates simulated future sample paths from a fitted `GAM`. Innovations are
#' resampled from the in-sample residuals, giving a non-parametric empirical bootstrap.
#'
#' @param x \code{fbl_gam} model object
#' @param new_data \code{tsibble} of future time points at which to generate paths
#' @param specials Parsed specials from the model formula
#' @param ... arguments to be passed to methods
#'
#' @author Trent Henderson
#' @export
#'
generate.fbl_gam <- function(x, new_data, specials = NULL,  ...){
  new_data <- prepare_gam_newdata(new_data, specials)
  pred <- stats::predict(x$model, newdata = new_data, se.fit = FALSE, type = "response")
  res <- stats::residuals(x$model, type = "response")
  innov <- sample(na.omit(res) - mean(res, na.rm = TRUE), NROW(new_data), replace = TRUE)
  dplyr::transmute(new_data, .sim = pred + innov)
}

#' Produce forecasts from the GAM
#'
#' @inheritParams fable::forecast.ARIMA
#' @param ... arguments passed to \code{stats::predict()}.
#'
#' @return Vector of distributions
#'
#' @author Trent Henderson
#'
#' @examples
#'
#' \donttest{
#' library(dplyr)
#' library(tsibble)
#'
#' tourism_melb <- tsibble::tourism |>
#'   filter(Region == "Melbourne") |>
#'   filter(Purpose == "Business") |>
#'   dplyr::select(c(Quarter, Region, Trips)) |>
#'   as_tsibble(key = Region, index = Quarter)
#'
#' fit <- tourism_melb |>
#'   model(mygam = GAM(Trips ~ trend() + season(4)))
#'
#' # Analytic intervals
#'
#' forecast(fit, h = "5 years")
#'
#' # Bootstrap intervals
#'
#' forecast(fit, h = "5 years", bootstrap = TRUE)
#' }
#'
#' @export
#'
forecast.fbl_gam <- function(object, new_data, specials = NULL, ...){
  new_data <- prepare_gam_newdata(new_data, specials)
  model <- object$model
  fam_name <- model$family$family

  if(fam_name == "gaussian"){
    preds <- stats::predict(model, newdata = new_data, se.fit = TRUE, type = "response", ...)
    distributional::dist_normal(preds$fit, sqrt(preds$se.fit^2 + model$sig2))

  } else if(fam_name == "Gamma"){
    preds <- stats::predict(model, newdata = new_data, se.fit = TRUE, type = "link", ...)
    distributional::dist_lognormal(preds$fit, sqrt(preds$se.fit^2 + model$sig2))

  } else if(fam_name == "poisson"){
    preds <- stats::predict(model, newdata = new_data, se.fit = FALSE, type = "response", ...)
    distributional::dist_poisson(preds)

  } else if(startsWith(fam_name, "Negative Binomial")){
    preds <- stats::predict(model, newdata = new_data, se.fit = FALSE, type = "response", ...)
    theta <- model$family$getTheta(trans = TRUE)
    distributional::dist_negative_binomial(size = theta, prob = theta / (theta + preds))

  } else if(startsWith(fam_name, "Beta regression")){
    preds <- stats::predict(model, newdata = new_data, se.fit = FALSE, type = "response", ...)
    theta <- model$family$getTheta(trans = TRUE)
    distributional::dist_beta(shape1 = preds * theta, shape2 = (1 - preds) * theta)

  } else{
    rlang::abort(paste0(
      "Analytic forecast distributions are not implemented for family '", fam_name, "'. ",
      "Supported families: `gaussian`, `Gamma` (log link), `poisson` (log link), `nb` (log link), `betar` (logit link). ",
      "Use bootstrap = TRUE for other families."
    ))
  }
}

#-------------- Fitted values and residuals --------------

#' Extract fitted values
#'
#' Extracts the fitted values from an estimated GAM
#'
#' @inheritParams fable::fitted.ARIMA
#'
#' @return Vector of fitted values
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
#' @return Vector of residuals
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
  base <- if(!is.null(x$lme)) "GAM+AR" else "GAM"
  fam  <- x$model$family$family
  if(fam == "gaussian") return(base)
  label <- if(startsWith(fam, "Negative Binomial")) "NB"
           else if(startsWith(fam, "Beta regression")) "Beta"
           else fam
  paste0(base, "(", label, ")")
}

#' @export
format.fbl_gam <- function(x, ...){
  "GAM"
}

#' Glance a GAM
#'
#' Construct a single row summary of the GAM model. Contains a range of model fit statistics.
#'
#' @inheritParams generics::glance
#'
#' @return `tibble` summarising the model fit.
#'
#' @examples
#' \donttest{
#' library(dplyr)
#' library(tsibble)
#'
#' tourism_melb <- tsibble::tourism |>
#'   filter(Region == "Melbourne") |>
#'   filter(Purpose == "Business") |>
#'   dplyr::select(c(Quarter, Region, Trips)) |>
#'   as_tsibble(key = Region, index = Quarter)
#'
#' fit <- tourism_melb |>
#'   model(mygam = GAM(Trips ~ trend() + season(4))) |>
#'   glance()
#' }
#' @export
glance.fbl_gam <- function(x, ...){
  fit <- x$model

  # When gamm() is used (for AR errors), AIC/BIC/logLik come from the `lme` component

  if(!is.null(x$lme)){
    log_lik_val <- as.numeric(stats::logLik(x$lme))
    aic_val <- stats::AIC(x$lme)
    bic_val <- stats::BIC(x$lme)
  } else{
    log_lik_val <- as.numeric(stats::logLik(fit))
    aic_val <- stats::AIC(fit)
    bic_val <- stats::BIC(fit)
  }

  outs <- tibble::tibble(
    r_squared = summary(fit)$r.sq,
    deviance = if(!is.null(x$lme)) NA else fit$deviance,
    df = fit$df.residual,
    log_lik = log_lik_val,
    AIC = aic_val,
    BIC = bic_val,
    edf = sum(fit$edf),
    GCV = fit$gcv.ubre,
    scale = fit$sig2
  )

  return(outs)
}

#' Present a tidy summary of a GAM
#'
#' @param x \code{fbl_gam} object
#' @param ... arguments to be passed to methods
#'
#' @examples
#' \donttest{
#' library(dplyr)
#' library(tsibble)
#'
#' tourism_melb <- tsibble::tourism |>
#'   filter(Region == "Melbourne") |>
#'   filter(Purpose == "Business") |>
#'   dplyr::select(c(Quarter, Region, Trips)) |>
#'   as_tsibble(key = Region, index = Quarter)
#'
#' fit <- tourism_melb |>
#'   model(mygam = GAM(Trips ~ trend() + season(4))) |>
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

#' Interpolate missing values using the GAM
#'
#' Replaces `NA` values in the response variable with in-sample GAM predictions evaluated at those time points.
#'
#' @param object \code{fbl_gam} model object
#' @param new_data \code{tsibble} containing observations, some of which may be \code{NA}
#' @param specials Parsed specials from the model formula
#' @param ... arguments to be passed to methods
#'
#' @return The \code{new_data} tsibble with missing values replaced by GAM predictions.
#'
#' @author Trent Henderson
#'
#' @export
#'
interpolate.fbl_gam <- function(object, new_data, specials, ...){
  resp <- tsibble::measured_vars(new_data)[[1]]
  miss_val <- which(is.na(new_data[[resp]]))

  if(length(miss_val) == 0){
    return(new_data)
  }

  full_data <- prepare_gam_newdata(new_data, specials)
  pred <- stats::predict(object$model, newdata = full_data[miss_val, , drop = FALSE], se.fit = FALSE, type = "response")
  new_data[[resp]][miss_val] <- pred
  new_data
}
