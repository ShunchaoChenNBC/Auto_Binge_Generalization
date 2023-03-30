
## 1. ******** -Epsiode Epsiode Click-Next-Up changed to "Manual Selection"
select *
FROM `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where adobe_date = "2023-02-16" and adobe_tracking_id = "++yVclMRAEzQWbppshXo5duYAnnYeT7KID0paDipHns=";

## 2. Auto-Binge trigger the viewers to watch the show on the same day and click epsiode to see details "pdp-nav|details||episodes|click"
select *
FROM `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where adobe_date = "2023-02-16" and adobe_tracking_id = "++ztcjsOi64NuXIibrDCRTtnJ3Z/snn8OQsqzd/8Fqk=";

# 3. 0 day return watch: Auto-Play "Paul t goldman" and then watch "poker face", and go back to watch "Paul t goldman" again
select *
FROM `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where adobe_date = "2023-02-16" and adobe_tracking_id = "+2IcSiFRthXW5KtViUJobNkZz7lfVDlzlosYjswloWI=";

# 4. 0 day return watch:Auto-Play "Paul t goldman" and then watch "alex murdaugh death deception power", and go back to watch "Paul t goldman" again
select *
FROM `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where adobe_date = "2023-02-16" and adobe_tracking_id = "+35ujzuFfYF0ui037OVXyRdnBFZKMScjTR7CwEBQclM=";


#5. 0 day return watch: Auto-Play "Paul t goldman" and then watch "poker face", and go back to watch "Paul t goldman" again
select *
FROM `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where adobe_date = "2023-02-16" and adobe_tracking_id = "+HdRcX1gdEm725FY4mjQtFw7i329NOuyFcpuLVSTALs=";


#6. ********* Different Device "Www" and "Apple TV" interrupt the clickstrem
select *
FROM `nbcu-ds-sandbox-a-001.Shunchao_Sandbox_Final.Auto_Binge_Metadata_Beta`
where adobe_date = "2023-02-16" and adobe_tracking_id = "+LwpVTT69R9KTzheses0CnB4EDMwyUlUne88eqks72M=";


