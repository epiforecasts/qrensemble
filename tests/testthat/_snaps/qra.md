# qra works

    Code
      res
    Message
      Forecast type: quantile
      Forecast unit:
      location, target_end_date, target_type, location_name, forecast_date, horizon,
      and model
    Output
      
           quantile_level location target_end_date target_type location_name
                    <num>   <char>          <Date>      <char>        <char>
        1:          0.010       DE      2021-07-24       Cases       Germany
        2:          0.010       DE      2021-07-24       Cases       Germany
        3:          0.025       DE      2021-07-24       Cases       Germany
        4:          0.025       DE      2021-07-24       Cases       Germany
        5:          0.050       DE      2021-07-24       Cases       Germany
       ---                                                                  
      364:          0.950       IT      2021-07-24      Deaths         Italy
      365:          0.975       IT      2021-07-24      Deaths         Italy
      366:          0.975       IT      2021-07-24      Deaths         Italy
      367:          0.990       IT      2021-07-24      Deaths         Italy
      368:          0.990       IT      2021-07-24      Deaths         Italy
           forecast_date horizon predicted observed                       model
                  <Date>   <num>     <num>    <num>                      <char>
        1:    2021-07-05       3  688.0000    10616 Quantile Regression Average
        2:    2021-07-12       2 1821.0000    10616 Quantile Regression Average
        3:    2021-07-05       3  792.0000    10616 Quantile Regression Average
        4:    2021-07-12       2 2002.0000    10616 Quantile Regression Average
        5:    2021-07-05       3  913.0000    10616 Quantile Regression Average
       ---                                                                     
      364:    2021-07-12       2  246.3120       78 Quantile Regression Average
      365:    2021-07-05       3  208.4875       78 Quantile Regression Average
      366:    2021-07-12       2  278.7647       78 Quantile Regression Average
      367:    2021-07-05       3  245.7201       78 Quantile Regression Average
      368:    2021-07-12       2  317.7048       78 Quantile Regression Average

