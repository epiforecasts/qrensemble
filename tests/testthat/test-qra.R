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
