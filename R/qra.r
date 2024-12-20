##' Create a qra ensemble
##'
##' @param x input data frame containing \code{model}, \code{quantile},
##'   \code{boundary}, \code{value}, \code{interval} columns.
##' @param target input data frame
##'   \code{boundary}, \code{value}, \code{interval} columns.
##' @return data frame with weights per quantile (which won't vary unless
##'   \code{per_quantile_weights} is set to TRUE), per model
##' @param per_quantile_weights logical; whether to estimate weights per
##'   quantile
##' @param enforce_normalisation logical; whether to enforce quantiles
##' @param intercept logical; whether to estimate and intercept
##' @param noncross logical; whether ot enforce non-crosssing of quantiles
##' @param ... passed to [quantgen::predict.quantile_ensemble()]; of particular
##'   interest might be setting \code{iso = TRUE} for isotonic regression
##' @importFrom quantgen quantile_ensemble
##' @importFrom stats predict
##' @importFrom data.table := CJ data.table
##' @autoglobal
##' @keywords internal
qra_create_ensemble <- function(x, target, per_quantile_weights, intercept,
                                enforce_normalisation, noncross,
                                ...) {
  ## prepare data table
  train <- qra_preprocess_forecasts(x)
  test <- qra_preprocess_forecasts(target)

  tau <- train$quantile_levels

  if (per_quantile_weights) {
    tau_groups <- seq_along(tau)
  } else {
    tau_groups <- rep(1, length(tau))
  }

  qe <- quantile_ensemble(
    train$predictions, train$data, tau, tau_groups = tau_groups,
    nonneg = enforce_normalisation, unit_sum = enforce_normalisation,
    intercept = intercept, noncross = noncross, time_limit = 60
  )

  pred <- predict(qe, test$predictions, ...)
  target_forecast <- unique(target[, !c("observed", "predicted", "model")])
  target_forecast <- target_forecast[, predicted := c(pred)]
  target_forecast <- target_forecast[,
    observed := rep(test$data, times = length(tau))
  ]

  ## retrieve weights from optimisation
  if (per_quantile_weights) {
    if (intercept) {
      weights <- c(t(qe$alpha[-1, ]))
      intercepts <- qe$alpha[1, ]
    } else {
      weights <- c(t(qe$alpha))
      intercepts <- rep(0, each = length(tau))
    }
  } else if (intercept) {
    weights <- rep(qe$alpha[-1], each = length(tau))
    intercepts <- qe$alpha[1]
  } else {
    weights <- rep(qe$alpha, each = length(tau))
    intercepts <- rep(0, each = length(tau))
  }

  ## create return tibbles
  wtb <- CJ(
    model = unique(x$model),
    quantile = unique(x$quantile_level),
    sorted = FALSE
  )[, weight := weights]

  itb <- data.table(
    quantile = unique(x$quantile),
    intercept = intercepts
  )
  return(list(
    weights = wtb,
    intercepts = itb,
    ensemble = target_forecast
  ))
}

#' Preprocess forecasts for QRA
#'
#' This splits forecasts into data and forecast, and excludes any models that
#' have missing forecasts
#' @inheritParams qra
#' @return A list with three elements: `predictions` (a data.table only
#' containing the predictions), `data` (a data.table only containing the data)
#' and `models` (a data.table listing the models and whether they are
#' included)
#' @importFrom data.table setorder dcast as.data.table
#' @importFrom quantgen combine_into_array
#' @importFrom scoringutils get_forecast_unit
#' @keywords internal
qra_preprocess_forecasts <- function(forecast) {
  forecast_unit <- get_forecast_unit(forecast)
  setorder(forecast, "quantile_level")

  ## make forecast a pure data.table
  forecast <- as.data.table(forecast)

  ## create data vector
  data <- forecast[,
    list(observed = unique(observed)), by = c(setdiff(forecast_unit, "model"))
  ][, observed]

  ## create prediction arrays
  pred_matrices <- forecast[, !"observed"]
  pred_matrices <- split(pred_matrices, by = "model")
  pred_matrices <- lapply(pred_matrices, function(x) {
    dt <- dcast(x, ... ~ quantile_level, value.var = "predicted")
    dt[, paste(forecast_unit) := NULL]
    return(as.matrix(dt))
  })
  ## combine into array
  pred_arrays <- combine_into_array(pred_matrices)

  quantile_levels <- unique(forecast$quantile_level)

  return(
    list(
      predictions = pred_arrays,
      data = data,
      quantile_levels = quantile_levels
    )
  )
}

