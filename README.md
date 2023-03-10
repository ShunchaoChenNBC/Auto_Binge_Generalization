# Auto_Binge_Generalization

Auto-Play Logic:
1.   	Only watch a show and watch time <= 30 seconds
2.   	a.Clickstream records the title as “Auto-Play”
            b.Sliver video records the same title at the same time and the timestamp of that title in SV is next to the timestamp in Clickstream
            c.Watch more than one episode (The same title occurs consecutively >=2)
            d.Must has feeder video and the feeder video is not any trailer

Manual Selection Logic:
Clickstream captured “click” in cue-up
No feeder video recorded
