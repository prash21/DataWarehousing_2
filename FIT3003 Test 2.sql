-- PRASHANT MURALI   STUDENT ID: 29625564    TEST 2 --

-- Viewing the given operational database
select * from MRECOMANY.utilities;
select * from MRECOMANY.utilities_used;
select * from MRECOMANY.client;
select * from MRECOMANY.contract;
select * from MREComany.invoice;


-- COMMANDS FOR CREATING THE DATA WAREHOUSE

-- Utilities dimension
DROP TABLE utilities_dim CASCADE CONSTRAINTS PURGE;
Create table utilities_dim as
SELECT distinct UTILITIESID, DESCRIPTION as Utilities_description
FROM MRECOMANY.utilities_used;


-- Company size dimension
DROP TABLE company_size_dim CASCADE CONSTRAINTS PURGE;
Create table company_size_dim(
Sizeid VARCHAR(10),
Size_description VARCHAR(20));

-- Populate company_size_dim
INSERT INTO company_size_dim
VALUES ('S', 'Small');

INSERT INTO company_size_dim
VALUES ('M', 'Medium');

INSERT INTO company_size_dim
VALUES ('L', 'Large');


-- Time dimension
-- Note that we get the distinct dates from ALL the Invoice Dates, Contract Signed Dates,
-- and Utility Consumption Date. 
DROP TABLE time_dim CASCADE CONSTRAINTS PURGE;
Create table time_dim as
SELECT distinct to_char(INVOICEDATE, 'qYYYY') as TimeID,
                to_char(INVOICEDATE, 'YYYY') as Year,
                to_char(INVOICEDATE, 'q') as Quarter
FROM MREComany.invoice
UNION
SELECT distinct to_char(CONTRACTSIGNEDDATE, 'qYYYY') as TimeID,
                to_char(CONTRACTSIGNEDDATE, 'YYYY') as Year,
                to_char(CONTRACTSIGNEDDATE, 'q') as Quarter
FROM MRECOMANY.contract
UNION
SELECT distinct to_char(CONSUMPTIONSTARTDATE, 'qYYYY') as TimeID,
                to_char(CONSUMPTIONSTARTDATE, 'YYYY') as Year,
                to_char(CONSUMPTIONSTARTDATE, 'q') as Quarter
FROM MRECOMANY.utilities_used;


-- Duration dimension
DROP TABLE duration_dim CASCADE CONSTRAINTS PURGE;
Create table duration_dim(
DurationID VARCHAR(10),
Duration_description VARCHAR(20));

-- Populate duration_dim
INSERT INTO duration_dim
VALUES ('ST', 'Short-term lease');

INSERT INTO duration_dim
VALUES ('MT', 'Medium-term lease');

INSERT INTO duration_dim
VALUES ('LT', 'Long-term lease');



-- Create the temp UtilityFact table
DROP TABLE temp_UtilityFact CASCADE CONSTRAINTS PURGE;
create table temp_UtilityFact as
SELECT ut.UtilitiesID, u.ConsumptionStartDate, u.TotalPrice
FROM MRECOMANY.utilities ut, MRECOMANY.utilities_used u
WHERE u.UtilitiesID = ut.UtilitiesID;

-- Add column to store TimeID
ALTER TABLE temp_UtilityFact
ADD (TimeID VARCHAR2(10));

-- Update it with ID for year
UPDATE temp_UtilityFact
SET TimeID = to_char(ConsumptionStartDate, 'qYYYY');

-- Create the final UtilityFact table
DROP TABLE UtilityFact CASCADE CONSTRAINTS PURGE;
CREATE TABLE UtilityFact AS
SELECT T.TimeID, T.UtilitiesID, sum(T.TotalPrice) AS Total_service_charge
FROM temp_UtilityFact T
GROUP BY T.TimeID, T.UtilitiesID;



-- Create the second ContactFact table, by creating the temp first
DROP TABLE temp_ContractFact CASCADE CONSTRAINTS PURGE;
create table temp_ContractFact as
SELECT c.ContractSignedDate, c.LeasingStartDate, c.LeasingEndDate, cl.NumberOfEmployees
FROM MRECOMANY.contract c, MRECOMANY.client cl
WHERE c.ClientID = cl.ClientID;

-- Add column to store Timeid
ALTER TABLE temp_ContractFact
ADD (Timeid VARCHAR2(10));

-- Update it with values
UPDATE temp_ContractFact
SET Timeid = to_char(ContractSignedDate, 'qYYYY');

-- Add column to store Sizeid
ALTER TABLE temp_ContractFact
ADD (Sizeid VARCHAR2(10));

-- Update it with values
UPDATE temp_ContractFact
SET Sizeid = 'S'
WHERE NumberOfEmployees < 20;

