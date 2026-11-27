forecasts <- scoringutils::example_quantile |>
  scoringutils::as_forecast_quantile()

test_that("qra works", {
  res <- qra(
    forecasts,
    group = c("target_type", "location", "location_name"),
    target = c(target_end_date = "2021-07-24")
  )
  expect_snapshot(res)
})

test_that("qra produces sensible results in trivial cases", {
  forecasts <- scoringutils::as_forecast_quantile(data.frame(
    model = rep(c("model2", "model1"), each = 2),
    observed = rep(1, 4),
    predicted = rep(c(0, 1), each = 2),
    quantile_level = rep(0.5, 4),
    time = rep(c(0, 1), time = 2)
  ))
  res <- qra(
    forecasts,
    target = c(time = 1)
  )
  expect_equal(attr(res, "weights")[model == "model1"]$weight, 1)
})

test_that("qra does not depend on the row order of the target forecasts", {
  forecasts <- data.table::data.table(
    model = rep(c("good", "bad"), each = 6),
    time = rep(rep(1:3, each = 2), 2),
    site = rep(c("a", "b"), 6),
    observed = rep(c(10, 100, 20, 200, 30, 300), 2)
  )
  forecasts <- rbind(
    data.table::copy(forecasts)[, quantile_level := 0.25],
    data.table::copy(forecasts)[, quantile_level := 0.75]
  )
  forecasts[, predicted := ifelse(model == "good", observed, 50)]
  ## list the target rows with the models and sites in reverse order
  forecasts <- rbind(
    forecasts[time != 3],
    forecasts[time == 3][order(model, -rank(site))]
  )
  res <- qra(
    scoringutils::as_forecast_quantile(forecasts),
    target = c(time = 3)
  )
  expect_equal(attr(res, "weights")[model == "good"]$weight, c(1, 1))
  expect_equal(res$predicted, res$observed)
})
