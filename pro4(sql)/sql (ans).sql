-- task 1:  Identifying the Top Branch by Sales Growth Rate
-- extract monthly sales data 

 
WITH MonthlySales AS (
    -- Convert the 'Date' string to a DATE type and then format it
    SELECT
        DATE_FORMAT(STR_TO_DATE(Date, '%d-%m-%Y'), '%Y-%m') AS SalesMonth,
        Branch,
        SUM(Total) AS MonthlyTotalSales
    FROM walmartsales
    GROUP BY
        SalesMonth,
        Branch
),
LaggedSales AS (
    -- Use the LAG function to get previous month's sales
    SELECT
        SalesMonth,
        Branch,
        MonthlyTotalSales,
        LAG(MonthlyTotalSales, 1, 0) OVER (PARTITION BY Branch ORDER BY SalesMonth) AS PreviousMonthSales
    FROM MonthlySales
),
GrowthRate AS (
    -- Calculate the monthly growth rate
    SELECT
        SalesMonth,
        Branch,
        MonthlyTotalSales,
        PreviousMonthSales,
        CASE
            WHEN PreviousMonthSales > 0 THEN ((MonthlyTotalSales - PreviousMonthSales) * 100.0 / PreviousMonthSales)
            ELSE NULL
        END AS MonthlyGrowthRate
    FROM LaggedSales
)
-- Find the top 3 branches with the highest average growth rate, with rounded values
SELECT
    Branch,
    ROUND(AVG(MonthlyGrowthRate), 2) AS AverageGrowthRate
FROM GrowthRate
WHERE MonthlyGrowthRate IS NOT NULL
GROUP BY
    Branch
ORDER BY
    AverageGrowthRate DESC
LIMIT 3;


-- task 2 : Finding the Most Profitable Product Line for Each Branch

WITH ProductLineProfit AS (
    -- Calculate the total gross income for each product line per branch, rounded to 2 decimal places
    SELECT
        Branch,
        `Product line` AS ProductLine,
        ROUND(SUM(`gross income`), 2) AS TotalGrossIncome
    FROM walmartsales
    GROUP BY
        Branch,
        `Product line`
),
RankedProfit AS (
    -- Rank product lines by their total gross income within each branch
    SELECT
        Branch,
        ProductLine,
        TotalGrossIncome,
        ROW_NUMBER() OVER (PARTITION BY Branch ORDER BY TotalGrossIncome DESC) AS RankNum
    FROM ProductLineProfit
)
-- Select the top-ranked product line for each branch
SELECT
    Branch,
    ProductLine,
    TotalGrossIncome
FROM RankedProfit
WHERE RankNum = 1
ORDER BY
    Branch;


-- task 3 : Analyzing Customer Segmentation Based on Spending 

WITH CustomerSpending AS (
    -- Calculate the total spending for each customer, rounded to 2 decimal places
    SELECT
        `Customer ID`,
        ROUND(SUM(Total), 2) AS TotalSpent
    FROM walmartsales
    GROUP BY
        `Customer ID`
),
CustomerTiers AS (
    -- Assign each customer to a spending tier using NTILE(3)
    SELECT
        `Customer ID`,
        TotalSpent,
        NTILE(3) OVER (ORDER BY TotalSpent) AS SpendingTierRank
    FROM CustomerSpending
)
-- Classify the tiers as High, Medium, and Low, and display the rounded values
SELECT
    `Customer ID`,
    TotalSpent,
    CASE
        WHEN SpendingTierRank = 1 THEN 'Low Spender'
        WHEN SpendingTierRank = 2 THEN 'Medium Spender'
        WHEN SpendingTierRank = 3 THEN 'High Spender'
    END AS SpendingTier
FROM CustomerTiers
ORDER BY
    TotalSpent DESC;

-- task 4 : Detecting Anomalies in Sales Transactions