#' Split forecast
#'
#' Splits forecast into data and forecast, excludes any models aren't complete,
#' and splits out the forecast target
#' @inheritParams qra
#' @return a list with forecast (the forecast with models removed that have
#'   missing forecasts, and the target forecasts removed)
#' @importFrom data.table merge.data.table as.data.table
#' @importFrom scoringutils get_forecast_unit
#' @keywords internal
#' @autoglobal
split_forecast <- function(forecast, forecast_unit, target) {
  forecast_unit <- get_forecast_unit(forecast)
  ## make forecast a pure data.table
  forecast <- as.data.table(forecast)
  ## check for missing values by first creating a complete set of grouping and
  ## pooling variables
  present <- unique(
    forecast[,
      c(setdiff(forecast_unit, "model"), "quantile_level"), with = FALSE
    ]
  )
  complete_set <- present[, list(model = unique(forecast$model)), by = present]
  ## next,  merge into the data
  merged <- merge.data.table(
    forecast, complete_set, by = colnames(complete_set), all.y = TRUE
  )
  ## check for each model whether any column has an na
  models <- merged[, list(included = !anyNA(.SD)), by = model]
  present_models <- present[, as.list(models), by = present]

  ## remove models with missing forecasts
  forecast <- forecast[model %in% models[included == TRUE, model]]

  ## split off target
  target_forecast <- forecast[get(names(target)) == target]
  forecast <- forecast[get(names(target)) != target]

  return(
    list(
      forecast = forecast,
      target = target_forecast,
      models = present_models
    )
  )
}

##' @name qra
##' @title Quantile Regression Average
##' Calculates a quantile regression average for forecasts.
##' @param forecast a data.table representing forecast; this is expected to
##'   have been created using [scoringutils::as_forecast_quantile()]
##' @param target the target for which to create the quantile regression
##'   average. This should be given as a vector of form `column = target`,
##'   where target is the value of column that represents the target. Note that
##'   the column named here cannot be a grouping variable.
##' @param group any columns wihch to group a vector of character vectors (e.g.,
##'   "horizon", "geography_scale", etc.) indicating columns in the
##'   \code{forecasts} and \code{data} data frames; by default, will not group
##'   anything, i.e. create one ensemble model
##' @param model the name of the model to return; default: "Quantile Regression
##'   Average"
##' @param ... passed to [quantgen::predict.quantile_ensemble()]; of particular
##'   interest might be setting \code{iso = TRUE} for isotonic regression
##' @inheritParams qra_create_ensemble
##' @return a data.table representing the forecasts forecast, but with
##'   \code{model} set to the value of the `model parameter. This will be in the
##'   forecast format produced by [scoringutils::as_forecast_quantile()]
##' @autoglobal
##' @importFrom data.table rbindlist setattr as.data.table
##' @importFrom purrr transpose map map2
##' @importFrom scoringutils as_forecast_quantile get_forecast_unit
##' @importFrom checkmate assert_class
##' @export
##' @examples
##' library("scoringutils")
##' example_quantile |>
##'   as_forecast_quantile() |>
##'   qra(
##'     group = c("target_type", "location", "location_name"),
##'     target = c(target_end_date = "2021-07-24")
##'   )
qra <- function(forecast, target, group = c(),
                model = "Quantile Regression Average",
                per_quantile_weights = FALSE, enforce_normalisation = TRUE,
                intercept = FALSE, noncross = TRUE, ...) {

  assert_class(forecast, "forecast_quantile")
  forecast_unit <- get_forecast_unit(forecast)

  ## filter out missing forecasts
  forecast <- as.data.table(forecast)
  forecast <- forecast[!is.na(predicted)]

  if (length(group) > 1) {
    ## first, split by group
    ensemble <- split(forecast, by = group)
  } else {
    ensemble <- list(forecast)
  }
  ## next, re-convert to forecast format
  ensemble <- map(ensemble, as_forecast_quantile, forecast_unit = forecast_unit)
  ## next, split off target forecasts and check for completeness
  ensemble <- transpose(map(ensemble, split_forecast, forecast_unit, target))
  ## now, determine weights and intercepts
  ensemble <- c(ensemble, transpose(map2(
    ensemble[["forecast"]], ensemble[["target"]],
    qra_create_ensemble,
    per_quantile_weights = per_quantile_weights,
    enforce_normalisation = enforce_normalisation,
    intercept = intercept,
    noncross = noncross, ...
  )))

  ## remove inputs
  ensemble[["forecast"]] <- NULL
  ensemble[["target"]] <- NULL

  ## pull together
  ensemble <- map(ensemble, rbindlist)

  ret <- as_forecast_quantile(ensemble[["ensemble"]][, model := ..model])
  setattr(ret, "weights", ensemble[["weights"]])
  setattr(ret, "intercept", ensemble[["intercept"]])
  setattr(ret, "models", ensemble[["models"]])
  setattr(ret, "class", c("forecast_quantile", "qra", class(ret)[-1]))

  return(ret)
}
