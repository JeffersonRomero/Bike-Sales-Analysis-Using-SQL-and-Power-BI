-- Bike Shop Data Cleaning: Comprehensive Examination

-- Display the entire dataset to understand its structure and contents

SELECT * FROM BikeSales.dbo.Sales

-- Selecting specific columns with a condition on Sub_Category to identify and visualize errors from file importation
-- This step helps in diagnosing issues related to incorrect data parsing or formatting during CSV import

SELECT Sub_Category, Product, Order_Quantity, Unit_Cost, Unit_Price, Profit, Cost, Revenue
FROM BikeSales.dbo.Sales
WHERE Sub_Category = 'Helmets';

-- Observation: The 'Product' column is incorrectly split across multiple columns.
-- Text from the 'Product' column has shifted into 'Order_Quantity', and subsequent columns, 
-- resulting in a situation where the 'Revenue' column contains two values separated by a comma.
-- This issue likely stems from the original CSV file, where the 'Product' field included comma-separated values
-- such as Product, Color/Size, etc., leading to misalignment during the import process.

-- To address the column misalignment issue, we will create new columns to store the corrected data values.
-- This will help in organizing the data correctly and addressing the issues caused by the import process.

-- Adding new columns to the Sales table for corrected data values
ALTER TABLE BikeSales.dbo.Sales
ADD Product_Fixed VARCHAR(255),
    Order_Quantity_Fixed VARCHAR(255),
    Unit_Cost_Fixed VARCHAR(255),
    Unit_Price_Fixed VARCHAR(255),
    Profit_Fixed VARCHAR(255),
    Cost_Fixed VARCHAR(255),
    Revenue_Fixed VARCHAR(255);

-- First, we will clean the Product_Fixed column by removing quotation marks from the Product column.

UPDATE BikeSales.dbo.Sales
SET Product_Fixed = REPLACE(Product, '"', '');

-- Next, we will address the Order_Quantity_Fixed column by removing quotation marks where present.

UPDATE BikeSales.dbo.Sales
SET Order_Quantity_Fixed = REPLACE(Order_Quantity, '"', '')
WHERE CHARINDEX('"', Order_Quantity) > 0;

-- Concatenate the values of Order_Quantity_Fixed with Product_Fixed, separated by a hyphen, 
-- for rows where Order_Quantity_Fixed is not null to correct column misalignment.

UPDATE BikeSales.dbo.Sales
SET Product_Fixed = CONCAT(Product_Fixed, '-', Order_Quantity_Fixed)
WHERE Order_Quantity_Fixed IS NOT NULL;

-- Set Order_Quantity_Fixed to NULL for all rows to prepare for further processing.

UPDATE BikeSales.dbo.Sales
SET Order_Quantity_Fixed = NULL;

-- Remove double quotation marks from Order_Quantity column where they are not present, 
-- and update Order_Quantity_Fixed with the cleaned values.

UPDATE BikeSales.dbo.Sales
SET Order_Quantity_Fixed = REPLACE(Order_Quantity, '"', '')
WHERE CHARINDEX('"', Order_Quantity) = 0;

-- Assign values from the corresponding columns (Unit_Cost, Unit_Price, Profit, Cost, Revenue) 
-- to the new fixed columns (Unit_Cost_Fixed, Unit_Price_Fixed, Profit_Fixed, Cost_Fixed, Revenue_Fixed).

UPDATE BikeSales.dbo.Sales
SET Unit_Cost_Fixed = Unit_Cost,
    Unit_Price_Fixed = Unit_Price,
    Profit_Fixed = Profit,
    Cost_Fixed = Cost,
    Revenue_Fixed = Revenue;

-- Set Unit_Cost_Fixed, Unit_Price_Fixed, Profit_Fixed, Cost_Fixed, and Revenue_Fixed to NULL 
-- for rows where Order_Quantity_Fixed is NULL to clean up data.

UPDATE BikeSales.dbo.Sales
SET 
    Unit_Cost_Fixed = NULL,
    Unit_Price_Fixed = NULL,
    Profit_Fixed = NULL,
    Cost_Fixed = NULL,
    Revenue_Fixed = NULL
WHERE Order_Quantity_Fixed IS NULL;

-- For rows where all the specified columns are NULL, 
-- update them using the COALESCE function to fill in missing values with values from other columns.

UPDATE BikeSales.dbo.Sales
SET 
    Order_Quantity_Fixed = COALESCE(Order_Quantity_Fixed, Unit_Cost),
    Unit_Cost_Fixed = COALESCE(Unit_Cost_Fixed, Unit_Price),
    Unit_Price_Fixed = COALESCE(Unit_Price_Fixed, Profit),
    Profit_Fixed = COALESCE(Profit_Fixed, Cost)
