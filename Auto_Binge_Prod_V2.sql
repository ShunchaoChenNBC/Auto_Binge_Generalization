

--- Xfinity (Flex and X1) combination 
--- Google Tv & Android Tv combination
--- this is the version combine Xfinity and Google TV and also use the display name directly from clickstream to reduce running time
--- Fixed series up record not match silver video issue
-- removed consecutive auto-binge logic: when Feeder_Video <> Display_Name and Feeder_Video != "" and Episode_Time = 0 and num_seconds_played_no_ads > 1800 then "Unattributed" -- only watch one show and watch more than 30mins
-- removed: order by 1,2,9,3 -- order by ID, Date, Device, and then timestamp
-- remove: when Feeder_Video <> Display_Name and Episode_Time > 0 and num_seconds_played_no_ads is not null then "Auto-Play"-- episode attribution, get rid of consecutive watching
-- remove unattributed when Feeder_Video <> Display_Name and Feeder_Video != "" and Episode_Time = 0 and num_seconds_played_no_ads > 30 then "Unattributed" -- only watch one show and watch more than 30s

-- Optimized: 1. changed subquery to cte; 2. remove testing columns (e.g. grp); 3. remove ordering 4. filter out all 0 watched time 

DECLARE fromdate DATE DEFAULT "2023-09-12"; --FROM DATE
DECLARE todate DATE DEFAULT "2023-09-18";     --TO DATE


create or replace table `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.Auto_Binge_Metadata_Staging_091223_091823`  as

with Raw_Clicks as (SELECT
post_evar56 as Adobe_Tracking_ID, 
adobe_date_est AS Adobe_Date, -- align with Brian's code
DATETIME(timestamp(RevisedTimeStamp), "America/New_York") AS Adobe_Timestamp, -- align with Brian's code
post_evar19 as Player_Event,
lower(post_evar7) as Binge_Details, -- lower to make sure parsing work
CASE 
when LOWER(post_evar106)= 'chromecast' AND LOWER(post_evar37) = 'Chromecast Receiver App' then 'Chromecast Receiver App'
when LOWER(post_evar37) like '%xbox%' then 'xbox'
when LOWER(post_evar37) ='ps4' then 'playstation'
ELSE LOWER(post_evar37) end as device_name, -- Device_Info from Clickstream
SPLIT(post_prop47, '|')[SAFE_OFFSET(0)] as Binge_Type -- capture SLEfromdate
FROM `nbcu-ds-prod-001.feed.adobe_clickstream` 
WHERE post_evar56 is not null
and post_cust_hit_time_gmt is not null 
and post_evar7 is not null
and post_evar7 not like "%display%"
and lower(post_evar7) not like "%episode%cue%up%" -- make sure no episode cue up 
and DATE(timestamp(post_cust_hit_time_gmt), "America/New_York") between fromdate and todate),

cte1 as (
SELECT 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
case when Binge_Details like "%series%cue%up%auto%play%" then "Auto-Play" -- series binge not epsiode cue up
     when lower(Binge_Type) like "%sle%binge%" then "Auto-Play" -- also include SLE
     when Binge_Details like "%programme%cue%up%auto%play%" then "Auto-Play"  -- movies binge 
     when Binge_Details like '%series%cue%up%click%' then "Clicked-Up-Next" --- series Click-up-next not epsiode cue up
     when Binge_Details like '%programme%cue%up%click%' then "Clicked-Up-Next" --- movies Click-up-next not epsiode cue up
     when Player_Event like "%details:%" and Binge_Details is not null then "Manual-Selection"
     when Binge_Details like '%deeplink%' then "Manual-Selection" ---Deep Link
     when Binge_Details like '%rail%click%'then "Manual-Selection" --Rail Click
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
FROM Raw_Clicks
),



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
from cte1
where Video_Start_Type is not null
and Display_Name is not null and Display_Name != ""), -- slove the missing data issue and remove useless clickstream records (e.g. episode cue up)

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
          or lower(display_name) in ('ktvh-dt','ksnv-dt','Kgwn.2','kgwn2') -- add edge cases here
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
                                'americas got talent all stars',
                                'poker face') -- extend the list to fix the wrong raw data
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
case when m.Series is not null then m.Series else regexp_replace(lower(cr.Display_Name), r"[:,.&'!]", '') end as Display_Name, -- deal with missing value in display name
video_id,
num_seconds_played_no_ads
from click_Ready cr
left join Mapping m on m.Epsiodes = regexp_replace(lower(cr.Display_Name), r"[:,.&'!]", '')
),

-----------------------------------------------------------------------------------
SV_Raw as (
SELECT
adobe_tracking_id as Adobe_Tracking_ID,
adobe_date as Adobe_Date,
adobe_timestamp as Adobe_Timestamp,
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
and adobe_date between fromdate and todate
and media_load = False and num_seconds_played_with_ads > 0),

