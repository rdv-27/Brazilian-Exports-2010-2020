-- Create database to receive, transform, and store data 

CREATE DATABASE	BrazilianExports
	COLLATE Latin1_General_100_CI_AI_SC_UTF8

GO

/*
	Use staging database to access staging table. Update values since the previous values/geographic regions
	don't show up on Power BI map visualizations.
*/

USE		BrazilianExportsStaging

UPDATE	BrazilianExportsStaging.dbo.BrazilianExportsStaging
SET		[Economic Block] = 'Asia (minus MIDDLE EAST)'
WHERE	[Economic Block] = 'Middle East'

UPDATE	BrazilianExportsStaging.dbo.BrazilianExportsStaging
SET		[Economic Block] = 'North America'
WHERE	[Economic Block] = 'Central America and Caribbean'

-- Use/return to BrazilianExports database

USE		BrazilianExports

GO

/*
	Create function to properly format date. Use first day of each month since report data granularity
	doesn't require day to day analysis.
*/

CREATE FUNCTION [dbo].[udf_DateFromInt_MOD] (@Month CHAR(2), @Year CHAR(4)) 
RETURNS DATE
AS
BEGIN
	DECLARE @date_out DATE = CAST((@Year + '/' + @Month + '/' + '01') AS DATE)
	RETURN @date_out
END


/*
	SELECT INTO statement modifies column data, generates new columns, and loads this data into a 2nd table.
	WHERE clause filters out regions/economic blocks containing duplicate rows.
*/

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
		THEN LEFT([Economic Block], CHARINDEX(' (', [Economic Block], 1)) 
		ELSE [Economic Block] END Region,
		"SH2 Code" ProductCode, 
		"SH2 Description" Product,
		ExportEarnings
INTO	BrazilianExports
FROM	BrazilianExportsStaging.dbo.BrazilianExportsStaging
WHERE	[Economic Block] NOT IN ('Southern Common Market (MERCOSUL)', 'Association Of Southeast Asian Nations (ASEAN)'
,'European Union (EU)', 'Andean Community')

GO

--	Temp table is created to temporarily hold city and state data. 3 Dim tables are created.

CREATE TABLE	#Dim_BrazilLocation1stVer	(
	CityID		INT IDENTITY (1,1),
	City		VARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC_UTF8,
	"State"		VARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC_UTF8
											)	
	
CREATE TABLE	Dim_ExportDestination	(
	CountryID	INT IDENTITY (1,1),
	Country		VARCHAR(100),
	Region		VARCHAR(100),
		CONSTRAINT PK_Dim_ExportDestination_CountryID PRIMARY KEY CLUSTERED (CountryID),--,
		CONSTRAINT AK_Country_Region UNIQUE(Country, Region)
										)

--CREATE UNIQUE INDEX AK_Country_Region ON Dim_ExportDestination (Country, Region)
--	WITH (IGNORE_DUP_KEY = ON);

CREATE TABLE Dim_Product	(
	ProductCode	INT,
	Product		VARCHAR(140),
	"Industry Code" INT,
	Industry VARCHAR(50),	
	"Industry Group" VARCHAR(50),
	Sector VARCHAR(30),
		CONSTRAINT PK_Dim_Product_ProductCode PRIMARY KEY CLUSTERED (ProductCode)
							)

CREATE TABLE	Dim_Date	(
	DateID		INT,
	"Date"		DATE,
	"Year"		INT,
	"Quarter"	VARCHAR(5),
	"Month"		VARCHAR(15),
	"MonthNum"	INT,
	"DateIncRef"	DATETIME,
		CONSTRAINT PK_Dim_Date_Test_DateID PRIMARY KEY CLUSTERED (DateID)
							)
							
------------------------------------------------- Dim_BrazilLocation ----------------------------------------------------

-- Unique city and state combinations are inserted into #Dim_BrazilLocation1stVer temp table.

