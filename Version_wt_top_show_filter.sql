create or replace table `nbcu-ds-sandbox-a-001.Shunchao_Ad_Hoc.Auto_Binge_Metadata_V4_Test` as

with Raw_Clicks as (SELECT
post_evar56 as Adobe_Tracking_ID, 
DATE(timestamp(post_cust_hit_time_gmt), "America/New_York") AS Adobe_Date,
DATETIME(timestamp(post_cust_hit_time_gmt), "America/New_York") AS Adobe_Timestamp,
post_evar19 as Player_Event,
post_evar7 as Binge_Details,
post_evar37 as device_name, -- Device_Info from Clickstream
SPLIT(post_prop47, '|')[SAFE_OFFSET(0)] as Binge_Type -- capture SLE
FROM `nbcu-ds-prod-001.feed.adobe_clickstream` 
WHERE post_evar56 is not null
and post_cust_hit_time_gmt is not null 
and post_evar7 is not null
and post_evar7 not like "%display"
and DATE(timestamp(post_cust_hit_time_gmt), "America/New_York") between "2023-01-26" and "2023-03-01"),

cte as (select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Video_Start_Type,
device_name,
Feeder_Video,
Feeder_Video_Id,
regexp_replace(lower(Display_Name), r"[:,.&'!]", '') as Display_Name,
video_id,
num_seconds_played_no_ads
from
(SELECT 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
case when Binge_Details like "%Series-cue-up%auto-play" then "Auto-Play"  -- Only care about series cue up, remove episode-cue-up
     when Binge_Details like '%cue%up%click' then "Clicked-Up-Next" 
     when Binge_Details like "%dismiss" then "Dismiss" 
     when Player_Event like "%details:%" and Binge_Details is not null then "Manual-Selection"
     when Binge_Details like '%deeplink%' then "Manual-Selection"
     when Binge_Details like 'rail%click'then "Manual-Selection" 
else null end as Video_Start_Type,
device_name,
"" Feeder_Video,
"" Feeder_Video_Id,
case when Player_Event like "%:episodes:%" and Binge_Details is not null then REGEXP_REPLACE(Player_Event, r'peacock:details:episodes:', '')
     when Player_Event like "%:upsell:%" and Binge_Details is not null then REGEXP_REPLACE(Player_Event, r'peacock:details:upsell:', '')
     when Player_Event like "%:more-like-this:%" and Binge_Details is not null then REGEXP_REPLACE(Player_Event, r'peacock:details:more-like-this:', '')
     when Player_Event like "%:extras:%" and Binge_Details is not null then REGEXP_REPLACE(Player_Event, r'peacock:details:extras:', '')
     when Player_Event like "%:details:%" and Binge_Details is not null then REGEXP_REPLACE(Player_Event, r'peacock:details:', '')
     when Binge_Details like "%auto-play" then  REGEXP_EXTRACT(Binge_Details, r"[|][|](.*)[|]")
     when Binge_Details like '%cue%up%click' then  REGEXP_EXTRACT(Binge_Details, r"[|][|](.*)[|]")
     when Binge_Details like 'rail%click'then REGEXP_EXTRACT(Binge_Details, r"[|]([a-zA-Z0-9\s-.:]+)[|]click")
else null end as Display_Name,
"" video_id,
null num_seconds_played_no_ads
FROM Raw_Clicks)
where Video_Start_Type is not null and Display_Name is not null and Display_Name != ""), -- slove the missing data issue

click_Ready as (select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Video_Start_Type,
device_name,
Feeder_Video, -- keep the feeder video blank
Feeder_Video_Id,
Display_Name,
video_id,
num_seconds_played_no_ads
from cte),

-------- Mapping for epsiode to series, channel issues, and remove linear channels-------------------------


