/*
********************************************************************************
TITLE: rxamb_turnaround.sql
PURPOSE: To identify any bottlenecks in the rx ambulatory pharamcies
AUTHOR: Anne Hoshor
*******************************************************************************/

with details_cte as (select max(rp.PHARMACY_NAME) as 'Pharmacy_Name',
max(odi.RX_NUM_FORMATTED_HX) as 'rx_number',
max(odi.fill_number) as 'fill_number',
max(rp.PHARMACY_ID) as 'Pharmacy_Id',
max(case when oao.ACTION_TYPE_C = 30 then oao.ACTION_DTTM_LOCAL end) as 'Entered_DtTm',
max(case when oao.ACTION_TYPE_C = 30 then ce.name end) as 'Entered_User',
max(case when oao.ACTION_TYPE_C = 45 then oao.ACTION_DTTM_LOCAL end) as 'Filled_DtTm',
max(case when oao.ACTION_TYPE_C = 45 then ce.name end) as 'Filled_User',
max(case when oao.ACTION_TYPE_C = 60 then oao.ACTION_DTTM_LOCAL end) as 'Verified_DtTm',
max(case when oao.ACTION_TYPE_C = 60 then ce.name end) as 'Verified_User', 
max(oaoi.action_id) as 'action_id',
max(concat(odi.ORDER_MED_ID,'-',odi.fill_number)) as 'order_med_id'

from order_disp_info odi 
  inner join order_med om on om.ORDER_MED_ID = odi.ORDER_MED_ID
    and om.ORDERING_MODE_C = '1' /*outpatient*/
  inner join CLARITY_DEP dep on dep.DEPARTMENT_ID = om.LOGIN_DEP_ID AND dep.SERV_AREA_ID IN ('51340984','9503','5134521') -- SA 10,5000,7500
inner join rx_phr rp on odi.FILL_PHR_ID = rp.PHARMACY_ID
  inner join ord_act_ord_info oaoi on oaoi.ORDER_ID = odi.ORDER_MED_ID
	and oaoi.ORDER_DATE = odi.CONTACT_DATE_REAL
  left outer join ord_act_flags oaf on oaf.action_id = oaoi.action_id
  left outer join FLAG_INFO flag on flag.RECORD_ID = oaf.RX_RESOLV_FLAG_ID
  inner join ORD_ACT_OT oao on oao.ACTION_ID = oaoi.ACTION_ID
    and oao.ACTION_TYPE_C in (30,45,60)/*pending Fill,Filled,Verified*/
  inner join CLARITY_EMP ce on ce.EPIC_EMP_ID = oao.USER_ID
  
  where odi.action_instant >= {{REPORT_START_DT}}  and odi.action_instant <= {{REPORT_END_DT}}
  and (rp.PHARMACY_ID in ({{C_PHA_NAME}}) OR NULLIF(COALESCE({{C_PHA_NAME}},'N'),'N') IS NULL)
  and (flag.RECORD_ID in ({{C_FLAG}}) OR NULLIF(COALESCE({{C_FLAG}},'N'),'N') IS NULL)
  and odi.FILL_SERVICE_DATE is not null
  and exists(select oao1.ACTION_ID from ORD_ACT_OT oao1 where oao1.ACTION_ID = oao.ACTION_ID
  and oao1.ACTION_TYPE_C = 60)
  and not odi.fill_Status_c = '100'
  and ( 
      (
         ({{C_REPORT_OPTIONS}}) = '2'  /*Clean*/
                                  and 
          not exists (select oaoi2.ORDER_ID from ord_act_ord_info oaoi2
	  inner join ord_act_flags oaf2 on oaf2.action_id = oaoi2.action_id
          inner join flag_info flag2 on flag2.record_id = oaf2.RX_RESOLV_FLAG_ID
          and flag2.record_id in ('90024','90025','90026','90027','90046001','90048000','90048145','90048147','9508','513122','513136','513159','51335')
          where  oaoi2.ORDER_ID = odi.ORDER_MED_ID
	  and oaoi2.ORDER_DATE = odi.CONTACT_DATE_REAL)
       )
                       
       or /*Rx Required Intervention*/

       (
           ({{C_REPORT_OPTIONS}}) = '3'
              and 
              flag.RECORD_ID in ('90024','90025','90026','90027','90046001','90048000','90048145','90048147','9508','513122','513136','513159','51335')     
       )
                              
        or /*Both*/
        
      (
            ({{C_REPORT_OPTIONS}}) = '1' OR NULLIF(COALESCE({{C_REPORT_OPTIONS}},'N'),'N') IS NULL
            
      )
)  
  
group by odi.ORDER_MED_ID,odi.fill_number
)
,flag_cte as (select max(oaf.ACTION_ID) as 'action_id',
string_agg(cast(flag.display_name as varchar(max)),',') as 'flag_list'
,string_agg(cast(flag.record_id as varchar(max)),',') as 'flag_ids'

from ord_act_flags oaf  
	inner join details_cte details_cte on oaf.ACTION_ID = details_cte.action_id 
	inner join FLAG_INFO flag on flag.RECORD_ID = oaf.RX_RESOLV_FLAG_ID
	inner join flg_map flg_map on flg_map.community_id = flag.record_id
where (flag.RECORD_ID in ({{C_FLAG}}) OR NULLIF(COALESCE({{C_FLAG}},'N'),'N') IS NULL)
group by details_cte.action_id 
)

