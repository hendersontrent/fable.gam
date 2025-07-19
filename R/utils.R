cycle_id <- function(tsbl, period) {
  idx <- tsibble::index(tsbl)
  seq_along(tsbl[[idx]]) %% period + 1
}

get_season_var <- function(data, idx, period) {
  index_vals <- data[[idx]]
  if (inherits(index_vals, "yearmonth") && period == 12) {
    return(lubridate::month(index_vals))
  } else if (inherits(index_vals, "yearquarter") && period == 4) {
    return(lubridate::quarter(index_vals))
  } else if (inherits(index_vals, "yearweek") && period == 52) {
    return(lubridate::isoweek(index_vals))
  } else if (inherits(index_vals, "Date") && period == 7) {
    return(lubridate::wday(index_vals, week_start = 1))
  }
  cycle_id(data, period)
}
