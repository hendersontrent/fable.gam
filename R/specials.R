specials_gam <- new_specials(
  trend = function(){
    list(term = "trend")
  },
  trend2 = function(k = -1, bs = "tp"){
    list(k = k,
         bs = bs)
  },
  season = function(period){
    list(period = period)
  },
  xreg = function(..., smooth = FALSE, k = -1, bs = "tp"){
    if(!is.logical(smooth) || length(smooth) != 1){
      abort("`smooth` must be TRUE or FALSE.")
    }
    dots <- enquos(...)
    xreg_df <- tibble::tibble(!!!dots)
    list(xreg_df = xreg_df, smooth = smooth, k = k, bs = bs)
  },
  errors = function(ar = 1){
    if(!is.numeric(ar) || length(ar) != 1 || ar < 1 || ar != floor(ar)){
      abort("`ar` must be a single positive integer.")
    }
    list(ar = as.integer(ar))
  }
)
