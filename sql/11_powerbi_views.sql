-- ============================================================
-- Power BI dashboard views and KPI calculations
-- ============================================================

-- ============================================================
-- VIEW 1: MONTHLY SALES
-- ============================================================

CREATE OR REPLACE VIEW vw_monthly_sales AS

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::date AS month,

    COUNT(DISTINCT o.order_id) AS orders,

    ROUND(
        COALESCE(SUM(oi.price), 0),
        2
    ) AS revenue,

    ROUND(
        COALESCE(SUM(oi.price), 0)
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS aov

FROM orders o

LEFT JOIN order_items oi
    ON o.order_id = oi.order_id

GROUP BY
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )

ORDER BY month;


-- ============================================================
-- VIEW 2: CUSTOMER ANALYSIS
-- ============================================================

CREATE OR REPLACE VIEW vw_customer_analysis AS

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,
        c.customer_state,

        COUNT(DISTINCT o.order_id) AS order_count,

        SUM(oi.price) AS revenue

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY
        c.customer_unique_id,
        c.customer_state
)

SELECT
    customer_state,

    COUNT(*) AS customers,

    SUM(
        CASE
            WHEN order_count = 1 THEN 1
            ELSE 0
        END
    ) AS one_time_customers,

    SUM(
        CASE
            WHEN order_count > 1 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN order_count > 1 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS repeat_rate_percent,

    ROUND(
        SUM(revenue),
        2
    ) AS revenue,

    ROUND(
        AVG(revenue),
        2
    ) AS avg_customer_revenue

FROM customer_orders

GROUP BY customer_state

ORDER BY revenue DESC;


-- ============================================================
-- VIEW 3: RFM CUSTOMER SEGMENTATION
-- ============================================================

CREATE OR REPLACE VIEW vw_rfm_customers AS

WITH customer_rfm AS (

    SELECT
        c.customer_unique_id,

        MAX(o.order_purchase_timestamp)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(oi.price)
            AS monetary

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id
),

reference_date AS (

    SELECT
        MAX(o.order_purchase_timestamp)
            AS max_purchase_date

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id
),

scored AS (

    SELECT
        cr.customer_unique_id,
        cr.last_purchase_date,

        ROUND(
            EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date
                    - cr.last_purchase_date
                )
            ) / 86400,
            2
        ) AS recency_days,

        cr.frequency,

        ROUND(
            cr.monetary,
            2
        ) AS monetary,

        CASE
            WHEN EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date
                    - cr.last_purchase_date
                )
            ) / 86400 <= 90
                THEN 5

            WHEN EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date
                    - cr.last_purchase_date
                )
            ) / 86400 <= 180
                THEN 4

            WHEN EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date
                    - cr.last_purchase_date
                )
            ) / 86400 <= 365
                THEN 3

            WHEN EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date
                    - cr.last_purchase_date
                )
            ) / 86400 <= 730
                THEN 2

            ELSE 1
        END AS recency_score,

        CASE
            WHEN cr.frequency = 1 THEN 1
            WHEN cr.frequency = 2 THEN 2
            WHEN cr.frequency = 3 THEN 3
            WHEN cr.frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS frequency_score,

        CASE
            WHEN cr.monetary < 100 THEN 1
            WHEN cr.monetary < 300 THEN 2
            WHEN cr.monetary < 600 THEN 3
            WHEN cr.monetary < 1000 THEN 4
            ELSE 5
        END AS monetary_score

    FROM customer_rfm cr

    CROSS JOIN reference_date rd
)

SELECT
    customer_unique_id,
    last_purchase_date,
    recency_days,
    frequency,
    monetary,

    recency_score,
    frequency_score,
    monetary_score,

    CONCAT(
        recency_score,
        frequency_score,
        monetary_score
    ) AS rfm_score,

    CASE

        WHEN recency_score = 5
             AND frequency_score >= 4
             AND monetary_score >= 4
            THEN 'Champions'

        WHEN recency_score >= 4
             AND frequency_score >= 2
             AND monetary_score >= 2
            THEN 'Loyal customers'

        WHEN recency_score >= 4
             AND frequency_score = 1
             AND monetary_score >= 2
            THEN 'Potential loyalists'

        WHEN recency_score <= 3
             AND frequency_score >= 2
            THEN 'At risk'

        WHEN recency_score <= 2
             AND frequency_score = 1
            THEN 'Lost / inactive'

        ELSE 'Other'

    END AS customer_segment

FROM scored;


-- ============================================================
-- VIEW 4: DELIVERY AND REVIEW ANALYSIS
-- ============================================================

CREATE OR REPLACE VIEW vw_delivery_reviews AS

