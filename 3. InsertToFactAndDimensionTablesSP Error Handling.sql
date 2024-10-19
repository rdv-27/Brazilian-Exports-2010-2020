/*
	Create stored procedure which is used in an SSIS package that is automated by a SQL Server Agent job.
	This allows loading of the dimensional model to be executed automatically in one step.
*/

CREATE PROCEDURE	usp_InsertToFactAndDimensionTablesUpdated
AS
SET NOCOUNT ON
SET XACT_ABORT ON;

/*
	Begin Transaction. This transaction ensures that all statements that run within its boundaries complete fully
	or else the entire transaction is rolled back.
*/

BEGIN
	BEGIN TRY

		BEGIN TRAN

--	Update values since the previous values/geographic regions don't show up on Power BI map visualizations.
	
			UPDATE	BrazilianExportsStaging.dbo.BrazilianExportsStaging
			SET		[Economic Block] = 'Asia (minus MIDDLE EAST)'
			WHERE	[Economic Block] = 'Middle East'

			UPDATE	BrazilianExportsStaging.dbo.BrazilianExportsStaging
			SET		[Economic Block] = 'North America'
			WHERE	[Economic Block] = 'Central America and Caribbean'

-- Truncate BrazilianExports so previous load's values are cleared.

			TRUNCATE TABLE BrazilianExports

			INSERT INTO	BrazilianExports
			SELECT	Year, 
					Month,
					("Month" + '01' + "Year") DateID,
	  				--FORMAT(CAST(("Month" + '/' + '01' + '/' + "Year") AS datetime), 'dd/MM/yyyy') Date,
					[dbo].[udf_DateFromInt_MOD] (Month, Year) Date,
					LEFT(City, CHARINDEX(' -', City, 1)) City,
					RIGHT(City, 2) State,
					Country,
					CASE 
					WHEN CHARINDEX(' (', [Economic Block],1) > 0 
					THEN LEFT([Economic Block], CHARINDEX(' (', [Economic Block],1)) 
					ELSE [Economic Block] END Region,
					"SH2 Code" ProductCode, 
					"SH2 Description" Product,
					ExportEarnings
			FROM	BrazilianExportsStaging.dbo.BrazilianExportsStaging
			WHERE	[Economic Block] NOT IN ('Southern Common Market (MERCOSUL)', 'Association Of Southeast Asian Nations (ASEAN)',
						'European Union (EU)', 'Andean Community')

-- Drop temp table and insert new values into it.

			DROP TABLE IF EXISTS  #Dim_BrazilLocation1stVer
			CREATE TABLE	#Dim_BrazilLocation1stVer	(
				CityID		INT PRIMARY KEY IDENTITY (1,1),
				City		VARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC_UTF8,
				"State"		VARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC_UTF8--,
				--"State Abbv" VARCHAR(5)  COLLATE Latin1_General_100_CI_AI_SC_UTF8
														)	

			INSERT INTO		#Dim_BrazilLocation1stVer(City, State)
			SELECT DISTINCT	City, State
			FROM BrazilianExports
			WHERE State NOT IN ('ND', 'EX')
			ORDER BY City


			INSERT INTO Dim_BrazilLocation (City, State, "State Abbv")
			SELECT		DBLV.City, SC.[State/Province], DBLV.[State]
			FROM		#Dim_BrazilLocation1stVer DBLV
			LEFT JOIN	StateCodes SC
			ON			DBLV.State = SC.[State Acronym]
			WHERE NOT EXISTS
			(
				SELECT	DBLV.City, SC.[State/Province]
				FROM	Dim_BrazilLocation DBL
				WHERE	DBLV.City = DBL.City AND SC.[State/Province] = DBL.State
			);

/*
	Insert into export destination dimension. WHERE NOT EXISTS checks for existing rows/values by comparing values
	between two tables and only inserts those that don't already exist in the table. This is approach is used as
	an alternative to the MERGE statement which is said to be more costly than running individual update, 
	delete, insert operations.
*/

			INSERT INTO  Dim_ExportDestination (Country, Region)
			SELECT DISTINCT Country, Region
			FROM BrazilianExports BEF
			WHERE NOT EXISTS
			(
				SELECT	BEF.Country, BEF.Region	
				FROM	Dim_ExportDestination DED
				WHERE	BEF.Country = DED.Country AND BEF.Region = DED.Region
			)
			ORDER BY Country