INSERT INTO		#Dim_BrazilLocation1stVer(City, State)
SELECT DISTINCT	City, State
FROM BrazilianExports
ORDER BY City

--SELECT * FROM Dim_BrazilLocation1stVer

-- State codes table is created and loaded.

CREATE TABLE	StateCodes	(
		"State/Province" VARCHAR(30),
		"State Acronym" CHAR(2)
							)

INSERT INTO	StateCodes
VALUES		('Acre', 'AC'),
			('Alagoas', 'AL'),
			('Amapa', 'AP'),
			('Amazonas', 'AM'),
			('Bahia', 'BA'),
			('Ceara', 'CE'),
			('Distrito Federal', 'DF'),
			('Espirito Santo', 'ES'),
			('Goias', 'GO'),
			('Maranhao', 'MA'),
			('Mato Grosso', 'MT'),
			('Mato Grosso do Sul', 'MS'),
			('Minas Gerais', 'MG'),
			('Para', 'PA'),
			('Paraiba', 'PB'),
			('Parana', 'PR'),
			('Pernambuco', 'PE'),
			('Piaui', 'PI'),
			('Rio Grande do Norte', 'RN'),
			('Rio Grande do Sul', 'RS'),
			('Rio de Janeiro', 'RJ'),
			('Rondonia', 'RO'),
			('Roraima', 'RR'),
			('Santa Catarina', 'SC'),
			('Sao Paulo', 'SP'),
			('Sergipe', 'SE'),
			('Tocantins', 'TO')

/*
	Dim_BrazilLocation table is created, unique index is defined on city, state, state abbreviation combination
	so that city/state combinations are inserted only once. These two columns are later used in a join condition
	to populate the fact table.
*/

CREATE TABLE	Dim_BrazilLocation	(
		[CityID] [int]  IDENTITY(1,1) NOT NULL,
		[City] [varchar](100) NULL,
		[State] VARCHAR(30),
		[State Abbv] [varchar](100) NULL,
			CONSTRAINT PK_Dim_BrazilLocation_CityID PRIMARY KEY CLUSTERED (CityID),--,
			CONSTRAINT AK_City_State UNIQUE(City, [State])--, [State Abbv])
									)

--CREATE UNIQUE INDEX AK_City_State_StateAbbv ON Dim_BrazilLocation (City, [State], [State Abbv])
--	WITH (IGNORE_DUP_KEY = ON);

-- Values are inserted into Dim_BrazilLocation from temp table and State codes table.

INSERT INTO Dim_BrazilLocation (City, State, "State Abbv")
SELECT		DBL.City, SC.[State/Province], DBL.State[State]
FROM		#Dim_BrazilLocation1stVer DBL
LEFT JOIN	StateCodes SC
ON			DBL.State = SC.[State Acronym]

-----------------------------------------------------------------------------------------------------------------------

--SELECT DISTINCT Country,[Economic Block] FROM BrazilianExportsNoDupes
--Where --[Economic Block] LIKE 'Africa%'--or  
--[Economic Block] LIKE 'Middle East'

--SELECT	[Economic Block], Country, SUM(CAST(ExportEarnings AS bigint)) AS SumEarnings
--FROM		BrazilianExports
--WHERE		Country IN ('Egypt')
--GROUP BY	[Economic Block], Country

---------------------------------------------------- Dim_Destination --------------------------------------------------

-- Insert distinct export destination country and city values.

INSERT INTO Dim_ExportDestination (Country, Region)
SELECT DISTINCT Country, Region
FROM BrazilianExports
ORDER BY Country

--SELECT * FROM Dim_ExportDestination

----------------------------------------------------- Dim_Product -----------------------------------------------------

/*
	Insert all product, industry, and sector data into product dimension. This data had to be manually
	matched in excel, since industry and sector were not found in the original dataset, and loaded entirely at once.
*/