WITH delivery AS (

    SELECT
        c.customer_state,
        o.order_id,

        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )
        ) / 86400 AS delivery_days,

        CASE
            WHEN o.order_delivered_customer_date
                 <= o.order_estimated_delivery_date
                THEN 1
            ELSE 0
        END AS on_time

    FROM orders o

    JOIN customers c
        ON o.customer_id = c.customer_id

    WHERE
        o.order_status = 'delivered'

        AND o.order_delivered_customer_date IS NOT NULL

        AND o.order_purchase_timestamp IS NOT NULL

        AND o.order_estimated_delivery_date IS NOT NULL
),

review_scores AS (

    SELECT
        order_id,
        AVG(review_score) AS review_score

    FROM reviews

    GROUP BY order_id
)

SELECT
    d.customer_state,

    COUNT(DISTINCT d.order_id)
        AS delivered_orders,

    ROUND(
        AVG(d.delivery_days),
        2
    ) AS avg_delivery_days,

    ROUND(
        100.0 * AVG(d.on_time),
        2
    ) AS on_time_percent,

    ROUND(
        AVG(r.review_score),
        2
    ) AS avg_review_score

FROM delivery d

LEFT JOIN review_scores r
    ON d.order_id = r.order_id

GROUP BY d.customer_state

ORDER BY delivered_orders DESC;


-- ============================================================
-- VIEW 5: PRODUCT CATEGORY ANALYSIS
-- ============================================================

CREATE OR REPLACE VIEW vw_product_category AS

SELECT
    COALESCE(
        p.product_category_name,
        'Unknown'
    ) AS category,

    COUNT(DISTINCT oi.order_id)
        AS orders,

    COUNT(*)
        AS items_sold,

    ROUND(
        SUM(oi.price),
        2
    ) AS revenue,

    ROUND(
        AVG(oi.price),
        2
    ) AS avg_item_price

FROM order_items oi

JOIN products p
    ON oi.product_id = p.product_id

GROUP BY
    COALESCE(
        p.product_category_name,
        'Unknown'
    )

ORDER BY revenue DESC;


-- ============================================================
-- VIEW 6: TOTAL CUSTOMERS
-- ============================================================

CREATE OR REPLACE VIEW vw_total_customers AS

SELECT
    COUNT(DISTINCT customer_unique_id)
        AS total_customers

FROM customers;


-- ============================================================
-- VIEW 7: OVERALL AVERAGE ORDER VALUE
-- ============================================================

CREATE OR REPLACE VIEW vw_overall_aov AS

SELECT
    ROUND(
        SUM(oi.price)
        / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value

FROM orders o

LEFT JOIN order_items oi
    ON o.order_id = oi.order_id;


-- ============================================================
-- VIEW 8: PAYMENT METHODS
-- ============================================================

CREATE OR REPLACE VIEW vw_payment_methods AS

SELECT
    payment_type,

    COUNT(*) AS payment_count,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS payment_percentage

FROM payments

GROUP BY payment_type

ORDER BY payment_count DESC;


-- ============================================================
-- VIEW 9: CUSTOMER KPIs
-- ============================================================

CREATE OR REPLACE VIEW vw_customer_kpis AS

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id)
            AS order_count,

        COALESCE(
            SUM(oi.price),
            0
        ) AS revenue

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    LEFT JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS total_customers,

    SUM(
        CASE
            WHEN order_count = 1 THEN 1
            ELSE 0
        END
    ) AS one_time_customers,

    SUM(
        CASE
            WHEN order_count > 1 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN order_count > 1 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS repeat_customer_rate,

    ROUND(
        AVG(revenue),
        2
    ) AS avg_customer_revenue

FROM customer_orders;


-- ============================================================
-- VIEW 10: CUSTOMER TYPE
-- ============================================================

CREATE OR REPLACE VIEW vw_customer_type AS

WITH customer_orders AS (

    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id)
            AS order_count

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN order_count = 1
            THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,

    COUNT(*) AS customer_count

FROM customer_orders

GROUP BY
    CASE
        WHEN order_count = 1
            THEN 'One-time'
        ELSE 'Repeat'
    END;


-- ============================================================
-- VIEW 11: DELIVERY KPIs
-- ============================================================

DROP VIEW IF EXISTS vw_delivery_kpis;

CREATE VIEW vw_delivery_kpis AS

WITH delivery_kpi AS (

    SELECT
        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_orders,

        ROUND(
            100.0
            * COUNT(*) FILTER (
                WHERE order_status = 'delivered'
            )
            / COUNT(*),
            2
        ) AS delivery_rate,

        ROUND(
            100.0
            * COUNT(*) FILTER (
                WHERE order_status = 'delivered'
                  AND order_delivered_customer_date
                      <= order_estimated_delivery_date
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE order_status = 'delivered'
                ),
                0
            ),
            2
        ) AS on_time_delivery_percent,

        ROUND(
            AVG(
                EXTRACT(
                    EPOCH FROM (
                        order_delivered_customer_date
                        - order_purchase_timestamp
                    )
                ) / 86400
            ) FILTER (
                WHERE order_status = 'delivered'
            ),
            2
        ) AS avg_delivery_days

    FROM orders
),

