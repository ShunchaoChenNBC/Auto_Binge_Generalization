CREATE OR REPLACE TABLE
  `nbcu-ds-sandbox-a-001.Shunchao_Ad_Hoc.Auto_Binge_Case_01` AS
SELECT
  * EXCEPT (Player_Event,Binge_Details,Binge_Type,grp,Episode_Time,New_Watch_Time_01,New_Watch_Time_02)
FROM
  `nbcu-ds-sandbox-a-001.Shunchao_Ad_Hoc.Auto_Binge_Case_01`
