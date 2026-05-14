# HealthCare-SQL-Portfolio
Healthcare SQL Repository featuring healthcare reporting and ETL workflows

handling_3rdParty_duplicates_stored_procedure.SQL
To deal with duplicates, I would first load the third-party file into a raw staging table. 
Then I would use ROW_NUMBER() partitioned by the business key to identify duplicate rows. I would either delete duplicates from staging or, depending on your teams preference, use a staging CTE that selects only rn = 1. Then I would use that cleaned result set as the source for the MERGE into the target table.  That way the staging table would be an exact snapshot of what come from the vendor. 

handling_vendor_schema_changes.SQL
In the case of the vendor changing their schema, without prior notification, I would fail the SSIS package before the bad data loads. 
The way I would do this is I would have an Execute SQL Task in SSIS to check the schema.  I would create a table that holds the vendors expected schema. Then I would compare the vendor's actual schema to the expected schema.  Then I would add a Precendence Constraint to the Execute SQL Task to only continue if the validation passes.  I would send an email task and a SQL Server Agent alert and add an event handler to log the error. See the SQL file titled "Check for Schema Changes.SQL" to view sample code that could go in the Execute SQL Task.  
