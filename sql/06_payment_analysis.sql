-- 1. Payment method usage

SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


-- 2. Payment method revenue contribution

WITH payment_summary AS (
    SELECT
        payment_type,
        SUM(payment_value) AS payment_value
    FROM payments
    GROUP BY payment_type
)
SELECT
    payment_type,
    ROUND(payment_value, 2) AS payment_value,
    ROUND(
        100.0 * payment_value / SUM(payment_value) OVER (),
        2
    ) AS payment_percentage
FROM payment_summary
ORDER BY payment_value DESC;


-- 3. Installment analysis

SELECT
    payment_type,
    COUNT(*) AS payment_records,
    ROUND(AVG(payment_installments), 2) AS average_installments,
    MIN(payment_installments) AS min_installments,
    MAX(payment_installments) AS max_installments
FROM payments
GROUP BY payment_type
ORDER BY average_installments DESC;


-- 4. Order value by payment method

WITH order_payment AS (
    SELECT
        order_id,
        payment_type,
        SUM(payment_value) AS order_payment_value
    FROM payments
    GROUP BY order_id, payment_type
)
SELECT
    payment_type,
    COUNT(*) AS order_count,
    ROUND(AVG(order_payment_value), 2) AS average_order_payment,
    ROUND(MIN(order_payment_value), 2) AS minimum_order_payment,
    ROUND(MAX(order_payment_value), 2) AS maximum_order_payment
FROM order_payment
GROUP BY payment_type
ORDER BY average_order_payment DESC;


-- 5. Payment method distribution by order

WITH order_payment AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_order_payment,
        MAX(payment_installments) AS installments,
        STRING_AGG(
            DISTINCT payment_type,
            ', '
        ) AS payment_methods
    FROM payments
    GROUP BY order_id
)
SELECT
    payment_methods,
    COUNT(*) AS order_count,
    ROUND(AVG(total_order_payment), 2) AS average_order_payment
FROM order_payment
GROUP BY payment_methods
ORDER BY order_count DESC;