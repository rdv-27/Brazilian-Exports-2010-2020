# Brazilian-Exports-2010-2020

 ### [YouTube Demonstration](link)

<h2>Description</h2>
End-to-end data project project that utilizes a 3.33 gigabyte CSV dataset containing <a href="https://www.kaggle.com/datasets/hugovallejo/brazil-exports">Brazil's exportation data</a> from 2010 to 2020 and stitches it with <a href="https://en.wikipedia.org/wiki/Global_Industry_Classification_Standard">GICS (Global Industry Classification Standard)</a> and Brazil state and province codes datasets to provide additional insights. Core concepts and methodologies applied include, but are not limited to, dimensional modeling, data stitching, ELT, ETL, data cleaning, reporting, and data visualization. Current version is the result of countless iterations and is a perpetual work in progress.<br />

<h2>Programming Languages, Tools, and Development Environments Used</h2>

- <b>T-SQL</b>
- <b>SSMS</b>
- <b>Power BI</b>
- <b>DAX</b>
- <b>Power BI Desktop</b>
- <b>SSIS</b>
- <b>Visual Studio</b>
- <b>Excel</b>

<h2>Power BI Report</h2>

This report analyzes trends in Brazil's exportation from 2010 to 2020. It utilizes several visuals and metrics which can be sliced by date, state, export destination (region or country), sector, industry group, industry, and product.


