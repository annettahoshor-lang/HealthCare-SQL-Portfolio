--Stored ETL Procedure that accepts a load date,performs an incremental load into first a staging table, 
--then a target table, uses error catching logic, removing duplicates
--loads a staging table,removes duplicates,(using merge/upsert logic),logs row counts

/*In this examkple, WIC participation results are coming from a 3rd party.  This procedure pulls in WIC participation results that were documented the previous day*/  
  
CREATE PROCEDURE dbo.LoadPatientWICResults (@LoadDate DATE)
AS
BEGIN    
  SET NOCOUNT ON;
  /*These variables will be used later for logging*/
  DECLARE @RowsStaged INT = 0;    
  DECLARE @RowsDeleted INT = 0;    
  DECLARE @RowsMerged INT = 0;
  
  BEGIN TRY        
  BEGIN TRANSACTION; /*Beging Incremental load into staging table.  
                        Incremental load means we do not load everything.  
                        Only the new data.*/
 
--ensure staging table is empty
TRUNCATE TABLE dbo.PatientWIC_Stage;            
    
 INSERT INTO dbo.PatientWIC_Stage        
 (PatientID,WICResult,LoadDate)        
 SELECT PatientID,WICResult,getdate()       
 FROM dbo.PatientWIC_Source        
 WHERE WICResultDate >= @LoadDate 
      and WICResultDate <= dateadd(day,1,@LoadDate)       
 SET @RowsStaged = @@ROWCOUNT;        
         
/*Check the staging table for duplicates. There should only be one WIC result per person. Remove any duplicates if there are any*/        
       
;WITH Duplicates AS
(SELECT PatientId,WICResult,ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY LoadDate DESC,StageID DESC) AS rn 
FROM dbo.PatientWIC_Stage )
       

DELETE FROM Duplicates        
WHERE rn > 1;        
SET @RowsDeleted = @@ROWCOUNT;             

/*Insert the new results into the target table using merge/upsert.  If the patient already has WICresults,overwrite them.*/
/*Merge / Upsert into target table*/        
       
MERGE dbo.PatientWIC_Target AS target        
USING dbo.PatientWIC_Stage AS source            
      ON target.patientId = source.patientId           
     AND source.LoadDate = getdate()       

WHEN MATCHED THEN            
UPDATE SET                
target.PatientID = source.PatientID,                
target.WICResult = source.WICResult,                               
target.LastUpdatedDateTime = GETDATE()

WHEN NOT MATCHED BY TARGET THEN            
INSERT(PatientId,WICResult,CreatedDateTime,LastUpdatedDateTime)            
VALUES(source.PatientId,source.WICResult,GETDATE(),GETDATE());

SET @RowsMerged = @@ROWCOUNT;              

/*Log success*/            
INSERT INTO dbo.ETL_Log(ProcedureName,LoadDate,RowsStaged,DuplicateRowsDeleted,RowsMerged,Status,RunDateTime)       
VALUES('dbo.LoadPatientWICResults',@LoadDate,@RowsStaged,@RowsDeleted,@RowsMerged,'Success',GETDATE());        

COMMIT TRANSACTION;    
END TRY

BEGIN CATCH /*Rollback if anything failed*/

    IF @@TRANCOUNT > 0            
      ROLLBACK TRANSACTION;
      
      /*Log failure*/        
INSERT INTO dbo.ETL_Log(ProcedureName,LoadDate,RowsStaged,DuplicateRowsDeleted,RowsMerged,Status,RunDateTime)       
VALUES('dbo.LoadPatientWICResults',GetDate(),@RowsStaged,@RowsDeleted,@RowsMerged,'Failed',GETDATE());        

    THROW;
END CATCH;
   
END;
