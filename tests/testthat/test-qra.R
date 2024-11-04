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