WHERE
    Order_Quantity_Fixed IS NULL
    AND Unit_Cost_Fixed IS NULL
    AND Unit_Price_Fixed IS NULL
    AND Profit_Fixed IS NULL;

-- Update Cost_Fixed with values from Revenue for rows where Cost_Fixed is NULL, 
-- and update Revenue_Fixed with values from Revenue for rows where Revenue_Fixed is NULL.

UPDATE BikeSales.dbo.Sales
SET Cost_Fixed = Revenue
WHERE Cost_Fixed IS NULL;

UPDATE BikeSales.dbo.Sales
SET Revenue_Fixed = Revenue
WHERE Revenue_Fixed IS NULL;

-- Extract and correct the values in Cost_Fixed and Revenue_Fixed by splitting the data 
-- where commas are present to ensure proper formatting.

UPDATE BikeSales.dbo.Sales
SET Cost_Fixed = LEFT(Cost_Fixed, CHARINDEX(',', Cost_Fixed) - 1)
WHERE Cost_Fixed LIKE '%,%';

UPDATE BikeSales.dbo.Sales
SET Revenue_Fixed = RIGHT(Revenue_Fixed, LEN(Revenue_Fixed) - CHARINDEX(',', Revenue_Fixed))
WHERE Revenue_Fixed LIKE '%,%';

-- Finally, remove the original columns (Product, Order_Quantity, Unit_Cost, Unit_Price, Profit, Cost, Revenue) 
-- that were replaced by the new fixed columns.

ALTER TABLE BikeSales.dbo.Sales
DROP COLUMN Product, Order_Quantity, Unit_Cost, Unit_Price, Profit, Cost, Revenue;

-- Before proceeding to data exploration, we will simplify the dataset by removing unnecessary columns. 
-- To streamline the CSV for exploratory data analysis, we will keep only the columns relevant to this analysis. 
-- The columns to be removed are "Date," "Day," "Unit_Cost_Fixed," and "Unit_Price_Fixed."

ALTER TABLE BikeSales.dbo.Sales
DROP COLUMN Date, Day, Unit_Cost_Fixed, Unit_Price_Fixed;

-- Verify the changes by selecting all columns from the Sales table to ensure the data has been cleaned and updated correctly.

SELECT * FROM BikeSales.dbo.Sales;

-- Data Exploration: Analyzing Bike Shop Dataset

-- 1. Age Distribution

SELECT 
    Age_Group,
    Female,
    Male,
    Total
FROM (
    SELECT 
        COALESCE(Age_Group, 'Total') AS Age_Group,
        SUM(CASE WHEN Customer_Gender = 'F' THEN 1 ELSE 0 END) AS Female,
        SUM(CASE WHEN Customer_Gender = 'M' THEN 1 ELSE 0 END) AS Male,
        COUNT(*) AS Total,
        CASE WHEN Age_Group IS NULL THEN 2 ELSE 1 END AS OrderColumn
    FROM 
        Bikes_Sales.dbo.Sales
    GROUP BY 
        Age_Group
    WITH ROLLUP
) AS CombinedResult
ORDER BY 
    OrderColumn, Age_Group DESC;

-- This query provides a breakdown of customer distribution by age group and gender, including a total count.
-- Analyzing this distribution helps understand the customer demographics, which is crucial for targeted marketing and sales strategies.

-- 2. Yearly Financial Trends

SELECT 
    CASE WHEN Year IS NULL THEN 'Total' ELSE Year END AS Year,
    SUM(CAST(Cost_Fixed AS INT)) AS Total_Cost,
    SUM(CAST(Profit_Fixed AS INT)) AS Total_Profit,
    SUM(CAST(Revenue_Fixed AS INT)) AS Total_Revenue
FROM 
    Bikes_Sales.dbo.Sales
GROUP BY 
    Year
WITH ROLLUP;

-- Analyzing yearly financial trends is crucial for understanding how the financial performance of the bike shop has evolved over time.
-- This summary helps identify patterns, seasonal effects, and overall financial health, 
-- providing valuable insights for strategic planning and decision-making.

-- 3. Product Profitability

-- The following query calculates and displays the total profit for each Product_Category and includes the overall total profit:
SELECT 
    Product_Category,
    SUM(CAST(Profit_Fixed AS INT)) AS Total_Profit
FROM 
    Bikes_Sales.dbo.Sales
GROUP BY 
    Product_Category

UNION ALL

SELECT 
    'Total',
    SUM(CAST(Profit_Fixed AS INT)) AS Total_Profit
FROM 
    Bikes_Sales.dbo.Sales

