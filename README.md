# Auto_Binge_Generalization

**Auto-Play Logic:**
    a.Clickstream records the title as “Auto-Play”
    b.Sliver video records the same title at the same time and the timestamp of that title in SV is next to the timestamp in Clickstream
    c.Watch more than one episode (The same title occurs consecutively >=2)
    d.Must has feeder video and the feeder video is not any trailer

**Manual Selection Logic:**
1. Clickstream captured “click” in cue-up
2. No feeder video recorded

**Notes:**
•	“New Watch Time” was replaced by “Final Watch Time”, which would be used for getting watching hours.
•	the time range started from “2023-01-01” and would be updated daily.
•	Columns “gre” and “Episode_Time” are intermediate columns that can be ignored in daily usage.
•	“Binge_Type” is the new feature for capturing “SLE”. It has 2 values in “Binge_Type”: “Cue-Up’ and “SLE”. “Cue-Up” includes “Series Cue Up” and “Programme Cue Up” 2 situations.
•	“Player Event” and “Binge Details” columns store original clickstream records and can be ignored in daily usage as well.
•	Return rate will be probably down in the upgraded version because the timestamp discrepancy between Sliver Video and Clickstream was eliminated 

