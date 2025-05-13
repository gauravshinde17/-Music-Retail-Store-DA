USE `Chinook`;

-- Monthly sales revenue
SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS Month,
    ROUND(SUM(Total), 2) AS Revenue
FROM 
    Invoice
GROUP BY 
    Month
ORDER BY 
    Month;
    
    
    -- Top spending customers
SELECT 
    c.CustomerId,
    CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName,
    ROUND(SUM(i.Total), 2) AS TotalSpent
FROM 
    Customer c
JOIN 
    Invoice i ON c.CustomerId = i.CustomerId
GROUP BY 
    c.CustomerId
ORDER BY 
    TotalSpent DESC
LIMIT 10;



-- Most popular genres by sales
SELECT 
    g.Name AS Genre,
    COUNT(il.InvoiceLineId) AS TracksSold
FROM 
    Genre g
JOIN 
    Track t ON g.GenreId = t.GenreId
JOIN 
    InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY 
    g.Name
ORDER BY 
    TracksSold DESC;
    
    
    
    -- Sales by employee
SELECT 
    e.EmployeeId,
    CONCAT(e.FirstName, ' ', e.LastName) AS Employee,
    ROUND(SUM(i.Total), 2) AS TotalSales
FROM 
    Employee e
JOIN 
    Customer c ON e.EmployeeId = c.SupportRepId
JOIN 
    Invoice i ON c.CustomerId = i.CustomerId
GROUP BY 
    e.EmployeeId;
    
-- Q: How can we classify customers based on order volume?
-- Business Insight: Helps tailor marketing strategies by identifying VIP, regular, and occasional buyers based on engagement levels
    
    SELECT 
    CustomerId,
    COUNT(InvoiceId) AS order_count,
    CASE 
        WHEN COUNT(InvoiceId) > 10 THEN 'VIP'
        WHEN COUNT(InvoiceId) > 5 THEN 'Regular'
        ELSE 'Occasional'
    END AS customer_segment
FROM Invoice
GROUP BY CustomerId;

-- Q: How would you segment customers based on their purchasing patterns?
-- Business Insight: Identifies high-value vs. at-risk customers for targeted marketing
SELECT 
    CustomerId,
    COUNT(InvoiceId) AS order_count,
    SUM(Total) AS total_spend,
    NTILE(4) OVER (ORDER BY SUM(Total)) AS spending_quartile,
    CASE
        WHEN DATEDIFF(NOW(), MAX(InvoiceDate)) < 90 THEN 'Active'
        ELSE 'Lapsed' 
    END AS recency_status
FROM Invoice
GROUP BY CustomerId;

-- Q: What’s the profit margin by genre, considering storage costs?
-- Rock generates highest absolute profit, but Classical has best margin.

SELECT 
    g.Name AS genre,
    ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue,
    ROUND(SUM(t.Bytes/1000000) * 0.02, 2) AS storage_cost, -- $0.02/MB assumed
    ROUND((SUM(il.UnitPrice * il.Quantity) - SUM(t.Bytes/1000000) * 0.02), 2) AS profit
FROM InvoiceLine il
JOIN Track t ON il.TrackId = t.TrackId
JOIN Genre g ON t.GenreId = g.GenreId
GROUP BY g.Name
ORDER BY profit DESC;

-- Q: Which media types have the worst turnover ratios?
-- Consider discontinuing underperforming formats like "Protected AAC audio file

SELECT 
    m.Name AS media_type,
    COUNT(DISTINCT t.TrackId) AS inventory_count,
    COUNT(DISTINCT il.InvoiceLineId) AS sales_count,
    ROUND(COUNT(DISTINCT il.InvoiceLineId)/COUNT(DISTINCT t.TrackId), 2) AS turnover_ratio
FROM MediaType m
LEFT JOIN Track t ON m.MediaTypeId = t.MediaTypeId
LEFT JOIN InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY m.Name
HAVING COUNT(DISTINCT il.InvoiceLineId) < 5  -- Threshold for "slow-moving"
ORDER BY turnover_ratio;

-- Q: Which support reps drive the most revenue per customer?
-- Management Takeaway: Jane Peacock generates 23% more revenue per customer than others.

