CREATE DATABASE	BrazilianExportsStaging
	COLLATE Latin1_General_100_CI_AI_SC_UTF8
GO

USE	BrazilianExportsStaging

--	Create a staging table that receives unchanged columns from kaggle dataset

CREATE TABLE	BrazilianExportsStaging	(		
		"Year"				NVARCHAR(4),
		"Month"				NVARCHAR(2),
		Country				NVARCHAR(50),
		City				NVARCHAR(50),
		"SH2 Code"			INT,
		"SH2 Description"	NVARCHAR(150),
		"Economic Block"	NVARCHAR(50),
		ExportEarnings		INT
										)

/*	
	Create a table containing columns that store an incrementing/identity value and each individual year.
	Year values allow identification of individual years so that year by year batch loading can be performed.
	The most recent identity value is used in SSIS package as a variable that gets summed to the year value to allow
	loading of subsequent year's data.
*/

CREATE TABLE	SSIS_IncVal	(
		"IncVal"	INT IDENTITY(1,1),
		"Year"		INT
							)

--SELECT	MAX(IncVal)
--FROM	SSIS_IncVal


--TRUNCATE TABLE	BrazilianExportsStaging

--TRUNCATE TABLE	SSIS_IncVal
