select*
from superstore

--#1 What percentage of total orders were shipped on the same date?
select count(*) as totalOrders,
sum(case when ship_date = order_date then 1 else 0 end) as shipedSameOrder,
cast(sum(case when ship_date = order_date then 1 else 0 end)as decimal(10,2))/ count(*) * 100 as pct
from superstore

--#2. Name top 3 customers with highest total quantities of orders.
select top 3 customer_name,count(*) as totalOrders
from superstore
group by customer_name
order by totalOrders desc

--#3. Find the top 5 items with the highest average sales.
select top 5 product_name,cast(avg(sales)as decimal(10,2)) as avg_sales
from superstore
group by product_name
order by avg_sales desc

--#4. Write a query to find the average order value for each customer, and rank the customers by their average order value.
with customer_rank as(
select customer_name,cast(avg(sales)as decimal(10,2)) as avg_sales
from superstore
group by customer_name
)
select customer_name, avg_sales,
rank() over(order by avg_sales desc) as rank
from customer_rank

--#5. Give the name of customers who ordered highest and lowest orders from each city.
with cusotmer_orders as (
select city,
customer_name,
count(order_id) as num_orders
from superstore
group by city, customer_name
),
rank_data as(
select city,
min(num_orders) as lowest_orders,
max(num_orders) as highest_orders
from cusotmer_orders
group by city
)
select c.city,
string_agg(case when num_orders = lowest_orders then customer_name else null end,',') as lowest_order_customers,
string_agg(case when num_orders = highest_orders then customer_name else null end,',') as highest_order_customers
from cusotmer_orders as c
join rank_data as r
on c.city = r.city
WHERE num_orders = lowest_orders OR num_orders = highest_orders
group by c.city

--#6. What is the most demanded sub-category in the west region?
select top 1 sub_category,sum(quantity) as total_orders
from superstore
where region = 'West'
group by sub_category
order by total_orders desc

--#7. Which order has the highest number of items? 
select top 1 order_id ,count(*) as total_quantity
from superstore
group by order_id 
order by total_quantity desc

--#8. Which order has the highest cumulative value?
--answer 1 
select top 1 order_id, sum(sales) as total_sales
from superstore
group by order_id
order by total_sales desc

--answer 2
with cte as(select order_id, sum(sales) as total_sales,
rank() over(order by sum(sales) desc) as rnk
from superstore
group by order_id
)
select order_id,total_sales,rnk
from cte
where rnk = 1

--#9. Which segment’s order is more likely to be shipped via first class?
select top 1 segment,count(*) as total_numbers
from superstore
where ship_mode = 'First Class'
group by segment
order by total_numbers desc

--#10. Which city is least contributing to total revenue?
select top 1 city ,round(sum(sales),2) total_revenue
from superstore
group by city
order by total_revenue 

--#11. What is the average time for orders to get shipped after order is placed?
select avg(DATEDIFF(day,order_date,ship_date)) as avg_time
from superstore

--#12. Which segment places the highest number of orders from each state and which segment places the largest individual orders from each state?

select segment,state,total_orders
from(select segment ,state,count(*) as total_orders,
ROW_NUMBER() over(partition by state order by count(*) desc) as rn
from superstore
group by segment,state
)t
where rn = 1
order by total_orders desc

-------------------------------------------------------------------

select segment,state,total_sales
from(select segment ,state,round(sum(sales),2) as total_sales,
ROW_NUMBER() over(partition by state order by sum(sales) desc) as rn
from superstore
group by segment,state
)t
where rn = 1
order by total_sales desc

--#13. Find all the customers who individually ordered on 3 consecutive days where each day’s total order was more than 50 in value. **
WITH daily_sales AS (
    SELECT 
        customer_id,
        customer_name,
        order_date,
        SUM(sales) AS total_sales
    FROM superstore
    GROUP BY customer_id, customer_name, order_date
    HAVING SUM(sales) > 50
),
cte AS (
    SELECT *,
           DATEADD(day, -ROW_NUMBER() OVER 
               (PARTITION BY customer_id ORDER BY order_date), 
               order_date) AS grp
    FROM daily_sales
)
SELECT customer_id, customer_name,grp
FROM cte
GROUP BY customer_id, customer_name, grp
HAVING COUNT(*) >= 3;


--#14. Find the maximum number of days for which total sales on each day kept rising.

with daily_sales as(select order_date,sum(sales) as total_sales
from superstore
group by order_date
),
compar_days as(
select * ,lag(total_sales) over(order by order_date)as prev_sales
from daily_sales
),
breaks as (select *,
case when total_sales > prev_sales then 1 else 0 end as break_flag
from compar_days
),
groups as (
select *,sum(break_flag) over (order by order_date) as grp
from breaks
)
select max(cnt) as max_rising_days
from(
select grp,count(*)as cnt
from groups
where total_sales > prev_sales
group by grp
) t;


with daily_sales as(select order_date,sum(sales) as total_sales
from superstore
group by order_date
),
compar_days as(
select * ,lag(total_sales) over(order by order_date)as prev_sales
from daily_sales
),
increasing_only as(
select * ,
       ROW_NUMBER() over(order by order_date) as rn1,
	   ROW_NUMBER() over(partition by
	                     case when total_sales > prev_sales then 1 else 0 end
						 order by order_date) as rn2
from compar_days
where total_sales > prev_sales
)
select max(cnt) as max_rising_days
from(
     select (rn1 - rn2) as grp,count(*) as cnt
	 from increasing_only
	 group by (rn1-rn2)
) t;

--15# calculate the percentage of customers by city
with cte as (select city,count(*) num_customers
from superstore
group by city)
select*,sum(num_customers) over() as total_cus,
round(cast(num_customers as decimal(10,2))/sum(num_customers) over()*100,2) as pct
from cte