sv_mapping as (
select regexp_replace(lower(episode_title), r"[:,.&'!]", '') as Epsiodes, 
case when length(display_name) <= 4 
          or lower(display_name) like "%tv" 
          or lower(display_name) like "%)" 
          or lower(display_name) like "%-dt"
          or lower(display_name) like "%premium"
          or lower(display_name) in ('ktvh-dt','ksnv-dt','Kgwn.2') -- add extreme cases here
          or regexp_contains(display_name, r"(W)[a-zA-Z0-9]+-[a-zA-Z0-9]")
          or regexp_contains(display_name, r"(K)[a-zA-Z0-9]+-[a-zA-Z0-9]")
          then null 
          else regexp_replace(lower(display_name), r"[:,.&'!]", '') --clean series here
          end as Series,-- remove platform names
count (display_name) as Display_Time
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_VIDEO`
where 1=1
and episode_title is not null 
and lower(episode_title) not in ('yellowstone',
                                'quantum leap',
                                'dateline nbc',
                                'pft live',
                                'americas got talent all stars') -- extend the list to fix the wrong raw data
and adobe_date = current_date("America/New_York")-1
group by 1,2
),

Mapping_Middle as (
select Epsiodes, 
Series,
dense_rank() over (partition by Epsiodes order by Display_Time desc) as rk
from sv_mapping
where Series is not null and Series != "N/a" and Epsiodes is not null and Epsiodes != "n/a"
order by 3 desc),

Mapping as (
select regexp_replace(lower(Epsiodes), r"[:,.&'!]", '') as Epsiodes, 
Series
from Mapping_Middle
where rk = 1 --- Only keep the highest value
and regexp_replace(lower(Epsiodes), r"[:,.&'!]", '')  not in ("poker face") -- Exclude the cases (Series Name are the sames as Epsiode Names)
),

Combinations as (
select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Video_Start_Type,
device_name,
Feeder_Video, 
Feeder_Video_Id,
case when m.Series is not null then m.Series else regexp_replace(lower(cr.Display_Name), r"[:,.&'!]", '') end as Display_Name,
video_id,
num_seconds_played_no_ads
from click_Ready cr
left join Mapping m on m.Epsiodes = regexp_replace(lower(cr.Display_Name), r"[:,.&'!]", '')
),


-----------------------------------------------------------------------------------


SV as (
select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Video_Start_Type,
device_name,
Lag(Display_Name) over (partition by adobe_tracking_id,adobe_date order by adobe_timestamp) as Feeder_Video, --if finish an epsiode before 00:00 AM and then watch another one after 00:00 Am will be "Manual" 
Lag(video_id) over (partition by adobe_tracking_id,adobe_date order by adobe_timestamp) as Feeder_Video_Id,
Display_Name,
video_id,
num_seconds_played_no_ads
FROM (
SELECT
adobe_tracking_id as Adobe_Tracking_ID,
adobe_date as Adobe_Date,
TIMESTAMP_ADD(adobe_timestamp , INTERVAL -40 second) as Adobe_Timestamp,
"" Player_Event,
"" Binge_Details,
"" Binge_Type,
case when lower(Display_Name) = "n/a" then lower(program) else lower(Display_Name) end as Display_Name, -- replace N/a by program name, 
case when lower(Display_Name) like '%trailer%' then 'Manual-Selection' else'Vdo_End' end as Video_Start_Type, --make all trailer ""
device_name,
video_id,
num_seconds_played_no_ads
FROM 
`nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_VIDEO` 
where adobe_tracking_ID is not null 
and adobe_date between "2023-01-26" and "2023-03-01" 
and media_load = False and num_seconds_played_with_ads > 0) as sv
where Video_Start_Type is not null and Display_Name is not null -- slove the missing data issue
),

middle_table as (select *
from Combinations
union all
select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Video_Start_Type,
device_name,
regexp_replace(lower(Feeder_Video), r"[:,.&'!]", '') as Feeder_Video,
Feeder_Video_Id,
regexp_replace(lower(Display_Name), r"[:,.&'!]", '') as Display_Name,
video_id,
num_seconds_played_no_ads
from SV),


cte2 as (select b.*,
sum(case when b.Feeder_Video = b.Display_Name then b.num_seconds_played_no_ads else 0 end) over (partition by Adobe_Tracking_ID, Adobe_Date, grp) as Episode_Time
from
(SELECT a.*,
lag(Video_Start_Type) over (partition by Adobe_Tracking_ID,adobe_date order by adobe_timestamp) as Last_Actions,
sum(case when Feeder_Video = Display_Name then 0 else 1 end) over (partition by Adobe_Tracking_ID, Adobe_Date order by Adobe_Timestamp) as grp -- intermediate feature
FROM 
middle_table a) b),

cte3 as 
(select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Last_Actions,
case when Feeder_Video is null and num_seconds_played_no_ads is not null then "Manual-Selection" 
when Feeder_Video like '%trailer%' then "Manual-Selection" -- all trailers are manual
when Last_Actions like '%Manual%' and Video_Start_Type = 'Vdo_End' then "Manual-Selection"
when Last_Actions = 'Auto-Play' and Video_Start_Type = 'Vdo_End'and Feeder_Video not like "%trailer%" then "Auto-Play" 
when Last_Actions = 'Clicked-Up-Next' and Video_Start_Type = 'Vdo_End'and Feeder_Video not like "%trailer%" then "Clicked-Up-Next" 
when Feeder_Video <> Display_Name and Episode_Time > 0 and num_seconds_played_no_ads is not null then "Auto-Play"-- episode attribution
when Feeder_Video <> Display_Name and Feeder_Video != "" and Episode_Time = 0 and num_seconds_played_no_ads <= 30 then "Auto-Play"--only watch one show and watch less than 30s
when Feeder_Video <> Display_Name and Feeder_Video != "" and Episode_Time = 0 and num_seconds_played_no_ads > 30 then "Unattributed" -- only watch one show and watch more than 30s
when Video_Start_Type = "Auto-Play" and (Feeder_Video is null or Feeder_Video = "") then "Manual-Selection" -- if cue-up auto but no feeder videos put it to Manual-Selection
else Video_Start_Type
end as Video_Start_Type,
device_name,
Feeder_Video,
Feeder_Video_Id,
Display_Name,
video_id,
num_seconds_played_no_ads,
case when (Feeder_Video is null 
or Feeder_Video <> Display_Name)
and (Last_Actions != "Clicked-Up-Next" or Video_Start_Type !=  "Clicked-Up-Next") -- Solve the double count issue in Click-Up-Next
then ifnull(num_seconds_played_no_ads,0) + Episode_Time else 0 end as New_Watch_Time
from cte2
order by 1,2,3)

select *
from cte3
order by 1,2,3
