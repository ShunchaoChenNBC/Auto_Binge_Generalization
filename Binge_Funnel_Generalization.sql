declare adobe_START_Date DATE DEFAULT "2023-02-15";
declare adobe_END_Date DATE DEFAULT "2023-03-16";
declare Source_Title string DEFAULT "bel-air";
declare Reached_Title string DEFAULT "grand crew";


with ID as 
( select Adobe_Tracking_ID,
  min(Adobe_Timestamp) as start
from `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where Final_Watch_Time > 0
and  Video_Start_Type in  ('Auto-Play', 'Clicked-Up-Next')
and Display_Name = Reached_Title and Feeder_Video = Source_Title
and Adobe_Date between adobe_START_Date and adobe_END_Date
group by 1),

ms as (
select Adobe_Tracking_ID,
  min(Adobe_Timestamp) as start,
  round(sum(Final_Watch_Time)/3600,2) as total_hours
from `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where Final_Watch_Time > 0
and Video_Start_Type = 'Manual-Selection'
and Display_Name = Reached_Title
and Adobe_Date between adobe_START_Date and adobe_END_Date
group by 1
),

Combination as 
(-- Binge Funnel Stageg 1: Total Watches & # accounts
select 
'Watched Source Title' As Category,
count(distinct Adobe_Tracking_ID) as Accounts, 
round(sum(num_seconds_played_no_ads)/3600,2) as Hours_Watched
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_VIDEO`
where lower(display_name) = Source_Title and adobe_date between adobe_START_Date and adobe_END_Date and num_seconds_played_no_ads>0
union all
-- Binge Funnel Stage 2: Total watches & accounts Auto-Binge
SELECT 
'Auto-played to Reached Title' as Category,
count(distinct Adobe_Tracking_ID) as Accounts, 
round(sum(Final_Watch_Time)/3600,2) as Hours_Watched
FROM `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where Adobe_Date between adobe_START_Date and adobe_END_Date and Video_Start_Type in ("Auto-Play", "Clicked-Up-Next") and lower(Feeder_video) = Source_Title and lower(Display_Name) = Reached_Title
and Final_Watch_Time > 0
union all
-- Binge Funnel Stage 3: Return Watching
select 
'Returned to watch Reached Title' as Category,
count(distinct ID.Adobe_Tracking_ID) returning_accts,
round(sum(ms.total_hours),2) returning_hours
from ID, ms
where ID.Adobe_Tracking_ID = ms.Adobe_Tracking_ID
AND ID.start < ms.start),

Combinations as 
(select c.*,
lag(Accounts) over (order by Accounts desc) as Eligible_Accounts
from Combination c
order by 2 desc)

select 
Cs.Category,
Cs.Accounts,
Cs.Eligible_Accounts,
round(Cs.Accounts/Cs.Eligible_Accounts,2) as Take_Rate,
Cs.Hours_Watched,
round(Cs.Hours_Watched/Cs.Accounts,2) as Hours_Per_Account
from Combinations Cs;







