--This table would only need to be created one time. It's purpose is to document the expected schema.
 
CREATE TABLE dbo.ExpectedVendorSchema
(
    SourceName VARCHAR(100),
    TableSchema VARCHAR(100),
    TableName VARCHAR(100),
    ColumnName VARCHAR(100),
    ExpectedDataType VARCHAR(100),
    ExpectedMaxLength INT NULL,
    IsRequired BIT
);

INSERT INTO dbo.ExpectedVendorSchema
(
    SourceName,
    TableSchema,
    TableName,
    ColumnName,
    ExpectedDataType,
    ExpectedMaxLength,
    IsRequired
)
VALUES
('WIC Vendor', 'dbo', 'PatientWIC_Source', 'PatientID', 'int', NULL, 1),
('WIC Vendor', 'dbo', 'PatientWIC_Source', 'WICResult', 'varchar', 50, 1),
('WIC Vendor', 'dbo', 'PatientWIC_Source', 'WICResultDate', 'date', NULL, 1);

--SQL for the Execute SQL Task
DECLARE @MismatchCount INT;

SELECT @MismatchCount = COUNT(*)
FROM dbo.ExpectedVendorSchema expected
LEFT JOIN INFORMATION_SCHEMA.COLUMNS actual
    ON actual.TABLE_SCHEMA = expected.TableSchema
   AND actual.TABLE_NAME = expected.TableName
   AND actual.COLUMN_NAME = expected.ColumnName
WHERE expected.SourceName = 'WIC Vendor'
AND expected.IsRequired = 1
  AND
  (
        actual.COLUMN_NAME IS NULL
        OR actual.DATA_TYPE <> expected.ExpectedDataType
        OR
        (
expected.ExpectedMaxLength IS NOT NULL
            AND actual.CHARACTER_MAXIMUM_LENGTH <> expected.ExpectedMaxLength
        )
  );

IF @MismatchCount > 0
BEGIN
    THROW 50001, 'Vendor schema validation failed. A required column is missing or has the wrong data type/length.', 1;
END;