ORDER BY 
    Product_Category;

-- This query provides insights into the profitability of each product category and the overall profit. 
-- It helps in identifying which categories are most profitable and allows for strategic planning and decision-making.

-- The next query breaks down the total profit for each Sub_Category within each Product_Category:
SELECT 
    Product_Category,
    Sub_Category,
    SUM(CAST(Profit_Fixed AS INT)) AS Total_Profit
FROM 
    Bikes_Sales.dbo.Sales
GROUP BY 
    Product_Category, Sub_Category
ORDER BY 
    CASE 
        WHEN Product_Category = 'Accessories' THEN 1
        WHEN Product_Category = 'Bikes' THEN 2
        WHEN Product_Category = 'Clothing' THEN 3
        ELSE 4
    END,
    Product_Category, 
    Sub_Category;

-- This query provides a detailed view of profitability at a more granular level, showing how different sub-categories 
-- contribute to the total profit within each product category. This information is essential for understanding the 
-- performance of specific sub-categories and making informed decisions on inventory and marketing strategies.

-- The final query shows the total profit for each product, grouped by Product_Category and Sub_Category:
SELECT 
    Product_Category,
    Sub_Category,
    Product_Fixed AS Product,
    SUM(CAST(Profit_Fixed AS INT)) AS Profit_Total
FROM 
    Bikes_Sales.dbo.Sales
GROUP BY 
    Product_Category, Sub_Category, Product_Fixed
ORDER BY 
    Product_Category, Sub_Category, Product_Fixed;

-- This query provides the most detailed view of profitability, breaking it down to the individual product level. 
-- It helps in identifying the most and least profitable products, which can be crucial for inventory management, 
-- pricing strategies, and sales promotions.

-- Overall, these queries are important for exploratory data analysis as they provide a comprehensive view of 
-- product profitability across different levels of granularity. This analysis is vital for identifying key drivers of 
-- profit, optimizing product offerings, and informing business strategy.

-- 4. Monthly Sales Trends

SELECT 
    Month,
    Total_Sales
FROM (
    SELECT 
        COALESCE(Month, 'Total') AS Month,
        SUM(CAST(Order_Quantity_Fixed AS INT)) AS Total_Sales,
        CASE 
            WHEN Month IS NULL THEN 1 
            ELSE
                CASE Month 
                    WHEN 'January' THEN 1 
                    WHEN 'February' THEN 2 
                    WHEN 'March' THEN 3 
                    WHEN 'April' THEN 4 
                    WHEN 'May' THEN 5 
                    WHEN 'June' THEN 6 
                    WHEN 'July' THEN 7 
                    WHEN 'August' THEN 8 
                    WHEN 'September' THEN 9 
                    WHEN 'October' THEN 10 
                    WHEN 'November' THEN 11 
                    WHEN 'December' THEN 12 
                END
        END AS Month_Order
    FROM 
        Bikes_Sales.dbo.Sales
    GROUP BY 
        Month
    UNION ALL
    SELECT 
        'Total' AS Month,
        SUM(CAST(Order_Quantity_Fixed AS INT)) AS Total_Sales,
        99 AS Month_Order 
    FROM 
        Bikes_Sales.dbo.Sales
) AS sub
ORDER BY 
    Month_Order;

-- This query provides an overview of sales trends by month, showing both individual monthly totals and an overall total. 
-- By aggregating sales data across different months, it highlights seasonal variations and trends in sales performance. 
-- Understanding these trends is crucial for identifying peak sales periods, planning inventory levels, and optimizing marketing strategies. 
-- This analysis can help in making data-driven decisions to enhance sales and business performance throughout the year.

-- 5. Financial Performance by Country and State

-- The following query displays the total revenue generated in each country, including an overall total:
SELECT 
    COALESCE(Country, 'Total') AS Country,
    SUM(CAST(Revenue_Fixed AS INT)) AS Total_Revenue
FROM 
    Bikes_Sales.dbo.Sales
GROUP BY 
    Country
WITH ROLLUP;

-- This query aggregates the total revenue per state within each country:
SELECT 
    Country,
    State,
    SUM(CAST(Revenue_Fixed AS INT)) AS Total_Revenue
FROM 
    Bikes_Sales.dbo.Sales
GROUP BY 
    Country, State
ORDER BY 
    Country, State;

-- These queries provide insights into financial performance across different geographic regions. By summarizing revenue data 
-- at the country and state levels, businesses can identify key revenue-generating areas and evaluate regional performance. 
-- This information is essential for strategic planning, targeting specific markets, and allocating resources effectively. 
-- Analyzing revenue by country and state helps in understanding market dynamics and making informed decisions to enhance global 
-- and regional sales strategies.