![image](https://github.com/user-attachments/assets/f1dcb8b7-de2d-4d11-91d5-1fb6517fa259)


<h3>Metrics</h3>
 
- <b>Total Export Earnings</b> is the simplest, it shows the sum of export earnings according to the filters applied at a given moment.
- <b>Export Earnings Per Month</b> divides Total Export Earnings by the number of months present in the current filter context to give the earnings per month for a given time period.
- <b>Export Concentration</b> shows you what percentage of export earnings something accounts for. For example, it can show you what percentage of export earnings a sector, state, or foreign market accounts for. In this way you can see how important certain markets, sectors, and states are.
- <b>State Export Concentration</b> only shows a value once you’ve selected a state. State Export Concentration shows the percentage of export earnings something accounts for within the selected state.
- <b>Export Earnings MoM</b> shows how earnings fluctuate from month to month in a given time period.
- <b>Export Earnings YoY</b> shows how earnings vary from the previous year to the current year or if several years are selected it gives the average YoY change for those years.
 
<h3>Visualizations</h3>
 
-	The <b>State map</b> shows Brazil’s states which are shaded according to Total Export Earnings. Darker shades represent higher Export Earnings and vice versa.
-	The <b>Export Destination map</b> shows the regions and countries that Brazil exports to. To see the countries Brazil exports to, you drill down on the region containing the country. Darker shades represent higher Export Earnings and vice versa.
-	The <b>Sector/.../Product line and clustered column chart</b> is four tiered and can drill down from Sector all the way to Product. It visualizes EE Month over Month, EE Year over Year, and Export Concentration as lines.
-	The <b>Month/Year line and clustered column chart</b> shows individual years and can drill down on each of those individual years to show months or it can drill down and show monthly averages for multiple years. It also visualizes three of the metrics as lines.

<h2>Process</h2>

I had to approach this project from various angles. I initially attempted to load the CSV file directly into Power BI, where I additionally had to alter the file to create fact and dimension tables using Power Query. It NEVER finished loading, 3.3 GB was too much data and transformation for Power Query to handle. I then decided that I would need to load this data into a dimensional model in SQL Server to be able to then load it into Power BI (PBI plays nice with star schemas). <a href="https://github.com/rdv-27/Brazilian-Exports-2010-2020/blob/main/2.%20BrazilianExports_Full%20DB%20Creation%20Mod%20Updated.sql">Here is the code I used<a/> to create the database containing the dimensional model as well as a staging table to receive the initial data load.

![SQL Server BE Diagram](https://github.com/user-attachments/assets/0d80f2d0-4927-4520-b276-275612c65212)

In one variant, I loaded the data directly into SQL Server using BULK INSERT.

![image](https://github.com/user-attachments/assets/2d687ecb-6f1d-4c09-8b48-b7b53bee0a48)

But ultimately I decided to use SSIS to load the data since it provided a more realistic use case and allowed me to practice using it.

I used Power Query in Excel to obtain distinct values for product code and product description. The Brazil Exports dataset contained two levels/hierarchies of detail (SH4 Code/SH4 Description & SH2 Code/SH2 Description) for product information which was excessive detail, so I decided to forego the second level of detail and just use SH2 Code and SH2 Description.

![image](https://github.com/user-attachments/assets/9f4094ef-eae4-4796-b018-79dafd64205e)

By doing this, I was able to obtain a list of 97 distinct product codes and products instead of 1226. I manually matched these values and stitched them to values from the GICS dataset.

![image](https://github.com/user-attachments/assets/d2f2f530-7186-4381-9160-c3796f73914a)

![image](https://github.com/user-attachments/assets/65b167de-3e8b-47d2-abbd-c5f03dec30b7)

I created a staging database and within it a staging table and a table called IncVal (short for incrementing value) as well as a database to hold a second staging table and fact and dimension tables. The IncVal table consisted of an integer identity column called IncVal and an integer column called Year. <a href="https://github.com/rdv-27/Brazilian-Exports-2010-2020/blob/main/1.%20Create%20BrazilianExports_Staging%20Updated.sql">Code found here.</a> 

<br>

I then created an SSIS package using Visual Studio. I wanted to load the data into the dimensional model year-by-year, so I set the SSIS package to load data into the staging and IncVal tables within the staging database. This data was then SELECTed INTO the staging table in the Brazil Exports database where transformations were simultaneously applied and then loaded into corresponding fact and dimension tables. A Stored Procedure was created to encapsulate most of this logic, WHERE NOT EXISTS was added to the code for the loading of two dimension tables to provide incremental loading and SCD type 2 functionality. <a href="https://github.com/rdv-27/Brazilian-Exports-2010-2020/blob/main/3.%20InsertToFactAndDimensionTablesSP%20Error%20Handling.sql">Code found here.</a> 

The SSIS package was then modified to TRUNCATE the staging table in the staging database which would then be followed by a data flow that made some minimal transformations and loaded into the staging table in the staging database, this was ultimately followed by a(n EXECUTE SQL) Task that executed the stored procedure.

![SSIS BE Control Flow](https://github.com/user-attachments/assets/733918c6-8815-4ea4-8364-62b37c1f55c2)

![SSIS BE Data Flow](https://github.com/user-attachments/assets/90eb4f1f-5d18-4c4c-8d16-9036d1447847)

The entire ETL/ELT process was then automated by creating a SQL Server Agent Job that automated the process by scheduling regular executions of the job.

![SQL Server Agent Job](https://github.com/user-attachments/assets/1a3268dd-c94f-449d-b0b7-1d62044fe8e1)

![SQL Server Agent Job #2](https://github.com/user-attachments/assets/4bb8b008-dd22-4754-b4f5-450eb84d725c)

<h2>Challenges</h2>

The dataset I chose was appealing mainly for the technical challenges it posed, however I am most definitely a fan of Brazilian culture (music, soccer, and geography). As I’ve mentioned I had to explore various approaches. It was considerably larger than most of the other datasets on Kaggle, so it forced me to explore various approaches when it came to loading it into Power BI.

In SSIS I had to utilize variables to load data year by year; I also had to learn how to handle different collation/UTF-8 data. The dataset contained duplicate values; it contained an attribute/column that specified the region that a product was exported to, but some rows described the exact same transaction and thus overlapped, e.g. you would have two rows describing the exact same transaction with one classified as exported to Europe and the other as European Union or South America and Mercosul (Southern Common Market).

![1c](https://github.com/user-attachments/assets/f2ec1f8d-ffc8-4519-9c18-adc3de946abd)

Below you can see how data for Argentina was duplicated because Argentina was grouped in two separate regions.

![1d](https://github.com/user-attachments/assets/615e6834-ec67-4550-8a0d-74dc433d4a63)

So to account for this when SELECTing INTO the second staging table I used a WHERE clause to filter out values that corresponded to an economic grouping and not to a geographic grouping. For that reason, I filtered out MERCOSUL, European Union, Andean Community, and ASEAN since they duplicated values and unintentionally doubled the quantities.

![image](https://github.com/user-attachments/assets/c824939d-a027-4056-91c4-ecd97806f7ed)

Another challenge occurred because I split a column from the original dataset into state and city columns in the Brazil Exports database. The thing is some cities in Brazil (as in many other places) share the same name, so when I populated my Fact table by pulling data from all the dimension tables using LEFT JOINs, I needed to account for this by using City and State columns as join conditions so that the correct level of granularity was specified, and I didn’t get additional/invalid rows.

![image](https://github.com/user-attachments/assets/8d7c300b-5365-4a65-a7a6-6e83365c2c27)

When it came to Power BI, the project posed many challenges. For any type of time analysis you need to use DAX functions referred to as Time Intelligence functions which requires that you to have what’s known as a Date/Calendar table. But this Date table needs to have a continuous range of dates, even if those dates aren’t relevant to your data, so that Power BI can slice your data by date. The data in the Brazil Exports dataset doesn’t have continuous dates, it just contains year and month information, so I had to implement logic in SQL Server to give date dimension data the necessary format to create continuous dates in the date dimension. Below is the code I used:

![image](https://github.com/user-attachments/assets/81855e69-5581-464a-970e-655871cea64f)

I also implemented this logic using DAX in one of my many iterations.

![image](https://github.com/user-attachments/assets/b1d8f406-57ed-4f89-823d-daf4a1d5fe11)


