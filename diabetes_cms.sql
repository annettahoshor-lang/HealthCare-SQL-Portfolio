/*What percentage of diabetic patients had good blood sugar control during the measurement years*/

/*Denominator
Patients:
Age 18–75
Diagnosis of diabetes
Seen in the clinic during the measurement years
Numerator
Patients whose most recent Hemoglobin A1C result is < 7.5   */

--First select all the patient who qualify for the denominator 

with den_cte as (select distinct(p.pat_id) as pat_id, format(p.BIRTH_DATE, 'MM/dd/yyyy') as dob,
  datediff(year,p.BIRTH_DATE,getdate()) -  
    case when dateadd(year,datediff(year, p.birth_date,getdate()), p.birth_date) > getdate()
      then 1
      else 0
    end as age, ce.CURRENT_ICD10_LIST

from pat_enc pe
inner join patient p on p.pat_id = pe.pat_id
inner join problem_list pl on pl.PAT_ID = p.pat_id
inner join clarity_edg ce on ce.DX_ID = pl.DX_ID
and (ce.CURRENT_ICD10_LIST like 'E10.%' or ce.CURRENT_ICD10_LIST like 'E11.%')

where pe.contact_date >= '2023-01-01' and pe.contact_date <= '2025-12-31'
  and pe.ENC_TYPE_C = 101
  and pe.APPT_CANCEL_DATE is null
  and pl.PROBLEM_STATUS_C = 1
  --calculate age
  and (datediff(year, p.birth_date,getdate()) - 
  case when dateadd(year,datediff(year, p.birth_date,getdate()),p.BIRTH_DATE) > getdate() 
    then 1
    else 0
  end) between 18 and 75)

  --get the denominator count
,den_cte_cnt as (select count(distinct(pat_id)) as den_count
from den_cte)


--Next calculate the numerator.  Patients whose most recent Hemoglobin A1C result is < 7.5
,num_cte as (
   select pat_id,result_date,result_value,most_recent from (
   select pe.pat_id as pat_id, ord.result_date as result_date,ord.ORD_NUM_VALUE as result_value,
   row_number() over(partition by pe.pat_id order by ord.result_date desc) as most_recent 
   
   from den_cte
   inner join pat_enc pe on den_cte.pat_id = pe.pat_id
   inner join order_proc op on op.PAT_ENC_CSN_ID = pe.PAT_ENC_CSN_ID
   inner join ORDER_RESULTS ord on ord.ORDER_PROC_ID = op.ORDER_PROC_ID
   
   where pl.PROBLEM_STATUS_C = 1 --active
         and op.LAB_STATUS_C = 3 --final
         and op.proc_id = 828 -- A1C lab test
         and ord.ORD_NUM_VALUE < 7.5
                  
) rn
where most_recent = 1) 

--get the numenator count
,num_cte_cnt as (select count(distinct(pat_id)) as num_count
from num_cte)


select concat(round(((cast(nc.num_count as float) / cast(dc.den_count as float)) * 100),2), '%') as measure_percentage
from num_cte_cnt nc cross join den_cte_cnt dc 