,turnarnd_cte as (select 

details_cte.Pharmacy_Id as 'Pharmacy_Id',
details_cte.ORDER_MED_ID as 'ORDER_MED_ID',
--Time To Filled(entered_dttm, filled_dttm)
--Hour portion
  concat(
  case 
     when cast(datediff(second,details_cte.Entered_DtTm,details_cte.Filled_DtTm)/3600 as int) < 9 
	   Then '0' + cast(datediff(second,details_cte.Entered_DtTm,details_cte.Filled_DtTm)/3600 as varchar) 
	 else cast(datediff(second,details_cte.Entered_DtTm,details_cte.Filled_DtTm)/3600 as varchar) 
  end ,
  
  --Minute Portion
  case 
	when datediff(mi,details_cte.Entered_DtTm,details_cte.Filled_DtTm) - ((datediff(second,details_cte.Entered_DtTm,details_cte.Filled_DtTm)/3600) * 60) < 10
	  Then ':0' +  cast(datediff(mi,details_cte.Entered_DtTm,details_cte.Filled_DtTm) - ((datediff(second,details_cte.Entered_DtTm,details_cte.Filled_DtTm)/3600) * 60) as varchar)
	else ':' + cast (datediff(mi,details_cte.Entered_DtTm,details_cte.Filled_DtTm) - ((datediff(second,details_cte.Entered_DtTm,details_cte.Filled_DtTm)/3600) * 60) as varchar)
  end )
	
	as 'Time_To_Filled',

--Time To Verified(filled_dttm, verified_dttm)
--Hour portion
  concat(
  case 
     when cast(datediff(second,details_cte.Filled_DtTm,details_cte.Verified_DtTm)/3600 as int) < 9 
	   Then '0' + cast(datediff(second,details_cte.Filled_DtTm,details_cte.Verified_DtTm)/3600 as varchar) 
	 else cast(datediff(second,details_cte.Filled_DtTm,details_cte.Verified_DtTm)/3600 as varchar) 
  end ,
  
  --Minute Portion
  case 
	when datediff(mi,details_cte.Filled_DtTm,details_cte.Verified_DtTm) - ((datediff(second,details_cte.Filled_DtTm,details_cte.Verified_DtTm)/3600) * 60) < 10
	  Then ':0' +  cast(datediff(mi,details_cte.Filled_DtTm,details_cte.Verified_DtTm) - ((datediff(second,details_cte.Filled_DtTm,details_cte.Verified_DtTm)/3600) * 60) as varchar)
	else ':' + cast (datediff(mi,details_cte.Filled_DtTm,details_cte.Verified_DtTm) - ((datediff(second,details_cte.Filled_DtTm,details_cte.Verified_DtTm)/3600) * 60) as varchar)
  end )	
	as 'Time_To_Verified',

--Turnaround_Time
--Hour portion
  concat(
  case 
     when cast(datediff(second,details_cte.Entered_DtTm,details_cte.Verified_DtTm)/3600 as int) < 9 
	   Then '0' + cast(datediff(second,details_cte.Entered_DtTm,details_cte.Verified_DtTm)/3600 as varchar) 
	 else cast(datediff(second,details_cte.Entered_DtTm,details_cte.Verified_DtTm)/3600 as varchar) 
  end ,
  
  --Minute Portion
  case 
	when datediff(mi,details_cte.Entered_DtTm,details_cte.Verified_DtTm) - ((datediff(second,details_cte.Entered_DtTm,details_cte.Verified_DtTm)/3600) * 60) < 10
	  Then ':0' +  cast(datediff(mi,details_cte.Entered_DtTm,details_cte.Verified_DtTm) - ((datediff(second,details_cte.Entered_DtTm,details_cte.Verified_DtTm)/3600) * 60) as varchar)
	else ':' + cast (datediff(mi,details_cte.Entered_DtTm,details_cte.Verified_DtTm) - ((datediff(second,details_cte.Entered_DtTm,details_cte.Verified_DtTm)/3600) * 60) as varchar)
  end )
	
	as 'Turnaround_Time'

from details_cte 
where details_cte.Filled_DtTm is not null
  and details_cte.Verified_DtTm is not null
)