-- Create a temp table to hold intermediate values

			CREATE TABLE	#Dim_Date_Temp	(
				DateID VARCHAR(15), 
				Date DATE, 
				Year INT, 
				"Quarter" INT, 
				Month VARCHAR(15), 
				MonthNum INT, 
				DateIncRef DATETIME
											)


/*
	Declare and initialize StartDate and EndDate variables. These variables hold min and max values from BrazilianExports
	table which contains data for a given individual year per each batch load. The original dataset doesn't contain data
	for every day, just for every month, but to declare a table as a Date table in Power BI you need to have a continuous
	set of dates. So this is the purpose for this entire section.
*/

			DECLARE	@StartDate DATE, @EndDate DATE;

			SELECT	@StartDate = CAST(MIN(Date) AS DATE) FROM BrazilianExports
			SELECT	@EndDate = CAST(EOMONTH(MAX(Date)) AS DATE) FROM BrazilianExports;

/*
	Use CTE to hold a query that is used to generate a range of dates from the beginning to the end of a given year.
	This data is then inserted into the Dim_Date temp table where new columns are generated.
*/	

			WITH CTE (Date)
			AS
			(
			SELECT DATEADD(day, n-1, @StartDate) AS Date
			FROM dbo.Nums
			WHERE n <= DATEDIFF(day, @StartDate, @EndDate) + 1
			)
			INSERT INTO	#Dim_Date_Temp
			SELECT CAST(MONTH(Date) AS VARCHAR) + '0' + CAST(DAY(Date) AS VARCHAR) + CAST(YEAR(Date) AS VARCHAR) DateID,
			Date, YEAR(Date) AS Year, DATEPART(qq, Date) AS Quarter, DATENAME(mm, Date) AS Month, 
			MONTH(Date) AS MonthNum, CAST(Date AS DATETIME) AS DateIncRef
			FROM CTE

/*
	WHERE NOT EXISTS checks for existing rows/values by comparing values between two tables and only inserts
	those that don't already exist in the table.
*/

			INSERT INTO Dim_Date
			SELECT DateID, Date, Year, "Quarter", Month, MonthNum, DateIncRef 
			FROM #Dim_Date_Temp DDT
			WHERE NOT EXISTS
			(
				SELECT	DDT.DateID
				FROM	Dim_Date DD
				WHERE	DDT.DateID = DD.DateID
			)
			ORDER BY Year, MonthNum

/*
	Populate fact table with a given year's worth of data by inserting quantitative values from each dimension using
	left joins. The Dim_BrazilLocation join condition offered a great learning opportunity because some cities in certain
	states had the same name, so if I joined just on city it resulted in many-to-many joins and produced additional rows,
	so I had to add State/State Abbv to the join condition.
*/			

			INSERT INTO		Fact_BrazilExports
			SELECT			DDa.DateID, DPP.ProductCode, DBL.CityID, DD.CountryID, ExportEarnings, DDa.DateIncRef
			FROM			dbo.BrazilianExports BE
			LEFT JOIN		Dim_Date DDa
			ON				DDa.DateID = BE.DateID
			LEFT JOIN		Dim_Product DPP
			ON				DPP.ProductCode = BE.ProductCode
			LEFT JOIN		Dim_BrazilLocation DBL
			ON				DBL.City = BE.City AND DBL.[State Abbv] = BE.State
			LEFT JOIN		Dim_ExportDestination DD
			ON				DD.Country = BE.Country
		
		COMMIT TRAN --InsertToDims

/*
	Catch block begins. It only runs if an error occurs in the try block. In this code IF @@TRANCOUNT > 0 checks
	if a transaction is open, if it is (i.e. a value greater than 0 is returned) then the transaction is rolled back.
	DECLARE @msg stores a message detailing the error that caused the catch block to execute. This message is then
	returned using RAISERROR. The maximum value in the IncVal column is referenced to delete it's corresponding row.
	This is done because the maximum IncVal is referenced in an SSIS package, stored as a variable, and summed to
	2010, which allows year-by-year batch loading. If the transaction fails and the most recently inserted IncVal
	value isn't deleted, the next batch will sum that value to 2010 and load the next year, effectively skipping an
	entire year's worth of data.
*/

	END TRY
	BEGIN CATCH

		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION

		DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE()
		RAISERROR(@msg, 16, 1)

		DELETE FROM BrazilianExportsStaging.dbo.SSIS_IncVal
		WHERE (SELECT MAX(IncVal) FROM BrazilianExportsStaging.dbo.SSIS_IncVal) = IncVal

	END CATCH
END