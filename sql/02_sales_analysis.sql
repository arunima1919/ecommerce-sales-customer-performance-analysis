-- 1. Total orders

SELECT COUNT(*) AS total_orders
FROM orders;


-- 2. Orders by status

SELECT
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- 3. Total customers

SELECT COUNT(*) AS total_customers
FROM customers;


-- 4. Total unique customers

SELECT COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;


-- 5. Total revenue from order items

SELECT
    ROUND(SUM(price), 2) AS total_product_revenue
FROM order_items;


-- 6. Total freight

SELECT
    ROUND(SUM(freight_value), 2) AS total_freight
FROM order_items;


-- 7. Total payment value

SELECT
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM payments;


-- 8. Payment methods

SELECT
    payment_type,
    COUNT(*) AS payment_count,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


-- Monthly order volume

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    COUNT(*) AS total_orders
FROM orders o
GROUP BY month
ORDER BY month;


-- Monthly product revenue

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    ROUND(SUM(oi.price), 2) AS product_revenue
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY month
ORDER BY month;


-- Monthly average order value

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY month
ORDER BY month;