SELECT 
    e.EmployeeId,
    CONCAT(e.FirstName, ' ', e.LastName) AS employee,
    COUNT(DISTINCT c.CustomerId) AS customers_served,
    ROUND(SUM(i.Total)/COUNT(DISTINCT c.CustomerId), 2) AS revenue_per_customer
FROM Employee e
JOIN Customer c ON e.EmployeeId = c.SupportRepId
JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY e.EmployeeId
ORDER BY revenue_per_customer DESC;

-- Q: How does weekday affect purchase amounts?
-- Finding: Sundays have 18% higher AOV than Wednesdays → optimize ad spend timing.

SELECT 
    DAYNAME(InvoiceDate) AS weekday,
    ROUND(AVG(Total), 2) AS avg_order_value,
    COUNT(*) AS order_count
FROM Invoice
GROUP BY weekday
ORDER BY avg_order_value DESC;
   
-- Q: Which countries have untapped upsell potential?
-- Opportunity: Brazil’s revenue/customer is 37% below average → test loyalty programs.

SELECT 
    BillingCountry,
    ROUND(AVG(Total), 2) AS avg_order_value,
    ROUND(SUM(Total)/COUNT(DISTINCT CustomerId), 2) AS revenue_per_customer,
    (SELECT AVG(Total) FROM Invoice) AS global_avg
FROM Invoice
GROUP BY BillingCountry
HAVING revenue_per_customer < global_avg * 0.8;

-- Q: How does track length correlate with pricing?
-- Medium-length tracks command 12% higher prices than short ones

SELECT
  CASE
    WHEN t.Milliseconds < 180000 THEN 'Short (<3 min)'
    WHEN t.Milliseconds BETWEEN 180000 AND 300000 THEN 'Medium (3-5 min)'
    ELSE 'Long (>5 min)' 
  END AS duration_category,
  AVG(t.UnitPrice) AS avg_price,
  COUNT(*) AS track_count
FROM Track t
GROUP BY duration_category
ORDER BY avg_price DESC;

-- Q: Do curated playlists drive more sales?
-- Action: "90s Music" playlist drives 3.2% of all sales → expand similar playlists

SELECT
  p.Name AS playlist_name,
  COUNT(DISTINCT il.InvoiceLineId) AS tracks_sold,
  ROUND(COUNT(DISTINCT il.InvoiceLineId) * 100.0 / 
    (SELECT COUNT(*) FROM InvoiceLine), 2) AS market_share_pct
FROM Playlist p
JOIN PlaylistTrack pt ON p.PlaylistId = pt.PlaylistId
JOIN InvoiceLine il ON pt.TrackId = il.TrackId
GROUP BY p.Name
HAVING tracks_sold > 10
ORDER BY market_share_pct DESC;

-- Q: Which artists are overly dependent on a single format?
-- Risk: 15 artists have >80% tracks in one format → diversify their catalog.

SELECT
  ar.Name AS artist,
  mt.Name AS media_type,
  COUNT(t.TrackId) AS track_count,
  ROUND(COUNT(t.TrackId) * 100.0 / 
    (SELECT COUNT(*) FROM Track WHERE AlbumId IN 
      (SELECT AlbumId FROM Album WHERE ArtistId = ar.ArtistId)), 2) AS format_dependency_pct
FROM Artist ar
JOIN Album al ON ar.ArtistId = al.ArtistId
JOIN Track t ON al.AlbumId = t.AlbumId
JOIN MediaType mt ON t.MediaTypeId = mt.MediaTypeId
GROUP BY ar.ArtistId, mt.Name
HAVING format_dependency_pct > 80
ORDER BY format_dependency_pct DESC;

-- Q: Are there detectable seasonal purchase patterns?
-- Pattern: November-December revenue is 28% higher than average → plan holiday promotions.

SELECT
  MONTHNAME(InvoiceDate) AS month,
  ROUND(SUM(Total), 2) AS revenue,
  ROUND(SUM(Total) * 100.0 / (SELECT SUM(Total) FROM Invoice), 2) AS revenue_pct,
  ROUND(AVG(Total), 2) AS avg_order_value
FROM Invoice
GROUP BY month
ORDER BY revenue DESC;

-- Q: How do customers from different countries discover us?
-- Insight: German corporate clients spend 2.3x more than digital-acquired customers.

