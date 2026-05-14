/*****************************************************************************************************************************
Extract name: Future Lab Blood Draw Orders Extract
BID: Anne Hoshor
Extract Description: Pull all future lab blood draw orders from the previous day.*/

select
max(pos.pos_name) as "region",
max(pos.pos_id) as "region_id",
max(pat.PAT_ID) as "pat_id",
om.internal_id as "order_id",
max(to_varchar(op.order_inst,'MM/dd/yyyy HH:mi')) as "order_instant",
max(to_varchar(op.fut_expect_comp_dt,'MM/dd/yyyy HH:mi')) as "expected_completion_date",
max(to_varchar(op.standing_exp_date,'MM/dd/yyyy HH:mi')) as "standing_expiration_date",
max(op.display_name) as "order_name",
max(ser.prov_name) as "auth_provider",
max(zop.name) as "order_priority",
max(zoc.name) as "order_class",
max(dep.department_name) as "department_ordering",
max(pat.PAT_MRN_ID) as "patient_id",
max(ec.csn) as "csn",
max(zst.name) as "order_specimen_type",
max(loc.loc_name) as "referring_facility",
max(to_varchar(pat.birth_date,'MM/dd/yyyy')) as "patient_dob",
max(pat.pat_name) as "patient_name",
max(coalesce(comm.other_communic_num,pat.home_phone)) as "phone_number",
max(pat.email_address) as "email",
max(ident.identity_id) as "adventhealth mrn",
max(lab.LLB_NAME) as "lab_name",
max(epm.PAYOR_NAME) as "encounter_insurance"
,max(cam.code_value) as Split_Loc
,max(cam.code_assc_value)  as Split_Reg


from clarity.order_proc op
inner join clarity.pat_enc pe on pe.PAT_ENC_CSN_ID = op.PAT_ENC_CSN_ID
inner join clarity.coverage cvg on cvg.coverage_id = pe.coverage_id
inner join clarity.CLARITY_EPM epm on cvg.payor_id = epm.payor_id
inner join clarity.PATIENT pat on pe.PAT_ID = pat.PAT_ID
INNER JOIN clarity.ept_csn EC ON PE.pat_enc_csn_id = EC.uci
left outer join clarity.order_status os on os.order_id = op.order_proc_id
inner join CLARITY.CLARITY_LLB LAB ON os.resulting_lab_id = LAB.RESULTING_LAB_ID
inner join clarity.ord_map om on om.cid = op.order_proc_id
left outer join clarity.clarity_ser ser on ser.prov_id = op.authrzing_prov_id
inner join clarity.order_proc_2 op2 on op2.order_proc_id = op.order_proc_id
inner join clarity.clarity_dep dep on dep.department_id = op2.login_dep_id
inner join clarity.clarity_dep_4 dep4 on dep4.department_id = dep.department_id
inner join clarity.clarity_pos pos on pos.pos_id = dep4.region_id
inner join clarity.clarity_loc loc on op2.refg_facility_id = loc.loc_id

inner join work.edw.code_assc_map cam on cam.code_name='pos.pos_id'
                and cam.code_value = pos.pos_id
                and cam.active_flag = 'Y'
                and cam.usage = 'salesforce_lab_orders'
                and cam.code_assc_name = 'region_abbr'
                
left outer join clarity.other_communctn comm on comm.pat_id = pat.pat_id
  and comm.other_communic_c in (1,6) /*Mobile,TTY/TDP*/
left outer join clarity.identity_id ident on ident.pat_id = pat.pat_id
  and ident.identity_type_id = 9502
inner join clarity.zc_order_class zoc on zoc.order_class_c = op.order_class_c
  and op.order_class_c not in (95016)
left outer join clarity.zc_order_priority zop on zop.order_priority_c  = op.order_priority_c
inner join clarity.zc_specimen_type zst on zst.specimen_type_c = op.specimen_type_c


WHERE op.order_inst >=date_trunc('day',(dateadd(day, -1, CURRENT_timestamp())))
AND op.order_inst < date_trunc('day', (CURRENT_timestamp()))
and dep.serv_area_id = 9503
and os.resulting_lab_id in (513435) /*AH Florida test Compendium*/
and op.future_or_stand = 'F'
and op.specimen_type_c = 9503 /*blood*/
and op2.act_order_c = 2 /*active procedure*/

and (

(pos.pos_id in (12345,12345)/*CFDS*/
and epm.PAYOR_NAME not in ('BLUE CROSS FL','BLUE CROSS FL MEDICARE','BLUE CROSS GA','CAREPLUS',
                           'FLORIDA HEALTHCARE PLANS','FREEDOM HEALTH','HEALTHSMART',
                           'HUMANA','HUMANA MEDICARE','SIMPLY HEALTHCARE FL MEDICAID',
                           'SUREST','VETERANS ADMINISTRATION','WELLCARE MEDICARE',
                           'SIMPLY HEALTHCARE MEDICARE','BLUE CROSS CO','CHAMPVA','WELLCARE NC MEDICAID'))
                           
 or
 
 
 (pos.pos_id in (12345,12345) /*WFD*/
and epm.PAYOR_NAME not in ('AARP','ALLIED BENEFIT SYSTEMS','CAREPLUS','FLORIDA HEALTHCARE PLANS',
'FLORIDA HEALTHCARE PLANS MEDICARE','FREEDOM HEALTH','GROUP AND PENSION ADMINISTRATORS',
'HEALTHSMART','HUMANA','HUMANA MEDICARE','LUCENT HEALTH','MEDICAID FL','MEDICAID FL SHARE OF COST',
'MERITAIN HEALTH','MOLINA HEALTHCARE FL MEDICAID','OPTIMUM HEALTHCARE','PREFERRED CARE PARTNERS',
'PRIORITY HEALTH MEDICARE','SIMPLY HEALTHCARE FL MEDICAID','SIMPLY HEALTHCARE MEDICARE',
'SUNSHINE HEALTH','SUNSHINE HEALTH FL MEDICAID','SUREST','TUFTS HEALTH PLAN','UMR',
'UNITED HEALTHCARE FL MEDICAID','UNITED HEALTHCARE GOLDEN RULE','VETERANS ADMINISTRATION',
'WELLCARE MEDICARE','WELLMED/UNITED HEALTHCARE MEDICARE'))                         
                           
  )
and op.standing_exp_date >= date_trunc('day', (CURRENT_timestamp())) 
and not exists (select ole.order_id from clarity.order_last_edit ole 
                where ole.order_id = op.order_proc_id
                and ole.ord_lst_ed_action_c in (4,6))
                
and op.proc_id not in ('51343890','51343891','51343892','51344011',
                       '51344012','51344013','51344014','51344015',
                       '51344016','51344017','51344018','51344019',
                       '51344020','51344021','51344022','51344023',
                       '51344024','51344025','51344026','51344027',
                       '51344028','51344029','51344030','51344031',
                       '51344335','51344756','51343888','51343889',
                       '51345775','51364522','51366063','51376952',
                       '950662','950780','950781','950784','950787',
                       '51343957','51343958','51343959','51343960',
                       '51343962','51343965','51343967','51343974',
                       '51343975','51343976','51343977','51343978',
                       '51343983','51343986','51343987','51344002',
                       '51358891','51358892','51358893','51358894',
                       '51358896','51360619','51360636','51360853',
                       '51377783','95017142','95022250')

group by om.internal_id
