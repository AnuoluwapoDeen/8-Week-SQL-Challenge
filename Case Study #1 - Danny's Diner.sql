CREATE TABLE Sales (
  CustomerID VARCHAR(5),
  Order_Date DATE,
  ProductID INT
  );


CREATE TABLE Members (
  CustomerID VARCHAR (5),
  Join_Date date
  );

  CREATE TABLE Menu (
  ProductID VARCHAR (5),
  Product_Name VARCHAR (5),
  Price INT
  );


   INSERT INTO Menu (productID, Product_Name, Price) VALUES
  (1, 'Sushi', 10),
  (2, 'Curry', 15),
  (3, 'Ramen', 12);


  INSERT INTO Members (CustomerID, Join_Date) VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');


  INSERT INTO Sales (CustomerID, Order_Date, ProductID) VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');

  SELECT * FROM Menu;

  SELECT * FROM Members;

  SELECT * FROM Sales;

  -- CASE STUDY QUESTIONS --

  -- 1. What is the total amount each customer spent at the restaurant?

  SELECT Sales.customerID, SUM(price) AS total_sales
FROM Sales
JOIN Menu
  ON Sales.productID = Menu.productID
GROUP BY customerID;

-- 2. How many days has each customer visited the restaurant?

SELECT customerID, COUNT(DISTINCT(order_date)) AS visit_count
FROM Sales
GROUP BY customerID;


--  3. What was the first item from the menu purchased by each customer?

WITH ordered_sales_cte AS (
  SELECT customerID, order_date, product_name,
    DENSE_RANK() OVER (PARTITION BY Sales.customerID ORDER BY Sales.order_date) AS RANK
  FROM Sales
  JOIN Menu ON Sales.ProductID = Menu.ProductID
)
SELECT customerID, product_name
FROM ordered_sales_cte
WHERE RANK = 1
GROUP BY customerID, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT 
  TOP 1 (COUNT(s.ProductID)) AS most_purchased, 
  product_name
FROM dbo.sales AS s
JOIN dbo.menu AS m
  ON s.ProductID = m.ProductID
GROUP BY s.ProductID, product_name
ORDER BY most_purchased DESC;

-- 5. Which item was the most popular for each customer?

SELECT customerID, product_name, order_date
FROM (
  SELECT Sales.customerID, Menu.product_name, Sales.order_date,
    ROW_NUMBER() OVER (PARTITION BY Sales.customerID ORDER BY Sales.order_date) AS rn
  FROM Sales
  JOIN Menu ON Sales.ProductID = Menu.ProductID
  JOIN Members ON Sales.customerID = Members.customerID
  WHERE Sales.order_date >= Members.join_date
) AS subquery
WHERE rn = 1;


--6. Which item was purchased first by the customer after they became a member?

SELECT Members.customerID, Menu.product_name, MIN(Sales.order_date) AS first_purchase_date
FROM Members
JOIN Sales ON Members.customerID = Sales.customerID
JOIN Menu ON Sales.ProductID = Menu.ProductID
WHERE Sales.order_date >= Members.join_date
GROUP BY Members.customerID, Menu.product_name;


--7. Which item was purchased just before the customer became a member?

WITH before_member_purchased_cte AS 
(SELECT 
    s.CustomerID, 
    m.join_date, 
    s.order_date, 
    s.ProductID,
    DENSE_RANK() OVER(PARTITION BY s.customerID ORDER BY s.order_date DESC)  AS rank
  FROM sales AS s
	JOIN members AS m
		ON s.CustomerID = m.CustomerID
	WHERE s.order_date < m.join_date
)

SELECT 
  s.CustomerID, 
  s.order_date, 
  m2.product_name 
FROM before_member_purchased_cte AS s
JOIN menu AS m2
	ON s.ProductID = m2.ProductID
WHERE rank = 1;

--8. What is the total items and amount spent for each member before they became a member?


SELECT 
  s.CustomerID, 
  COUNT(DISTINCT s.ProductID) AS distinct_menu_item, 
  SUM(mm.price) AS total_sales
FROM sales AS s
JOIN members AS m
	ON s.CustomerID = m.CustomerID
JOIN menu AS mm
	ON s.ProductID = mm.ProductID
WHERE s.order_date < m.join_date
GROUP BY s.CustomerID;


--9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH price_points_cte AS
(
	SELECT *, 
		CASE WHEN product_name = 'Sushi' THEN price * 20
		ELSE price * 10 END AS points
	FROM menu
)

SELECT 
  s.CustomerID, 
  SUM(p.points) AS total_points
FROM price_points_cte AS p
JOIN sales AS s
	ON p.ProductID = s.ProductID
GROUP BY s.CustomerID;

--10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
-- 1. Find member validity date of each customer and get last date of January
-- 2. Use CASE WHEN to allocate points by date and product id
-- 3. SUM price and points

WITH dates_cte AS 
(SELECT 
    *, 
    DATEADD(DAY, 6, join_date) AS valid_date, 
		EOMONTH('2021-01-31') AS last_date
	FROM members AS m
)

SELECT 
  d.CustomerID, 
  s.order_date, 
  d.join_date, 
  d.valid_date, 
  d.last_date, 
  m.product_name, 
  m.price,
	SUM( 
    CASE WHEN m.product_name = 'Sushi' THEN 2 * 10 * m.price
		WHEN s.order_date BETWEEN d.join_date AND d.valid_date THEN 2 * 10 * m.price
		ELSE 10 * m.price END) AS points
FROM dates_cte AS d
JOIN sales AS s
	ON d.CustomerID = s.CustomerID
JOIN menu AS m
	ON s.ProductID = m.ProductID
WHERE s.order_date < d.last_date
GROUP BY d.CustomerID, s.order_date, d.join_date, d.valid_date, d.last_date, m.product_name, m.price;


--------------------
--BONUS QUESTIONS--
--------------------

-- Join All The Things
-- Recreate the table with: customer_id, order_date, product_name, price, member (Y/N)

SELECT 
  s.CustomerID, 
  s.order_date, 
  m.product_name, 
  m.price,
  CASE WHEN mm.join_date > s.order_date THEN 'N'
	  WHEN mm.join_date <= s.order_date THEN 'Y'
	  ELSE 'N' END AS member
FROM sales AS s
LEFT JOIN menu AS m
	ON s.ProductID = m.ProductID
LEFT JOIN members AS mm
	ON s.CustomerID = mm.CustomerID
ORDER BY s.CustomerID, s.order_date;


-- Rank All The Things
-- Recreate the table with: customer_id, order_date, product_name, price, member (Y/N), ranking(null/123)

WITH summary_cte AS 
(SELECT 
    s.CustomerID, 
    s.order_date, 
    m.product_name, 
    m.price,
    CASE WHEN mm.join_date > s.order_date THEN 'N'
	    WHEN mm.join_date <= s.order_date THEN 'Y'
	    ELSE 'N'END AS member
FROM sales AS s
LEFT JOIN menu AS m
	ON s.ProductID = m.ProductID
LEFT JOIN members AS mm
	ON s.ProductID = mm.CustomerID
)

SELECT 
*,
	CASE WHEN member = 'N' then NULL
    ELSE
			RANK () OVER(PARTITION BY customerID, member ORDER BY order_date) 
		END AS ranking
FROM summary_cte;