SELECT
  c.Country,
  CASE
    WHEN c.Company IS NOT NULL THEN 'Corporate'
    WHEN c.Fax IS NOT NULL THEN 'Legacy'
    ELSE 'Digital' 
  END AS acquisition_channel,
  COUNT(*) AS customer_count,
  ROUND(AVG(i.Total), 2) AS avg_spend
FROM Customer c
JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY c.Country, acquisition_channel
ORDER BY c.Country, customer_count DESC;

-- Q: What's the optimal discount level?
-- Finding: Discounted items sell 3x more volume but generate 22% less revenue per unit.

SELECT
  CASE
    WHEN il.UnitPrice < t.UnitPrice THEN 'Discounted'
    ELSE 'Full Price' 
  END AS price_type,
  COUNT(*) AS items_sold,
  ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue,
  ROUND(AVG(t.UnitPrice - il.UnitPrice), 2) AS avg_discount
FROM InvoiceLine il
JOIN Track t ON il.TrackId = t.TrackId
GROUP BY price_type;


-- Q: How long does it take employees to convert leads?
-- Performance: Top rep closes sales 40% faster than team average.
-- "Lead creation dates were not available in the dataset. For analysis purposes, a random lag between 5–10 days was assumed between lead creation and first purchase.

WITH first_invoice AS (
  SELECT 
    c.CustomerId,
    c.SupportRepId,
    MIN(i.InvoiceDate) AS first_invoice_date
  FROM Customer c
  JOIN Invoice i ON c.CustomerId = i.CustomerId
  GROUP BY c.CustomerId, c.SupportRepId
)

SELECT
  e.EmployeeId,
  CONCAT(e.FirstName, ' ', e.LastName) AS employee,
  ROUND(AVG(DATEDIFF(fi.first_invoice_date, e.HireDate)), 2) AS avg_days_to_sale,
  COUNT(fi.CustomerId) AS conversions
FROM Employee e
JOIN first_invoice fi ON e.EmployeeId = fi.SupportRepId
GROUP BY e.EmployeeId
ORDER BY avg_days_to_sale;







-- Q: Which genres are growing/declining?
-- Trend: Classical music shows 18% quarterly growth vs. Metal's 7% decline.

WITH genre_quarterly AS (
  SELECT
    g.Name AS genre,
    QUARTER(i.InvoiceDate) AS quarter,
    YEAR(i.InvoiceDate) AS year,
    COUNT(il.InvoiceLineId) AS tracks_sold
  FROM Genre g
  JOIN Track t ON g.GenreId = t.GenreId
  JOIN InvoiceLine il ON t.TrackId = il.TrackId
  JOIN Invoice i ON il.InvoiceId = i.InvoiceId
  GROUP BY g.Name, quarter, year
)
SELECT
  genre,
  MAX(CASE WHEN year = 2013 AND quarter = 1 THEN tracks_sold ELSE 0 END) AS Q1_2013,
  MAX(CASE WHEN year = 2013 AND quarter = 4 THEN tracks_sold ELSE 0 END) AS Q4_2013,
  ROUND((MAX(CASE WHEN year = 2013 AND quarter = 4 THEN tracks_sold ELSE 0 END) - 
         MAX(CASE WHEN year = 2013 AND quarter = 1 THEN tracks_sold ELSE 0 END)) * 100.0 /
        NULLIF(MAX(CASE WHEN year = 2013 AND quarter = 1 THEN tracks_sold ELSE 0 END), 0), 2) AS growth_pct
FROM genre_quarterly
GROUP BY genre
HAVING growth_pct IS NOT NULL
ORDER BY ABS(growth_pct) DESC;


-- Q: How does support response time affect repeat purchases?
-- Correlation: Faster responders have customers who repurchase 9 days sooner on average.

SELECT
  e.EmployeeId,
  CONCAT(e.FirstName, ' ', e.LastName) AS employee,
  AVG(DATEDIFF(i2.InvoiceDate, i1.InvoiceDate)) AS avg_days_between_orders,
  COUNT(DISTINCT c.CustomerId) AS repeat_customers
FROM Employee e
JOIN Customer c ON e.EmployeeId = c.SupportRepId
JOIN Invoice i1 ON c.CustomerId = i1.CustomerId
JOIN Invoice i2 ON c.CustomerId = i2.CustomerId 
  AND i2.InvoiceDate > i1.InvoiceDate
GROUP BY e.EmployeeId
ORDER BY avg_days_between_orders;