,avg_cte as (
   select 

details_cte.Pharmacy_Name as 'Pharmacy_Name',
max(details_cte.Pharmacy_Id) as 'Pharmacy_Id',
avg(datediff(mi,details_cte.Entered_DtTm,details_cte.Verified_DtTm)) as 'Average_Turn_Around_Time_Min',
avg(datediff(mi,details_cte.Entered_DtTm,details_cte.Filled_DtTm)) as 'Average_Time_To_Filled_Min',
avg(datediff(mi,details_cte.Filled_DtTm,details_cte.Verified_DtTm)) as 'Average_Time_To_Verified_Min'
	 
from details_cte 
where details_cte.Entered_DtTm is not null
  and details_cte.Filled_DtTm is not null
  and details_cte.Verified_DtTm is not null
 
group by details_cte.Pharmacy_Name)

select

details_cte.Pharmacy_Name as 'Pharmacy_Name',
details_cte.rx_number as 'Rx_Number',
details_cte.order_med_id as 'order_id',
details_cte.fill_number as 'rx_fill_number',
details_cte.action_id as 'Action_id',
flag_cte.flag_list as 'Flag_Name',
flag_cte.flag_ids as 'flag_ids',

details_cte.Entered_DtTm as 'Entered_DtTm',
details_cte.Entered_User as 'Entered_User',
details_cte.Filled_DtTm as 'Filled_DtTm',
details_cte.Filled_User as 'Filled_User',
details_cte.Verified_DtTm as 'Verified_DtTm',
details_cte.Verified_User as 'Verified_User',

turnarnd_cte.Time_To_Filled as 'Time_To_Filled',
turnarnd_cte.Time_To_Verified as 'Time_To_Verified',
turnarnd_cte.Turnaround_Time as 'Turnaround_Time',

avg_cte.Average_Time_To_Filled_Min 'Average_Time_To_Filled_Minutes',
avg_cte.Average_Time_To_Verified_Min 'Average_Time_To_Verified_Minutes',
avg_cte.Average_Turn_Around_Time_Min as 'Average_Turn_Around_Time_Minutes'

from details_cte details_cte
left outer join flag_cte flag_cte on details_cte.action_id = flag_cte.action_id 
left outer join avg_cte avg_cte on details_cte.pharmacy_id  = avg_cte.pharmacy_id
left outer join turnarnd_cte turnarnd_cte on details_cte.ORDER_MED_ID = turnarnd_cte.ORDER_MED_ID
 
 