WITH ProductLineStats AS (
    -- Calculate the average and standard deviation of sales for each product line
    SELECT
        `Product line` AS ProductLine,
        AVG(Total) AS AverageSales,
        STDDEV(Total) AS StdDevSales
    FROM walmartsales
    GROUP BY
        `Product line`
)
-- Identify transactions that are outside of two standard deviations from the product line's average
SELECT
    t.`Invoice ID`,
    t.`Product line` AS ProductLine,
    t.Total,
    s.AverageSales,
    s.StdDevSales
FROM walmartsales AS t
JOIN ProductLineStats AS s
    ON t.`Product line` = s.ProductLine
WHERE
    t.Total > (s.AverageSales + (2 * s.StdDevSales)) OR
    t.Total < (s.AverageSales - (2 * s.StdDevSales))
ORDER BY
    t.`Product line`,
    t.Total DESC;
    
SELECT
    `Invoice ID`,
    `Product line`,
    Total,
    
    -- Calculate average sales for the same product line
    (SELECT AVG(Total)
     FROM walmartsales AS sub
     WHERE sub.`Product line` = main.`Product line`) AS Avg_sale,
     
    -- Classify anomaly status
    CASE
        WHEN Total > 1.5 * (
            SELECT AVG(Total)
            FROM walmartsales AS sub
            WHERE sub.`Product line` = main.`Product line`
        ) THEN 'High Anomaly'
        
        WHEN Total < 0.5 * (
            SELECT AVG(Total)
            FROM walmartsales AS sub
            WHERE sub.`Product line` = main.`Product line`
        ) THEN 'Low Anomaly'
        
        ELSE 'Normal'
    END AS Anomaly_Status

FROM
    walmartsales AS main;


-- task 5 : Most Popular Payment Method by City 

select *  from walmartsales; 

WITH PaymentMethodCounts AS (
    -- Count the number of transactions for each payment method in each city
    SELECT
        City,
        Payment,
        COUNT(`Invoice ID`) AS TransactionCount
    FROM walmartsales
    GROUP BY
        City,
        Payment
),
RankedPayments AS (
    -- Rank payment methods by transaction count within each city
    SELECT
        City,
        Payment,
        TransactionCount,
        ROW_NUMBER() OVER (PARTITION BY City ORDER BY TransactionCount DESC) AS RankNum
    FROM PaymentMethodCounts
)
-- Select the top-ranked payment method for each city
SELECT
    City,
    Payment AS MostPopularPaymentMethod,
    TransactionCount
FROM RankedPayments
WHERE
    RankNum = 1
ORDER BY
    City;

-- task 6 : Monthly Sales Distribution by Gender.

WITH MonthlySales AS (
    -- Convert the 'Date' string to a DATE type and then format it to get the year and month
    SELECT
        DATE_FORMAT(STR_TO_DATE(Date, '%d-%m-%Y'), '%Y-%m') AS SalesMonth,
        Gender,
        -- Calculate the total sales for each gender in each month, rounded to 2 decimal places
        ROUND(SUM(Total), 2) AS TotalSales
    FROM
        walmartsales
    GROUP BY
        SalesMonth,
        Gender
)
SELECT
    SalesMonth,
    Gender,
    TotalSales,
    -- Calculate the percentage of sales for each gender within the month
    ROUND(TotalSales * 100.0 / SUM(TotalSales) OVER (PARTITION BY SalesMonth), 2) AS SalesPercentage
FROM
    MonthlySales
ORDER BY
    SalesMonth,
    Gender;
    
-- task 7 : Best Product Line by Customer Type.

WITH ProductLineSales AS (
    -- Calculate the total sales for each product line per customer type
    SELECT
        `Customer type` AS CustomerType,
        `Product line` AS ProductLine,
        ROUND(SUM(Total), 2) AS TotalSales
    FROM walmartsales
    GROUP BY
        `Customer type`,
        `Product line`
),
RankedSales AS (
    -- Rank product lines by their total sales within each customer type
    SELECT
        CustomerType,
        ProductLine,
        TotalSales,
        ROW_NUMBER() OVER (PARTITION BY CustomerType ORDER BY TotalSales DESC) AS RankNum
    FROM ProductLineSales
)
-- Select the top-ranked product line for each customer type
SELECT
    CustomerType,
    ProductLine,
    TotalSales
