-- 1. Overall delivery performance

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders),
        2
    ) AS delivery_rate
FROM orders
WHERE order_status = 'delivered';


-- 2. Average delivery time

SELECT
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400
        ),
        2
    ) AS average_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- 3. Median delivery time

SELECT
    ROUND(
        (
            PERCENTILE_CONT(0.5) WITHIN GROUP (
                ORDER BY EXTRACT(
                    EPOCH FROM (
                        order_delivered_customer_date
                        - order_purchase_timestamp
                    )
                ) / 86400
            )
        )::numeric,
        2
    ) AS median_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- 4. Actual delivery vs estimated delivery

SELECT
    CASE
        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'On time / early'
        ELSE 'Late'
    END AS delivery_performance,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance
ORDER BY order_count DESC;


-- 5. Average delay / early delivery

SELECT
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400
        ),
        2
    ) AS average_delivery_difference_days,
    ROUND(
        MIN(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400
        ),
        2
    ) AS earliest_delivery_difference_days,
    ROUND(
        MAX(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400
        ),
        2
    ) AS latest_delivery_difference_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;


-- Delivery performance by customer state

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400
        ),
        2
    ) AS average_delivery_days,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date
                  <= o.order_estimated_delivery_date
        ) / COUNT(*),
        2
    ) AS on_time_percentage
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY on_time_percentage DESC;


-- States with the slowest average delivery

SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400
        ),
        2
    ) AS average_delivery_days
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 100
ORDER BY average_delivery_days DESC;


-- Monthly delivery performance

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    COUNT(*) AS delivered_orders,
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400
        ),
        2
    ) AS average_delivery_days,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date
                  <= o.order_estimated_delivery_date
        ) / COUNT(*),
        2
    ) AS on_time_percentage
FROM orders o
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY month
ORDER BY month;


-- Late delivery orders by state

SELECT
    c.customer_state,
    COUNT(*) AS late_orders
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND o.order_delivered_customer_date > o.order_estimated_delivery_date
GROUP BY c.customer_state
ORDER BY late_orders DESC;