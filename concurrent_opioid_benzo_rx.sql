/*
********************************************************************************
TITLE: Concurrent e-Prescribing Opioid Benzodiazepine - KY SOS Metric 2b 
AUTHOR: Anne Hoshor
*******************************************************************************/
DROP TABLE IF EXISTS #enc

SELECT 

max(enc.PAT_ID) PAT_ID,
max(datediff(year,ept.BIRTH_DATE,enc.CONTACT_DATE)) Age_At_Encounter,
max(csn.CSN) CSN,
max(enc.HSP_ACCOUNT_ID) HSP_ACCOUNT_ID,
max(henc.ADT_PAT_CLASS_C) ADT_PAT_CLASS_C,
max(cast(henc.HOSP_DISCH_TIME as date)) Discharge_Date,
string_agg(icd.code,'; ') Diagnosis,
enc.PAT_ENC_CSN_ID,
max(dep.DEPARTMENT_ID) DEPARTMENT_ID

into #enc

FROM   
PAT_ENC enc
INNER JOIN PAT_ENC_HSP henc on henc.PAT_ENC_CSN_ID = enc.PAT_ENC_CSN_ID 
     and cast(henc.HOSP_DISCH_TIME as date) >= {{REPORT_START_DT}} 
     and cast(henc.HOSP_DISCH_TIME as date) < ({{REPORT_END_DT}} +1)
INNER JOIN CLARITY_DEP dep on dep.DEPARTMENT_ID = henc.DEPARTMENT_ID 
  and (dep.REV_LOC_ID IN ({{C_REVENUE_LOCATION}}) OR NULLIF(COALESCE({{C_REVENUE_LOCATION}},N''),N'') IS NULL)
INNER JOIN PATIENT ept on enc.PAT_ID = ept.PAT_ID
INNER JOIN EPT_CSN csn on csn.UCI = enc.PAT_ENC_CSN_ID
inner join coverage cvg on cvg.COVERAGE_ID = enc.COVERAGE_ID
inner join clarity_epm epm on epm.PAYOR_ID = cvg.PAYOR_ID
  and epm.FINANCIAL_CLASS not like 'Hospice'
INNER JOIN CLARITY_SA sa On sa.SERV_AREA_ID = dep.SERV_AREA_ID 
      and {{IN_PROPERTY_REQ [[sa.SERV_AREA_ID]] [[C_DYNAMIC_SERVICE_AREA]]}}
left outer join PAT_ENC_DX DX on enc.PAT_ENC_CSN_ID = DX.PAT_ENC_CSN_ID
left outer JOIN CLARITY_EDG EDG ON EDG.DX_ID = DX.dx_id 
left outer JOIN EDG_CURRENT_ICD10 ICD ON ICD.DX_ID=EDG.DX_ID AND ICD.LINE=1

where datediff(year,ept.BIRTH_DATE,enc.CONTACT_DATE) >=18
      and datediff(day,henc.HOSP_DISCH_TIME,henc.HOSP_ADMSN_TIME) <= 120
and not exists (select DX.PAT_ENC_CSN_ID from PAT_ENC_DX DX 
    inner JOIN CLARITY_EDG EDG ON EDG.DX_ID = DX.dx_id 
    inner JOIN EDG_CURRENT_ICD10 ICD ON ICD.DX_ID=EDG.DX_ID AND ICD.LINE=1
     and (icd.code like 'C%' or icd.code like 'D00%'
	      or icd.code  like 'D01%' or icd.code  like 'D02%' or icd.code  like 'D03%'
		  or icd.code  like 'D04%' or icd.code  like 'D05%' or icd.code  like 'D06%'
	      or icd.code  like 'D07%' or icd.code  like 'D09%' or icd.code  like 'D10%'
		  or icd.code  like 'D11%' or icd.code  like 'D12%' or icd.code  like 'D13%'
		  or icd.code  like 'D14%' or icd.code  like 'D15%' or icd.code  like 'D16%'
		  or icd.code  like 'D17%' or icd.code  like 'D18%' or icd.code  like 'D19%'
		  or icd.code  like 'D20%' or icd.code  like 'D21%' or icd.code  like 'D22%'
		  or icd.code  like 'D23%' or icd.code  like 'D24%' or icd.code  like 'D25%'
		  or icd.code  like 'D26%' or icd.code  like 'D27%' or icd.code  like 'D28%'
		  or icd.code  like 'D29%' or icd.code  like 'D30%' or icd.code  like 'D31%'
		  or icd.code  like 'D32%' or icd.code  like 'D33%' or icd.code  like 'D34%'
		  or icd.code  like 'D35%' or icd.code  like 'D36%' or icd.code  like 'D37%'
		  or icd.code  like 'D38%' or icd.code  like 'D39%' or icd.code  like 'D40%'
		  or icd.code  like 'D41%' or icd.code  like 'D42%' or icd.code  like 'D43%'
		  or icd.code  like 'D44%' or icd.code  like 'D45%' or icd.code  like 'D46%' 
		  or icd.code  like 'D47%' or icd.code  like 'D48%' or icd.code  like'D49%'
		  or icd.code  like'D57%')
		  
     where enc.PAT_ENC_CSN_ID = DX.PAT_ENC_CSN_ID) 
GROUP BY enc.PAT_ENC_CSN_ID;

select
max(enc.DEPARTMENT_ID) as 'DEPARTMENT_ID',
max(enc.PAT_ID) as 'PAT_ID',
max(enc.Age_At_Encounter) as 'Age_At_Encounter',
enc.CSN as 'CSN',
max(enc.HSP_ACCOUNT_ID) as 'HSP_ACCOUNT_ID',
max(enc.ADT_PAT_CLASS_C) as 'ADT_PAT_CLASS_C',
max(enc.Discharge_Date) as 'Discharge_Date',
max(enc.Diagnosis) as 'Diagnosis',
string_agg(med.THERA_CLASS_C, '; ') as 'Thera_Class_C',
string_agg(med.NAME, '; ') as 'Medication_Name',
string_agg(med.ORDERING_DATE, '; ') as 'Med_Order_Date',
string_agg(med.ID,'; ') as 'MedId',
count(med.id) as 'counts',
case when count(med.id) > 1
      then 0
      else 1
end as 'NoConcurrentPrescriptionFlag',
max('Y') as 'FIRST_ORDER'

from #enc enc

left join(
   select 
    enc.PAT_ENC_CSN_ID,
	om.ORDER_MED_ID ID,
	med.THERA_CLASS_C,
	med.NAME,
	om5.ORDERED_DAYS_SUPPLY_PER_FILL,
	om.ORDERING_DATE as 'ORDERING_DATE'
	
	FROM #enc enc
	INNER JOIN ORDER_MED om ON enc.PAT_ENC_CSN_ID = om.PAT_ENC_CSN_ID
	  and (om.DISCON_TIME is NULL or om.DISCON_TIME <= 0)
	INNER JOIN ORDER_MED_3 om3 ON om.ORDER_MED_ID=om3.ORDER_ID AND om3.EPRES_DEST_C IS NOT NULL
	INNER JOIN CLARITY_MEDICATION med on med.MEDICATION_ID = om.MEDICATION_ID 
	  and (med.DEA_CLASS_CODE_C = 2 or med.PHARM_SUBCLASS_C = 950319)
	INNER JOIN ORDER_MED_5 om5 ON om.ORDER_MED_ID=om5.ORDER_ID
	) med on med.PAT_ENC_CSN_ID = enc.PAT_ENC_CSN_ID

group by enc.CSN

DROP TABLE #enc