FROM RankedSales
WHERE
    RankNum = 1
ORDER BY
    CustomerType;


-- task 8:  Identifying Repeat Customers

WITH CustomerPurchaseDates AS (
    -- Convert the 'Date' string to a DATE type and order by date for each customer
    SELECT
        `Customer ID`,
        STR_TO_DATE(Date, '%d-%m-%Y') AS PurchaseDate
    FROM walmartsales
    ORDER BY
        `Customer ID`,
        PurchaseDate
),
NextPurchaseDates AS (
    -- Find the date of the next purchase for each customer
    SELECT
        `Customer ID`,
        PurchaseDate,
        LEAD(PurchaseDate, 1) OVER (PARTITION BY `Customer ID` ORDER BY PurchaseDate) AS NextPurchaseDate
    FROM CustomerPurchaseDates
)
-- Identify repeat customers who made a purchase within 30 days of their previous one
SELECT
    `Customer ID`,
    PurchaseDate,
    NextPurchaseDate,
    DATEDIFF(NextPurchaseDate, PurchaseDate) AS DaysBetweenPurchases
FROM NextPurchaseDates
WHERE
    DATEDIFF(NextPurchaseDate, PurchaseDate) IS NOT NULL
    AND DATEDIFF(NextPurchaseDate, PurchaseDate) <= 30
ORDER BY
    `Customer ID`,
    PurchaseDate;
    
-- here it show the unique values 

 WITH CustomerPurchaseDates AS (
    -- Convert the 'Date' string to a DATE type and order by date for each customer
    SELECT
        `Customer ID`,
        STR_TO_DATE(Date, '%d-%m-%Y') AS PurchaseDate
    FROM walmartsales
    ORDER BY
        `Customer ID`,
        PurchaseDate
),
NextPurchaseDates AS (
    -- Find the date of the next purchase for each customer
    SELECT
        `Customer ID`,
        PurchaseDate,
        LEAD(PurchaseDate, 1) OVER (PARTITION BY `Customer ID` ORDER BY PurchaseDate) AS NextPurchaseDate
    FROM CustomerPurchaseDates
)
-- Identify unique customers who made a repeat purchase within 30 days
SELECT DISTINCT
    `Customer ID`
FROM NextPurchaseDates
WHERE
    DATEDIFF(NextPurchaseDate, PurchaseDate) IS NOT NULL
    AND DATEDIFF(NextPurchaseDate, PurchaseDate) <= 30
ORDER BY
    `Customer ID`;


-- task 9 :  Finding Top 5 Customers by Sales Volume 

SELECT
    `Customer ID`,
    -- Calculate the sum of all purchases for each customer, rounded to 2 decimal places
    ROUND(SUM(Total), 2) AS TotalSalesRevenue
FROM
    walmartsales
GROUP BY
    `Customer ID`
ORDER BY
    TotalSalesRevenue DESC
LIMIT 5;

-- task 10 :  Analyzing Sales Trends by Day of the Week 

SELECT
    -- Extract the day of the week name from the 'Date' column
    DAYNAME(STR_TO_DATE(Date, '%d-%m-%Y')) AS DayOfWeek,
    -- Calculate the total sales for each day, rounded to 2 decimal places
    ROUND(SUM(Total), 2) AS TotalSales
FROM
    walmartsales
GROUP BY
    DayOfWeek
ORDER BY
    TotalSales DESC;
    
SELECT
    DAYNAME(STR_TO_DATE(Date, '%d-%m-%Y')) AS Day_Of_Week,
    ROUND(SUM(Total), 2) AS Total_Sales
FROM
    walmartsales
GROUP BY
    Day_Of_Week
ORDER BY
    Total_Sales DESC
LIMIT 1;
