-- 1. Orders by customer state

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(
        100.0 * COUNT(DISTINCT o.order_id)
        / SUM(COUNT(DISTINCT o.order_id)) OVER (),
        2
    ) AS order_percentage
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_state
ORDER BY order_count DESC;


-- 2. Unique customers by state

SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM customers c
GROUP BY c.customer_state
ORDER BY unique_customers DESC;


-- 3. Product revenue by customer state

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(
        100.0 * SUM(oi.price)
        / SUM(SUM(oi.price)) OVER (),
        2
    ) AS revenue_percentage
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY product_revenue DESC;


-- 4. Average order value by state

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(
        SUM(oi.price)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY average_order_value DESC;


-- 5. Revenue per unique customer by state

WITH state_revenue AS (
    SELECT
        c.customer_state,
        SUM(oi.price) AS revenue
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_state
),
state_customers AS (
    SELECT
        customer_state,
        COUNT(DISTINCT customer_unique_id)
            AS unique_customers
    FROM customers
    GROUP BY customer_state
)
SELECT
    r.customer_state,
    unique_customers,
    ROUND(r.revenue, 2) AS revenue,
    ROUND(
        r.revenue / unique_customers,
        2
    ) AS revenue_per_customer
FROM state_revenue r
JOIN state_customers c
    ON r.customer_state = c.customer_state
ORDER BY revenue_per_customer DESC;


-- 6. Top states by combined customer and revenue contribution

SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id)
        AS unique_customers,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(
        SUM(oi.price)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY product_revenue DESC
LIMIT 10;


-- 7. Repeat-customer rate by state

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_unique_id,
        c.customer_state
)
SELECT
    customer_state,
    COUNT(*) AS unique_customers,
    COUNT(*) FILTER (
        WHERE order_count > 1
    ) AS repeat_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_count > 1
        ) / COUNT(*),
        2
    ) AS repeat_customer_rate
FROM customer_orders
GROUP BY customer_state
ORDER BY repeat_customer_rate DESC;


-- 8. Repeat-customer rate by state
-- Only states with at least 500 unique customers

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_unique_id,
        c.customer_state
)
SELECT
    customer_state,
    COUNT(*) AS unique_customers,
    COUNT(*) FILTER (
        WHERE order_count > 1
    ) AS repeat_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_count > 1
        ) / COUNT(*),
        2
    ) AS repeat_customer_rate
FROM customer_orders
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY repeat_customer_rate DESC;


-- 9. Average review score by state

SELECT
    c.customer_state,
    COUNT(*) AS review_count,
    ROUND(AVG(r.review_score), 2)
        AS average_review_score
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN reviews r
    ON o.order_id = r.order_id
GROUP BY c.customer_state
ORDER BY average_review_score DESC;


-- 10. Review score + repeat rate together

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_unique_id,
        c.customer_state
),
repeat_rate AS (
    SELECT
        customer_state,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE order_count > 1
            ) / COUNT(*),
            2
        ) AS repeat_customer_rate
    FROM customer_orders
    GROUP BY customer_state
),
reviews_by_state AS (
    SELECT
        c.customer_state,
        COUNT(*) AS review_count,
        ROUND(AVG(r.review_score), 2)
            AS average_review_score
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN reviews r
        ON o.order_id = r.order_id
    GROUP BY c.customer_state
)
SELECT
    r.customer_state,
    r.repeat_customer_rate,
    v.average_review_score,
    v.review_count
FROM repeat_rate r
JOIN reviews_by_state v
    ON r.customer_state = v.customer_state
ORDER BY r.repeat_customer_rate DESC;


-- 11. States with high repeat rate and high satisfaction

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_unique_id,
        c.customer_state
),
repeat_rate AS (
    SELECT
        customer_state,
        COUNT(*) AS unique_customers,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE order_count > 1
            ) / COUNT(*),
            2
        ) AS repeat_customer_rate
    FROM customer_orders
    GROUP BY customer_state
),
review_data AS (
    SELECT
        c.customer_state,
        ROUND(AVG(r.review_score), 2)
            AS average_review_score
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN reviews r
        ON o.order_id = r.order_id
    GROUP BY c.customer_state
)
SELECT
    r.customer_state,
    r.unique_customers,
    r.repeat_customer_rate,
    v.average_review_score
FROM repeat_rate r
JOIN review_data v
    ON r.customer_state = v.customer_state
WHERE r.unique_customers >= 500
ORDER BY
    r.repeat_customer_rate DESC,
    v.average_review_score DESC;