/*What percentage of hypertensive patients had controlled blood pressure?
Denominator
Patients:
Age 18–85
Diagnosis of hypertension
Seen during the measurement period
Numerator
Most recent blood pressure reading:
Systolic < 140
Diastolic < 90
Need separate systolic and diastolic values*/

--First select all the patient who qualify for the denominator 
with den_cte as (
select distinct(p.pat_id) as pat_id, format(p.BIRTH_DATE, 'MM/dd/yyyy') as dob,
  datediff(year,p.BIRTH_DATE,getdate()) -  
    case when dateadd(year,datediff(year, p.birth_date,getdate()), p.birth_date) > getdate()
      then 1
      else 0
    end as age, ce.CURRENT_ICD10_LIST
from pat_enc pe
inner join patient p on p.pat_id = pe.pat_id
inner join problem_list pl on pl.PAT_ID = p.pat_id
inner join clarity_edg ce on ce.DX_ID = pl.DX_ID

where pe.contact_date >= '2023-01-01' and pe.contact_date <= '2025-12-31'
  and pe.ENC_TYPE_C = 101
  and pe.APPT_CANCEL_DATE is null
  and pl.PROBLEM_STATUS_C = 1
  and ce.CURRENT_ICD10_LIST like '%I10%'
  and (datediff(year,p.birth_date,getdate()) -

    case when dateadd(year,datediff(year,p.birth_date,getdate()),p.BIRTH_DATE) > getdate()
    then 1
    else 0
    end between 18 and 85) 
)

--get the denominator count
,den_cte_cnt as (select count(distinct(pat_id)) as den_count
from den_cte)

,num_cte as (
select pat_id,result_date,Systolic,Diastolic,rcnt_rec from (
select pe.pat_id as pat_id,pe.pat_enc_csn_id,ifm.recorded_time as result_date
,cast(substring(ifm.MEAS_VALUE,1,CHARINDEX('/',ifm.MEAS_VALUE) -1) as int) as Systolic
,cast(substring(ifm.MEAS_VALUE,CHARINDEX('/',ifm.MEAS_VALUE) +1,len(ifm.meas_value)) as int) as Diastolic
,dense_rank() over (partition by pe.pat_id order by ifm.recorded_time desc) as rcnt_rec

from den_cte 
inner join pat_enc pe on den_cte.pat_id = pe.pat_id
inner join IP_FLWSHT_REC ipr on ipr.INPATIENT_DATA_ID = pe.INPATIENT_DATA_ID
inner join ip_flwsht_meas ifm on ifm.FSD_ID = ipr.FSD_ID

where ifm.FLO_MEAS_ID = '5' --Blood Pressure
) rn where rcnt_rec = 1 and diastolic < 90 and systolic < 140)

--get the numenator count
,num_cte_cnt as (select count(distinct(pat_id)) as num_count
from num_cte)

select concat(round(cast(ncc.num_count as float) / cast(dcc.den_count as float) * 100,2),'%') as HyperTension_Measure
from den_cte_cnt dcc
 cross join num_cte_cnt ncc