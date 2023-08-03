
create or replace table `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Monitoring` as


with cte as (select Adobe_Date, count(distinct Adobe_Tracking_ID) as Accts, round(sum(Final_Watch_Time)/3600,2) as Watched_Hours
from `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Prod`
where Adobe_Date Between "2023-06-01" and "2023-08-02" and Final_Watch_Time > 0
group by 1),

cte1 as (
select 
adobe_date,
count(distinct Adobe_Tracking_ID) as SV_Accts,
round(sum(num_seconds_played_no_ads)/3600,2) as SV_Watch_Hours
FROM `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_VIDEO` 
where Adobe_Date Between "2023-06-01" and "2023-08-02" and num_seconds_played_no_ads > 0
group by 1
)

select cte.*,
cte1.SV_Accts,
cte1.SV_Watch_Hours,
round(cte.Accts / cte1.SV_Accts,2) as Acct_Prc,
round(cte.Watched_Hours / cte1.SV_Watch_Hours,2) as Hours_Prc
from cte
left join cte1 on cte.adobe_date = cte1.adobe_date
order by 1 desc