INSERT INTO	Dim_Product
VALUES(1 , 'Live animals' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(2 , 'Meat and edible meat offal' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(3 , 'Fish and crustaceans, molluscs and other aquatic invertebrates' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(4 , 'Dairy produce; birds'' eggs; natural honey; others' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(5 , 'Products of animal origin, not specified or included elsewhere' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(6 , 'Live trees and other plants; others' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(7 , 'Edible vegetables and certain roots and tubers' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(8 , 'Edible fruit and nuts; peel of citrus fruits or melons' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(9 , 'Coffee, tea, maté and spices' , '302010' , 'Beverages' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(10 , 'Cereals' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(11 , 'Products of the milling industry; Malt; Starches; Inulin; Wheat gluten' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(12 , 'Oil seeds and oleaginous fruits; Grains, Seeds, others' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(13 , 'Lac; gums, resins and other vegetable saps and extracts' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(14 , 'Vegetable plaiting materials; Vegetable products not elsewhere specified or included' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(15 , 'Animal or vegetable fats and oils; Others' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(16 , 'Preparations of meat, of fish or of crustaceans, others' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(17 , 'Sugars and sugar confectionery' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(18 , 'Cocoa and cocoa preparations' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(19 , 'Preparations of cereals, flour, starch or milk; pastrycooks'' products' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(20 , 'Preparations of vegetables, fruit, nuts or other parts of plants' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(21 , 'Miscellaneous edible preparations' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(22 , 'Beverages, spirits and vinegar' , '302010' , 'Beverages' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(23 , 'Residues and waste from the food industries; others' , '202010' , 'Commercial Services & Supplies' , 'Commercial & Professional Services' ,'Industrials'),
(24 , 'Tobacco and manufactured tobacco substitutes' , '302020' , 'Food Products' , 'Food, Beverage & Tobacco' ,'Consumer Staples'),
(25 , 'Salt; sulphur; earths and stone; plastering materials, lime and cement' , '151020' , 'Construction Materials' , 'Materials' ,'Materials'),
(26 , 'Ores, slag and ash' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(27 , 'Mineral fuels, mineral oils, bituminous substances; mineral waxes' , '101020' , 'Oil, Gas & Consumable Fuels' , 'Energy' ,'Energy'),
(28 , 'Inorganic chemicals; organic or inorganic compounds of precious metals, others' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(29 , 'Organic chemicals' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(30 , 'Pharmaceutical products' , '352020' , 'Pharmaceuticals' , 'Pharmaceuticals, Biotechnology & Life Sciences' ,'Health Care'),
(31 , 'Fertilisers' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(32 , 'Tanning or dyeing extracts; tannins and their derivatives; others' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(33 , 'Essential oils and resinoids; perfumery, cosmetic or toilet preparations' , '303020' , 'Personal Products' , 'Household & Personal Products' ,'Consumer Staples'),
(34 , 'Soap, organic surface-active agents, others' , '303010' , 'Household Products' , 'Household & Personal Products' ,'Consumer Staples'),
(35 , 'Albuminoidal substances; modified starches; glues; enzymes' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(36 , 'Explosives; pyrotechnic products; matches; others' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(37 , 'Photographic or cinematographic goods' , '255040' , 'Specialty Retail' , 'Retailing' ,'Consumer Discretionary'),
(38 , 'Miscellaneous chemical products' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(39 , 'Plastics and articles thereof' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(40 , 'Rubber and articles thereof' , '151010' , 'Chemicals' , 'Materials' ,'Materials'),
(41 , 'Raw hides and skins (other than furskins), and leather' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(42 , 'Articles of leather; articles of animal gut (other than silkworm gut),, others' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(43 , 'Furskins and artificial fur; manufactures thereof' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(44 , 'Wood and articles of wood; wood charcoal' , '151050' , 'Paper & Forest Products' , 'Materials' ,'Materials'),
(45 , 'Cork and articles of cork' , '151050' , 'Paper & Forest Products' , 'Materials' ,'Materials'),
(46 , 'Manufactures of straw, of esparto or of other plaiting materials ' , '151050' , 'Paper & Forest Products' , 'Materials' ,'Materials'),
(47 , 'Pulp of wood or of other fibrous cellulosic material, others,' , '151050' , 'Paper & Forest Products' , 'Materials' ,'Materials'),
(48 , 'Paper and paperboard; articles of paper pulp, of paper or of paperboard' , '151050' , 'Paper & Forest Products' , 'Materials' ,'Materials'),
(49 , 'Books, newspapers, pictures and other products of the printing industry; others' , '502010' , 'Media' , 'Media & Entertainment' ,'Communication Services'),
(50 , 'Silk' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(51 , 'Wool, fine or coarse animal hair; horsehair yarn and woven fabric' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(52 , 'Cotton' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(53 , 'Other vegetable textile fibres; paper yarn and woven fabrics of paper yarn' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(54 , 'Man-made filaments' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(55 , 'Man-made staple fibres' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(56 , 'Wadding, felt and nonwovens; others' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(57 , 'Carpets and other textile floor coverings' , '252010' , 'Household Durables' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(58 , 'Special woven fabrics; tufted textile fabrics; lace; tapestries; others' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(59 , 'Impregnated, coated, covered or laminated textile fabrics; others' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(60 , 'Lnitted or crocheted fabrics' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(61 , 'Articles of apparel and clothing accessories, knitted or crocheted' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(62 , 'Articles of apparel and clothing accessories, not knitted or crocheted' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(63 , 'Other made-up textile articles; sets; rags, others' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(64 , 'Footwear, gaiters and the like; parts of such articles' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(65 , 'Headgear and parts thereof' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(66 , 'Umbrellas, sun umbrellas, walking-sticks, seat-sticks, whips, riding-crops, others' , '255040' , 'Specialty Retail' , 'Retailing' ,'Consumer Discretionary'),
(67 , 'Prepared feathers and articles made of feathers or of down; others' , '252030' , 'Textiles, Apparel & Luxury Goods' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(68 , 'Articles of stone, plaster, cement, asbestos, mica or similar materials' , '201020' , 'Building Products' , 'Capital Goods' ,'Industrials'),
(69 , 'Ceramic products' , '252010' , 'Household Durables' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(70 , 'Glass and glassware' , '252010' , 'Household Durables' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(71 , 'Natural or cultured pearls, precious or semi-precious stones, others' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(72 , 'Iron and steel' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(73 , 'Articles of iron or steel' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(74 , 'Copper and articles thereof' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(75 , 'Nickel and articles thereof' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(76 , 'Aluminium and articles thereof' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(78 , 'Lead and articles thereof' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(79 , 'Zinc and articles thereof' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(80 , 'Tin and articles thereof' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(81 , 'Other base metals; cermets; articles thereof' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(82 , 'Tools, implements, cutlery, spoons and forks, of base metal; parts thereof of base metal' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(83 , 'Miscellaneous articles of base metal' , '151040' , 'Metals & Mining' , 'Materials' ,'Materials'),
(84 , 'Nuclear reactors, boilers, machinery and mechanical appliances; others' , '201060' , 'Machinery' , 'Capital Goods' ,'Industrials'),
(85 , 'Electrical machinery and equipment and parts thereof; others' , '201040' , 'Electrical Equipment' , 'Capital Goods' ,'Industrials'),
(86 , 'Railway or tramway locomotives, rolling-stock and parts thereof; others' , '201060' , 'Machinery' , 'Capital Goods' ,'Industrials'),
(87 , 'Vehicles other than railway or tramway rolling-stock, and parts and accessories thereof' , '251020' , 'Automobiles' , 'Automobiles & Components' ,'Consumer Discretionary'),
(88 , 'Aircraft, spacecraft, and parts thereof' , '201010' , 'Aerospace & Defense' , 'Capital Goods' ,'Industrials'),
(89 , 'Ships, boats and floating structures' , '201040' , 'Electrical Equipment' , 'Capital Goods' ,'Industrials'),
(90 , 'Optical, photographic, cinematographic instruments; others' , '255040' , 'Specialty Retail' , 'Retailing' ,'Consumer Discretionary'),
(91 , 'Clocks and watches and parts thereof' , '252020' , 'Leisure Products' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(92 , 'Musical instruments; parts and accessories of such articles' , '252020' , 'Leisure Products' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(93 , 'Arms and ammunition; parts and accessories thereof' , '255010' , 'Distributors' , 'Retailing' ,'Consumer Discretionary'),
(94 , 'Furniture; bedding, mattresses, cushions and similar stuffed furnishings; others' , '252010' , 'Household Durables' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(95 , 'Toys, games and sports requisites; parts and accessories thereof' , '252020' , 'Leisure Products' , 'Consumer Durables & Apparel' ,'Consumer Discretionary'),
(96 , 'Miscellaneous manufactured articles' , '255030' , 'Multiline Retail' , 'Retailing' ,'Consumer Discretionary'),
(97 , 'Works of art, collectors'' pieces and antiques' , '255040' , 'Specialty Retail' , 'Retailing' ,'Consumer Discretionary'),
(99 , 'Special operations' , '151010' , 'Chemicals' , 'Materials' ,'Materials')


------------------------------------------------------- Dim_Date -------------------------------------------------------

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Nums table created to hold numbers.

CREATE TABLE [dbo].[Nums](
	[n] [int] NOT NULL,
 CONSTRAINT [PK_Nums] PRIMARY KEY CLUSTERED 
(
	[n] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

-- WHILE loop used to populate Nums table.

DECLARE @Count INT = 1

WHILE @Count < 1000 BEGIN
	INSERT INTO [BrazilianExports].[dbo].[Nums]
	VALUES (@Count)
	SET @Count += 1;
END

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
	This data is then immediately inserted into the date dimension where new columns are generated.
*/	

WITH CTE (Date)
AS
(
SELECT DATEADD(day, n-1, @StartDate) AS Date
FROM dbo.Nums
WHERE n <= DATEDIFF(day, @StartDate, @EndDate) + 1
)
INSERT INTO	Dim_Date
SELECT CAST(MONTH(Date) AS VARCHAR) + '0' + CAST(DAY(Date) AS VARCHAR) + CAST(YEAR(Date) AS VARCHAR) DateID,
Date, YEAR(Date) AS Year, DATEPART(qq, Date) AS Quarter, DATENAME(mm, Date) AS Month, 
MONTH(Date) AS MonthNum, CAST(Date AS DATETIME) AS DateIncRef
FROM CTE
ORDER BY Year, MonthNum

--SELECT		*
--FROM		Dim_Date

-------------------------------------------- Fact_BrazilExports --------------------------------------------------

/*	
	Create fact table by storing all quantitative columns and establishing referential integrity between
	primary keys in dimension tables and corresponding keys in fact table.
*/

CREATE TABLE	Fact_BrazilExports	(
				DateID INT,
				ProductCode	INT,
				CityID	INT,
				CountryID	INT,
				ExportEarnings	INT,
				"DateIncRef" DATETIME,
				CONSTRAINT FK_Fact_BrazilExports_Dim_Date FOREIGN KEY (DateID)
				REFERENCES Dim_Date (DateID),
				CONSTRAINT FK_Fact_BrazilExports_Dim_Product FOREIGN KEY (ProductCode)
				REFERENCES Dim_Product (ProductCode),
				CONSTRAINT FK_Fact_BrazilExports_Dim_BrazilLocation FOREIGN KEY (CityID)
				REFERENCES Dim_BrazilLocation (CityID),
				CONSTRAINT FK_Fact_BrazilExports_Dim_ExportDestination FOREIGN KEY (CountryID)
				REFERENCES Dim_ExportDestination (CountryID),
									)

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
ON				DD.Country = BE.Country --AND DD.Region = BE.Region