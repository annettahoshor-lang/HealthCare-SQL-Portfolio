# HealthCare-SQL-Portfolio
Healthcare SQL Repository featuring healthcare reporting and ETL workflows

handling_3rdParty_duplicates_stored_procedure.sql
To deal with duplicates, I would first load the third-party file into a raw staging table.
Then I would use ROW_NUMBER() partitioned by the business key to identify duplicate rows. I would either delete duplicates from staging or, depending on your teams preference, use a staging CTE that selects only rn = 1. Then I would use that cleaned result set as the source for the MERGE into the target table.  That way the staging table would be an exact snapshot of what come from the vendor. 

handling_vendor_schema_changes.sql
In the case of the vendor changing their schema, without prior notification, I would fail the SSIS package before the bad data loads. 
The way I would do this is I would have an Execute SQL Task in SSIS to check the schema.  I would create a table that holds the vendors expected schema. Then I would compare the vendor's actual schema to the expected schema.  Then I would add a Precedence Constraint to the Execute SQL Task to only continue if the validation passes.  I would send an email task and a SQL Server Agent alert and add an event handler to log the error. See the SQL file titled "handling_vendor_schema_changes.sql" to view sample code that would go in the Execute SQL Task.  

diabetes_cms.sql
This is a diabetes CMS measure that quantifies if the metric was met and returns a percentage.   
The measure is "What percentage of diabetic patients had good blood sugar control during the measurement years?"
Denominator : Age 18–75, Diagnosis of diabetes, Seen in the clinic during the measurement year
Numerator: Patients whose most recent Hemoglobin A1C result is < 7.5

hypertension_cms.sql
This is a hypertension CMS measure that quantifies if the metric was met and returns a percentage.   
The measure is "What percentage of patients with a diagnosis of hypertension had good blood pressure control during the measurement years?"
Denominator : Age 18–85, Diagnosis of hypertension, Seen in the clinic during the measurement year
Numerator: Most recent blood pressure reading:
Systolic < 140
Diastolic < 90

rxamb_turnaround_time.sql
The purpose of this sql is calculate the turnaround time for Ambulatory pharmacies and identify any bottlenecks.  This sql pulls the average turnaround time for each step in the pharmacy process (entered time, filled time, verified time).  It can also be used to drill down to the specific user and prescription.

rxamb_3rdparty_payer.sql
The purpose of this SQL is to pull data for all medications that were either shipped or dispensed for the specified Ambulatory pharmacy during the specified time period.  An example of the data fields pulled are pharmacy_npi, dispensed_ndc, dispensed_drug, rx_number, dispense_quanity, #_of_refills, patient_charged_amount, patient_paid_amount, insurance_charged_amount, insurance_paid_amount, rx_gross_margin. 

concurrent_opioid_benzo_rx.sql
This report is for the KY SOS Metric: Patients, age 18 years or older, prescribed via electronic means, two or more schedule II opioids or a schedule II Opioid and benzodiazepine concurrently at discharge excluding patients who have an active diagnosis of cancer.    

outreach_future_labs.sql
The purpose of this sql is to pull contact information including telephone number and email for future labs.  This extract was ftp'd daily to a 3rd party vendor who then used the information to send text and email reminders to patients.  
