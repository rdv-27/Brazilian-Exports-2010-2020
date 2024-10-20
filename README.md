# Brazilian-Exports-2010-2020

 ### [YouTube Demonstration](link)

<h2>Description</h2>
End-to-end data project project that utilizes a 3.33 gigabyte CSV dataset containing <a href="https://www.kaggle.com/datasets/hugovallejo/brazil-exports">Brazil's exportation data</a> from 2010 to 2020 and stitches it with <a href="https://en.wikipedia.org/wiki/Global_Industry_Classification_Standard">GICS (Global Industry Classification Standard)</a> and Brazil state and province codes datasets to provide additional insights. Core concepts and methodologies applied include, but are not limited to, dimensional modeling, data stitching, ELT, ETL, data cleaning, reporting, and data visualization. Current version is the result of countless iterations and is a perpetual work in progress.<br />

<h2>Languages, Tools, and Development Environments Used</h2>

- <b>T-SQL</b>
- <b>SSMS</b>
- <b>Power BI</b>
- <b>DAX</b>
- <b>Power BI</b>
- <b>SSIS</b>
- <b>Visual Studio</b>
- <b>Excel</b>

<h2>Power BI Report</h2>

This report analyzes trends in Brazil's exportation from 2010 to 2020. It utilizes several visuals and metrics which can be sliced by date, state, export destination (region or country), sector, industry group, industry, and product.


![image](https://github.com/user-attachments/assets/f1dcb8b7-de2d-4d11-91d5-1fb6517fa259)


Metrics
 
- <b>Total Export Earnings is the simplest, it shows the sum of export earnings according to the filters applied in a given moment.</b>
- <b>Export Earnings Per Month divides Total Export Earnings by the number of months present in the current filter context to give the earnings per month for a given time period.</b>
- <b>Export Concentration shows you what percentage of export earnings something accounts for. For example, it can show you what percentage of export earnings a sector, state, or foreign market accounts for. In this way you can see how important certain markets, sectors, and states are.</b>
- <b>	State Export Concentration only shows a value once you’ve selected a state. State Export Concentration shows the percentage of export earnings something accounts for within the selected state.</b>
- <b>	Export Earnings MoM shows how earnings fluctuate from month to month in a given time period.</b>
- <b>	Export Earnings YoY shows how earnings vary from the previous year to the current year or if several years are selected it gives the average YoY change for those years.</b>
 
Visualizations
 
•	The State map shows Brazil’s states which are shaded according to Total Export Earnings. Darker shades represent higher Export Earnings and vice versa.
•	The Export Destination map shows the regions and countries that Brazil exports to. To see the countries Brazil exports to, you drill down on the region containing the country. Darker shades represent higher Export Earnings and vice versa.
•	The Sector/.../Product line and clustered column chart is four tiered and can drill down from Sector all the way to Product. It visualizes EE Month over Month, EE Year over Year, and Export Concentration as lines.
•	The Month/Year line and clustered column chart shows individual years and can drill down on each of those individual years to show months or it can drill down and show monthly averages for multiple years. It also visualizes three of the metrics as lines.