review_kpi AS (

    SELECT
        ROUND(
            AVG(review_score),
            2
        ) AS avg_review_score

    FROM reviews
)

SELECT
    d.total_orders,
    d.delivered_orders,
    d.delivery_rate,
    d.on_time_delivery_percent,
    d.avg_delivery_days,
    r.avg_review_score

FROM delivery_kpi d

CROSS JOIN review_kpi r;


-- ============================================================
-- VIEW 12: DELIVERY STATUS
-- ============================================================

CREATE OR REPLACE VIEW vw_delivery_status AS

SELECT
    CASE
        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,

    COUNT(*) AS order_count

FROM orders

WHERE order_status = 'delivered'

GROUP BY 1;


-- ============================================================
-- VIEW 13: DELIVERY TIME BUCKETS
-- ============================================================

CREATE OR REPLACE VIEW vw_delivery_time_buckets AS

WITH delivery_days AS (

    SELECT
        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date
                - order_purchase_timestamp
            )
        ) / 86400 AS days

    FROM orders

    WHERE order_status = 'delivered'
)

SELECT
    CASE
        WHEN days <= 7
            THEN '0–7 days'

        WHEN days <= 14
            THEN '8–14 days'

        WHEN days <= 21
            THEN '15–21 days'

        ELSE '22+ days'

    END AS delivery_time_bucket,

    CASE
        WHEN days <= 7 THEN 1
        WHEN days <= 14 THEN 2
        WHEN days <= 21 THEN 3
        ELSE 4
    END AS sort_order,

    COUNT(*) AS order_count

FROM delivery_days

GROUP BY 1, 2

ORDER BY sort_order;


-- ============================================================
-- VIEW 14: DELIVERY TIME VS REVIEW SCORE
-- ============================================================

CREATE OR REPLACE VIEW vw_delivery_time_review AS

WITH delivery_data AS (

    SELECT
        o.order_id,

        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )
        ) / 86400 AS days

    FROM orders o

    WHERE o.order_status = 'delivered'
),

review_per_order AS (

    SELECT
        order_id,

        AVG(review_score) AS review_score

    FROM reviews

    GROUP BY order_id
)

SELECT
    CASE
        WHEN d.days <= 7
            THEN '0–7 days'

        WHEN d.days <= 14
            THEN '8–14 days'

        WHEN d.days <= 21
            THEN '15–21 days'

        ELSE '22+ days'

    END AS delivery_time_bucket,

    CASE
        WHEN d.days <= 7 THEN 1
        WHEN d.days <= 14 THEN 2
        WHEN d.days <= 21 THEN 3
        ELSE 4
    END AS sort_order,

    ROUND(
        AVG(r.review_score),
        2
    ) AS avg_review_score

FROM delivery_data d

JOIN review_per_order r
    ON d.order_id = r.order_id

GROUP BY 1, 2

ORDER BY sort_order;

-- ============================================================
-- VIEW 15: REVIEW SCORE DISTRIBUTION
-- ============================================================

CREATE OR REPLACE VIEW vw_review_score_distribution AS

SELECT
    review_score,

    COUNT(*) AS review_count

FROM reviews

WHERE review_score IS NOT NULL

GROUP BY review_score

ORDER BY review_score;

-- ============================================================
-- CHECK ALL POWER BI VIEWS
-- ============================================================

SELECT *
FROM vw_monthly_sales;


SELECT *
FROM vw_customer_analysis;


SELECT *
FROM vw_rfm_customers
LIMIT 20;


SELECT *
FROM vw_delivery_reviews;


SELECT *
FROM vw_product_category;


SELECT *
FROM vw_total_customers;


SELECT *
FROM vw_overall_aov;


SELECT *
FROM vw_payment_methods;


SELECT *
FROM vw_customer_kpis;


SELECT *
FROM vw_customer_type;


SELECT *
FROM vw_delivery_kpis;


SELECT *
FROM vw_delivery_status;


SELECT *
FROM vw_delivery_time_buckets;


SELECT *
FROM vw_delivery_time_review;


SELECT *
FROM vw_review_score_distribution;