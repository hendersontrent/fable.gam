cycle_id <- function(tsbl, period) {
  idx <- tsibble::index(tsbl)
  seq_along(tsbl[[idx]]) %% period + 1
}

# cycle_id <- function(tsbl, period) {
#   idx <- tsibble::index(tsbl)
#   time <- tsbl[[idx]]
#   if (period == 12) return(lubridate::month(time))
#   if (period == 4) return(lubridate::quarter(time))
#   if (period == 7) return(lubridate::wday(time))
#   return(seq_along(time) %% period + 1)
# }