SV as (
select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Video_Start_Type,
case when lower(device_name) like "%xfinity%" then "xfinity" --- combine xfinity x1 and xfinity flex
when lower(device_name) like "%google%tv%" then "android tv" --- combine google tv and android tv
else lower(device_name) end as device_name,
Lag(Display_Name) over (partition by adobe_tracking_id,adobe_date order by adobe_timestamp) as Feeder_Video, --if finish an epsiode before 00:00 AM and then watch another one after 00:00 Am, will be "Manual" 
Lag(video_id) over (partition by adobe_tracking_id,adobe_date order by adobe_timestamp) as Feeder_Video_Id,
Display_Name,
video_id,
num_seconds_played_no_ads
FROM SV_Raw
where Video_Start_Type is not null and Display_Name is not null -- slove the missing data issue
),

middle_table as (
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
Display_Name,
video_id,
num_seconds_played_no_ads
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

cte2 as (
SELECT a.*,
lag(Video_Start_Type) over (partition by Adobe_Tracking_ID,adobe_date,device_name order by adobe_timestamp) as Last_Actions,
sum(case when Feeder_Video = Display_Name then 0 else 1 end) over (partition by Adobe_Tracking_ID, Adobe_Date, device_name order by Adobe_Timestamp) as grp -- intermediate feature
FROM 
middle_table a
),



cte3 as (select b.*,
sum(case when b.Feeder_Video = b.Display_Name then b.num_seconds_played_no_ads else 0 end) over (partition by Adobe_Tracking_ID, Adobe_Date, device_name, grp) as Episode_Time -- roll-over sum up
from cte2 b),

cte4 as 
(select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Last_Actions,
case when (Feeder_Video is null or Feeder_Video = "") and num_seconds_played_no_ads is not null then "Manual-Selection" 
when Feeder_Video like '%trailer%' then "Manual-Selection" -- all trailers are manual
when Last_Actions like '%Manual%' and Video_Start_Type = 'Vdo_End' then "Manual-Selection"
when Last_Actions = 'Auto-Play' 
and Video_Start_Type = 'Vdo_End'
and Feeder_Video not like "%trailer%" 
and LAG(Display_Name) over (partition by Adobe_Tracking_ID,adobe_date,device_name order by adobe_timestamp) = Display_Name 
and (Feeder_Video != Display_Name) 
then "Auto-Play" -- must a feeder and Feeder <> Display Name and Display Name match previous Display Name (clickstream)
when Last_Actions = 'Clicked-Up-Next' 
and Video_Start_Type = 'Vdo_End'
and Feeder_Video not like "%trailer%" 
and (Feeder_Video != Display_Name) 
then "Clicked-Up-Next" 
when Video_Start_Type = "Auto-Play" and (Feeder_Video is null or Feeder_Video = "") then "Manual-Selection" -- if cue-up auto but no feeder videos put it to Manual-Selection
else "Manual-Selection"
end as Video_Start_Type,
device_name,
Feeder_Video,
Feeder_Video_Id,
Display_Name,
video_id,
num_seconds_played_no_ads,
case when 
Feeder_Video is null 
or Feeder_Video = ""
or Feeder_Video <> Display_Name
then ifnull(num_seconds_played_no_ads,0) + Episode_Time 
else 0 end as New_Watch_Time_01,
case when LAG(Display_Name) over (partition by Adobe_Tracking_ID,adobe_date,device_name order by adobe_timestamp) != Display_Name 
and (LAG(Feeder_Video) over (partition by Adobe_Tracking_ID,adobe_date,device_name order by adobe_timestamp) is null 
or LAG(Feeder_Video) over (partition by Adobe_Tracking_ID,adobe_date,device_name order by adobe_timestamp) = "")
and Feeder_Video = Display_Name -- if 2 videos not equal, do not get time
then Episode_Time else 0 end as New_Watch_Time_02 --if record not match, then assign time to here
from cte3
order by 1,2,3),

cte5 as (select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Last_Actions,
Video_Start_Type,
device_name,
Feeder_Video,
Feeder_Video_Id,
Display_Name,
video_id,
case when (Feeder_Video = "" and lead(Feeder_Video) over (partition by Adobe_Tracking_ID,adobe_date,device_name order by adobe_timestamp) = "") 
or (Display_Name != lead(Display_Name) over (partition by Adobe_Tracking_ID,adobe_date,device_name order by adobe_timestamp) and num_seconds_played_no_ads is null)
then 0 else New_Watch_Time_01 end as New_Watch_Time_01, --- if current record and next record not consistent, then re-assign value
New_Watch_Time_02
from cte4)

select 
Adobe_Tracking_ID,
Adobe_Date,
Adobe_Timestamp,
Player_Event,
Binge_Details,
Binge_Type,
Last_Actions,
Video_Start_Type,
device_name as Device_Name, -- keep the name format consistent
Feeder_Video,
Feeder_Video_Id,
Display_Name,
video_id,
New_Watch_Time_01+New_Watch_Time_02 as Final_Watch_Time 
from cte5
where New_Watch_Time_01+New_Watch_Time_02>0


