/*****************************************************************************************************************************
Extract Name: RX AMB Third Party Detail Extract v3
Date        : 09/09/2024
BID         : Anne Hoshor
Description : Pull various finincial information for dispensed prescriptions
*****************************************************************************************************************************/

select 
  max(pat.name) as "Patient_Name"
 ,max(pharm.name) as "pharmacy_name"
 ,max(pharm.npi)  as "pharmacy_npi"
 ,max(mdf.primaryComponentNDC)  as "Dispensed_ndc" 
 ,max(medDim.name)  as "Dispensed_Drug" 
 ,max(to_char(mdf.dispenseSentInstant, 'yyyyMMdd')) as "Dispensed_Date"
 ,max(mdf.rxNumber) as "RX_Number"
 ,max(mdf.primarycomponentquantity)  as "Dispensed Quantity" 
 ,max(mdf.dayssupply)  as "Dispensed Days Supply"
 ,max(mdf.fillNumber) as "Refill_Nbr"
 
  ,max(epp1.bin_num)  as "Primary Payer BIN" 
  ,max(epp1.processor_cntrl_num)  as "Primary Payer PCN" 
  ,max(cov.subscribergroupnumber)  as "Primary Payor Group Number" 
  ,max(cov.payorname)  as "Primary Payor Name" 
  ,max(epp.benefit_plan_name)  as "Primary Participating Plan" 
  ,max(cov.payorfinancialclass)  as "Primary Sponsoring Payor Type" 
  ,max(epp2.bin_num)  as "Secondary Payer BIN" 
  ,max(epp2.processor_cntrl_num)  as "Secondary Payer PCN" 
  ,max(cov2.payorname)  as "Secondary Payor Name" 
  ,max(epp_ben2.benefit_plan_name)  as "Secondary Participating Plan"
  
  ,max(mdf.patientchargedamount)  as "Patient_Charged_Amount" 
  ,max(mdf.PatientPaidAmount) as "Patient_Paid_Amount"
  ,max(mdf.FirstPayorChargedAmount) as "First_Payor_Charged_Amount"
  ,max(mdf.FirstPayorPaidAmount) as "First_Payor_Paid_Amount"
  ,max(mdf.SecondPayorChargedAmount) as "Second_Payor_Charged_Amount"
  ,max(mdf.SecondPayorPaidAmount) as "Second_Payor_Paid_Amount"
  ,max(mdf.ThirdPayorChargedAmount) as "Third_Payor_Charged_Amount"
  ,max(mdf.ThirdPayorPaidAmount) as "Third_Payor_Paid_Amount"
  ,max(mdf.medicationAcquisitionCost) as "Acquisition_Cost"
  ,max(mdf.PatientPaidAmount + mdf.FirstPayorPaidAmount + mdf.SecondPayorPaidAmount
       + mdf.ThirdPayorPaidAmount) as "Total_Paid_Amount"
  ,max((mdf.PatientPaidAmount + mdf.FirstPayorPaidAmount + mdf.SecondPayorPaidAmount
       + mdf.ThirdPayorPaidAmount) - mdf.medicationAcquisitionCost) as "RX_Gross_Margin"     


from CABOODLE.MEDICATIONDISPENSEFACT mdf
INNER JOIN caboodle.patientdim pat on pat.durableKey = mdf.patientdurablekey
inner join caboodle.medicationDim medDim on medDim.medicationKey = mdf.medicationKey
inner join CABOODLE.PHARMACYDIM pharm on pharm.pharmacyKey = mdf.fillPharmacyKey

left outer join caboodle.coveragedim cov 
    on cov.coveragekey = mdf.firstcoveragekey
left outer join clarity.clarity_epp epp 
    on epp.benefit_plan_id = cov.benefitplanepicid
left outer join clarity.coverage_2 co_amt 
    on co_amt.cvg_id = cov.coverageepicid
left outer join clarity.zc_financial_class fin_class 
    on fin_class.financial_class = epp.clm_fin_cl_c
left outer join clarity.clarity_epp_2 epp1 
    on epp1.benefit_plan_id = cov.benefitplanepicid  

left outer join caboodle.coveragedim cov2 
    on cov2.coveragekey = mdf.secondcoveragekey
left outer join clarity.clarity_epp_2 epp2 
    on epp2.benefit_plan_id = cov2.benefitplanepicid
left outer join clarity.coverage_2 co_amt2 
    on co_amt2.cvg_id = cov2.coverageepicid
left outer join clarity.clarity_epp epp_ben2 
    on epp_ben2.benefit_plan_id = cov2.benefitplanepicid

where mdf.dispenseSentInstant >= dateadd('day', -7, current_date())
  and mdf.dispenseSentInstant < current_date() 
	and mdf.mode = 'Outpatient' 
	and mdf._IsDeleted = 0
  and pharm.npi in ('12345')
  and mdf.mode = 'Outpatient'
  and mdf.fillstatus in ('Shipped','Dispensed')
  
group by mdf.rxnumber,mdf.fillNumber

  