UPDATE temp_ContractFact
SET Sizeid = 'M'
WHERE NumberOfEmployees >= 20
AND NumberOfEmployees <= 100;

UPDATE temp_ContractFact
SET Sizeid = 'L'
WHERE NumberOfEmployees > 100;

-- Add column to store Durationid
ALTER TABLE temp_ContractFact
ADD (Durationid VARCHAR2(10));

UPDATE temp_ContractFact
SET Durationid = 'ST'
WHERE to_char(LeasingEndDate, 'YYMMDD') - to_char(LeasingStartDate, 'YYMMDD') < '10000';

UPDATE temp_ContractFact
SET Durationid = 'MT'
WHERE to_char(LeasingEndDate, 'YYMMDD') - to_char(LeasingStartDate, 'YYMMDD') >= '10000'
AND to_char(LeasingEndDate, 'YYMMDD') - to_char(LeasingStartDate, 'YYMMDD') <= '50000';

UPDATE temp_ContractFact
SET Durationid = 'LT'
WHERE to_char(LeasingEndDate, 'YYMMDD') - to_char(LeasingStartDate, 'YYMMDD') > '50000';

-- Create the final ContractFact table
DROP TABLE ContractFact CASCADE CONSTRAINTS PURGE;
CREATE TABLE ContractFact AS
SELECT T.TimeID, T.SizeID, T.DurationID, COUNT(T.ContractSignedDate) AS Num_Of_Contracts
FROM temp_ContractFact T
GROUP BY T.TimeID, T.SizeID, T.DurationID;




-- Create the temp fact for RevenueFact
DROP TABLE temp_RevenueFact CASCADE CONSTRAINTS PURGE;
create table temp_RevenueFact as
SELECT i.InvoiceDate, i.TotalPrice, cl.NumberOfEmployees
FROM MRECOMANY.invoice i, MRECOMANY.client cl
WHERE i.ClientID = cl.ClientID;

-- Add column to store Timeid
ALTER TABLE temp_RevenueFact
ADD (Timeid VARCHAR2(10));

-- Update it with values
UPDATE temp_RevenueFact
SET Timeid = to_char(InvoiceDate, 'qYYYY');

-- Add column to store Sizeid
ALTER TABLE temp_RevenueFact
ADD (Sizeid VARCHAR2(10));

-- Update it with values
UPDATE temp_RevenueFact
SET Sizeid = 'S'
WHERE NumberOfEmployees < 20;

UPDATE temp_RevenueFact
SET Sizeid = 'M'
WHERE NumberOfEmployees >= 20
AND NumberOfEmployees <= 100;

UPDATE temp_RevenueFact
SET Sizeid = 'L'
WHERE NumberOfEmployees > 100;

-- Create the final fact table for revenue fact
DROP TABLE RevenueFact CASCADE CONSTRAINTS PURGE;
CREATE TABLE RevenueFact AS
SELECT T.TimeID, T.SizeID, SUM(T.TotalPrice) AS Total_Leasing_Revenue
FROM temp_RevenueFact T
GROUP BY T.TimeID, T.SizeID;



-- QUERY QUESTIONS

-- QA
SELECT c.Size_description, t.Year, sum(f.Total_Leasing_Revenue) as Total_Leasing_Revenue
from RevenueFact f, company_size_dim c, time_dim t
WHERE f.Timeid = t.Timeid
AND f.Sizeid = c.Sizeid
AND t.Year = '2019'
Group by c.Size_description, t.Year;

-- QB
SELECT u.Utilities_description, t.Year, t.Quarter, sum(f.Total_service_charge) as Total_service_charge
from UtilityFact f, utilities_dim u, time_dim t
WHERE f.Timeid = t.Timeid
AND f.UtilitiesID = u.UtilitiesID
AND u.Utilities_description = 'Water'
AND t.Year = '2016'
AND t.Quarter = '1'
Group by u.Utilities_description, t.Year, t.Quarter;

-- QC
SELECT c.Size_description, d.Duration_description, sum(f.Num_of_contracts) as Num_Of_Contracts
from ContractFact f, company_size_dim c, duration_dim d
WHERE f.Sizeid = c.Sizeid
AND f.DurationID = d.DurationID
AND c.Size_description = 'Large'
Group by c.Size_description, d.Duration_description;

-- QD
SELECT c.Size_description, t.Year, sum(f.Num_of_contracts) as Number_Of_Contracts
from ContractFact f, company_size_dim c, time_dim t
WHERE f.Sizeid = c.Sizeid
AND f.TimeID = t.TimeID
Group by c.Size_description, t.Year
ORDER BY Number_Of_Contracts DESC;
 
-- END OF CODE
