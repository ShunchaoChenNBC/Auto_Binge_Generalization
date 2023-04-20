# Auto_Binge_Generalization

**Auto-Play Logic:**
1. Logic 1:
<br /> • Clickstream records the title as “Auto-Play”
<br /> • Sliver video records the same title at the same time and the timestamp of that title in SV is next to the timestamp in Clickstream
<br /> • Must has feeder video and the feeder video is not any trailer

2. Logic 2:
<br /> • Watch more than one episode (The same title occurs consecutively >=2)
<br /> • Must has feeder video and the feeder video is not any trailer

**Manual Selection Logic:**
<br /> • Clickstream captured “click” in cue-up
<br /> • No feeder video recorded

**Notes:**

<br />•	“New Watch Time” was replaced by “Final Watch Time”, which would be used for getting watching hours.
<br />•	the time range started from “2023-01-01” and would be updated daily.
<br />•	Columns “gre” and “Episode_Time” are intermediate columns that can be ignored in daily usage.
<br />•	“Binge_Type” is the new feature for capturing “SLE”. It has 2 values in “Binge_Type”: “Cue-Up’ and “SLE”. “Cue-Up” includes “Series Cue Up” and “Programme Cue Up” 2 situations.
<br />•	“Player Event” and “Binge Details” columns store original clickstream records and can be ignored in daily usage as well.
<br />•	Return rate will be probably down in the upgraded version because the timestamp discrepancy between Sliver Video and Clickstream was eliminated 

