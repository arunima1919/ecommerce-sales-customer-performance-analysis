-- 1. Top sellers by revenue

SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM order_items oi
GROUP BY oi.seller_id
ORDER BY total_revenue DESC
LIMIT 20;


-- 2. Top sellers by number of orders

SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM order_items oi
GROUP BY oi.seller_id
ORDER BY total_orders DESC
LIMIT 20;


-- 3. Seller performance summary

SELECT
    COUNT(DISTINCT seller_id) AS active_sellers,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(price), 2) AS total_revenue,
    ROUND(AVG(price), 2) AS average_item_price
FROM order_items;


-- 4. Seller revenue concentration

WITH seller_revenue AS (
    SELECT
        seller_id,
        SUM(price) AS revenue
    FROM order_items
    GROUP BY seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        revenue,
        SUM(revenue) OVER (
            ORDER BY revenue DESC
        ) AS cumulative_revenue,
        SUM(revenue) OVER () AS total_revenue
    FROM seller_revenue
)
SELECT
    seller_id,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * cumulative_revenue / total_revenue,
        2
    ) AS cumulative_revenue_percentage
FROM ranked_sellers
ORDER BY revenue DESC
LIMIT 20;


-- 5. Seller order distribution

WITH seller_orders AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM order_items
    GROUP BY seller_id
),
seller_ranges AS (
    SELECT
        seller_id,
        order_count,
        CASE
            WHEN order_count = 1
                THEN '1 order'
            WHEN order_count BETWEEN 2 AND 10
                THEN '2-10 orders'
            WHEN order_count BETWEEN 11 AND 50
                THEN '11-50 orders'
            WHEN order_count BETWEEN 51 AND 100
                THEN '51-100 orders'
            ELSE '100+ orders'
        END AS seller_order_range
    FROM seller_orders
)
SELECT
    seller_order_range,
    COUNT(*) AS seller_count
FROM seller_ranges
GROUP BY seller_order_range
ORDER BY
    CASE seller_order_range
        WHEN '1 order' THEN 1
        WHEN '2-10 orders' THEN 2
        WHEN '11-50 orders' THEN 3
        WHEN '51-100 orders' THEN 4
        WHEN '100+ orders' THEN 5
    END;