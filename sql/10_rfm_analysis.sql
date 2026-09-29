-- ============================================================
-- RFM customer segmentation and customer value analysis
-- ============================================================

-- ============================================================
-- SET 18A — RFM BASE METRICS
-- ============================================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS customers,
    ROUND(AVG(frequency), 2) AS average_frequency,
    ROUND(AVG(monetary), 2) AS average_monetary,
    ROUND(MIN(monetary), 2) AS minimum_monetary,
    ROUND(MAX(monetary), 2) AS maximum_monetary
FROM customer_rfm;


-- Recency distribution

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(o.order_purchase_timestamp) AS max_purchase_date
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
)

SELECT
    CASE
        WHEN EXTRACT(
            EPOCH FROM (
                rd.max_purchase_date - cr.last_purchase_date
            )
        ) / 86400 <= 90
            THEN '0-90 days'

        WHEN EXTRACT(
            EPOCH FROM (
                rd.max_purchase_date - cr.last_purchase_date
            )
        ) / 86400 <= 180
            THEN '91-180 days'

        WHEN EXTRACT(
            EPOCH FROM (
                rd.max_purchase_date - cr.last_purchase_date
            )
        ) / 86400 <= 365
            THEN '181-365 days'

        WHEN EXTRACT(
            EPOCH FROM (
                rd.max_purchase_date - cr.last_purchase_date
            )
        ) / 86400 <= 730
            THEN '366-730 days'

        ELSE '730+ days'
    END AS recency_group,

    COUNT(*) AS customer_count

FROM customer_rfm cr
CROSS JOIN reference_date rd

GROUP BY recency_group

ORDER BY customer_count DESC;


-- ============================================================
-- SET 18B — EXPLORATORY RFM SCORING
-- ============================================================

-- NTILE-based scoring.
-- This is exploratory and is not used for the final RFM model.

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

rfm_scores AS (
    SELECT
        customer_unique_id,

        6 - NTILE(5) OVER (
            ORDER BY last_purchase_date
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary
        ) AS monetary_score

    FROM customer_rfm
)

SELECT
    recency_score,
    frequency_score,
    monetary_score,
    COUNT(*) AS customer_count
FROM rfm_scores
GROUP BY
    recency_score,
    frequency_score,
    monetary_score
ORDER BY
    recency_score DESC,
    frequency_score DESC,
    monetary_score DESC;


-- ============================================================
-- SET 18C — BUSINESS RFM SEGMENTATION
-- ============================================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(o.order_purchase_timestamp) AS max_purchase_date
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
),

rfm AS (
    SELECT
        cr.customer_unique_id,

        EXTRACT(
            EPOCH FROM (
                rd.max_purchase_date - cr.last_purchase_date
            )
        ) / 86400 AS recency_days,

        cr.frequency,
        cr.monetary

    FROM customer_rfm cr
    CROSS JOIN reference_date rd
)

SELECT
    CASE
        WHEN recency_days <= 90
             AND frequency >= 2
             AND monetary >= 300
            THEN 'Champions'

        WHEN recency_days <= 180
             AND frequency >= 2
            THEN 'Loyal customers'

        WHEN recency_days <= 90
             AND frequency = 1
            THEN 'Potential loyalists'

        WHEN recency_days > 180
             AND frequency >= 2
            THEN 'At risk'

        WHEN recency_days > 365
             AND frequency = 1
            THEN 'Lost / inactive'

        ELSE 'Other'
    END AS customer_segment,

    COUNT(*) AS customer_count,
    ROUND(AVG(frequency), 2) AS average_frequency,
    ROUND(AVG(monetary), 2) AS average_monetary

FROM rfm

GROUP BY customer_segment

ORDER BY customer_count DESC;


-- Revenue contribution by RFM segment

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(o.order_purchase_timestamp) AS max_purchase_date
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
),

segmented AS (
    SELECT
        cr.customer_unique_id,
        cr.monetary,

        CASE
            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 90
                 AND cr.frequency >= 2
                 AND cr.monetary >= 300
                THEN 'Champions'

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 180
                 AND cr.frequency >= 2
                THEN 'Loyal customers'

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 90
                 AND cr.frequency = 1
                THEN 'Potential loyalists'

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 > 180
                 AND cr.frequency >= 2
                THEN 'At risk'

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 > 365
                 AND cr.frequency = 1
                THEN 'Lost / inactive'

            ELSE 'Other'
        END AS customer_segment

    FROM customer_rfm cr
    CROSS JOIN reference_date rd
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(monetary), 2) AS total_revenue,

    ROUND(
        100.0 * SUM(monetary)
        / SUM(SUM(monetary)) OVER (),
        2
    ) AS revenue_percentage

FROM segmented

GROUP BY customer_segment

ORDER BY total_revenue DESC;


-- ============================================================
-- SET 18D — IMPROVED RFM SCORING
-- ============================================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(o.order_purchase_timestamp) AS max_purchase_date
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
)

SELECT
    cr.customer_unique_id,

    ROUND(
        EXTRACT(
            EPOCH FROM (
                rd.max_purchase_date - cr.last_purchase_date
            )
        ) / 86400,
        2
    ) AS recency_days,

    cr.frequency,

    ROUND(cr.monetary, 2) AS monetary,

    CASE
        WHEN EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date - cr.last_purchase_date
                )
             ) / 86400 <= 90
            THEN 5

        WHEN EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date - cr.last_purchase_date
                )
             ) / 86400 <= 180
            THEN 4

        WHEN EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date - cr.last_purchase_date
                )
             ) / 86400 <= 365
            THEN 3

        WHEN EXTRACT(
                EPOCH FROM (
                    rd.max_purchase_date - cr.last_purchase_date
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

ORDER BY
    recency_score DESC,
    frequency_score DESC,
    monetary_score DESC

LIMIT 20;


-- Frequency distribution

WITH customer_frequency AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS frequency
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

frequency_groups AS (
    SELECT
        customer_unique_id,
        frequency,

        CASE
            WHEN frequency = 1
                THEN '1 order'

            WHEN frequency = 2
                THEN '2 orders'

            WHEN frequency = 3
                THEN '3 orders'

            WHEN frequency BETWEEN 4 AND 5
                THEN '4-5 orders'

            ELSE '6+ orders'
        END AS frequency_group

    FROM customer_frequency
)

SELECT
    frequency_group,
    COUNT(*) AS customer_count

FROM frequency_groups

GROUP BY frequency_group

ORDER BY
    CASE frequency_group
        WHEN '1 order' THEN 1
        WHEN '2 orders' THEN 2
        WHEN '3 orders' THEN 3
        WHEN '4-5 orders' THEN 4
        WHEN '6+ orders' THEN 5
    END;


-- Monetary distribution

WITH customer_monetary AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

monetary_groups AS (
    SELECT
        customer_unique_id,
        monetary,

        CASE
            WHEN monetary < 100
                THEN 'Low: <100'

            WHEN monetary < 300
                THEN 'Medium: 100-299'

            WHEN monetary < 600
                THEN 'High: 300-599'

            WHEN monetary < 1000
                THEN 'Very high: 600-999'

            ELSE 'Premium: 1000+'
        END AS monetary_group

    FROM customer_monetary
)

SELECT
    monetary_group,
    COUNT(*) AS customer_count,
    ROUND(SUM(monetary), 2) AS total_revenue

FROM monetary_groups

GROUP BY monetary_group

ORDER BY
    CASE monetary_group
        WHEN 'Low: <100' THEN 1
        WHEN 'Medium: 100-299' THEN 2
        WHEN 'High: 300-599' THEN 3
        WHEN 'Very high: 600-999' THEN 4
        WHEN 'Premium: 1000+' THEN 5
    END;


-- ============================================================
-- SET 18E — FINAL RFM SEGMENTS
-- ============================================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(o.order_purchase_timestamp) AS max_purchase_date
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
),

scored AS (
    SELECT
        cr.customer_unique_id,
        cr.last_purchase_date,

        EXTRACT(
            EPOCH FROM (
                rd.max_purchase_date - cr.last_purchase_date
            )
        ) / 86400 AS recency_days,

        cr.frequency,
        cr.monetary,

        CASE
            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 90
                THEN 5

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 180
                THEN 4

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 365
                THEN 3

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
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
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(frequency), 2) AS average_frequency,
    ROUND(AVG(monetary), 2) AS average_monetary

FROM (
    SELECT
        *,
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

    FROM scored
) segments

GROUP BY customer_segment

ORDER BY customer_count DESC;


-- Revenue contribution by final segment

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(o.order_purchase_timestamp) AS max_purchase_date
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
),

scored AS (
    SELECT
        cr.*,

        CASE
            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 90 THEN 5

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 180 THEN 4

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 365 THEN 3

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 730 THEN 2

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
),

segments AS (
    SELECT
        *,
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

    FROM scored
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(monetary), 2) AS total_revenue,

    ROUND(
        100.0 * SUM(monetary)
        / SUM(SUM(monetary)) OVER (),
        2
    ) AS revenue_percentage

FROM segments

GROUP BY customer_segment

ORDER BY total_revenue DESC;


-- Top 20 Champions

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

reference_date AS (
    SELECT
        MAX(o.order_purchase_timestamp) AS max_purchase_date
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
)

SELECT
    cr.customer_unique_id,

    ROUND(
        EXTRACT(
            EPOCH FROM (
                rd.max_purchase_date - cr.last_purchase_date
            )
        ) / 86400,
        2
    ) AS recency_days,

    cr.frequency,
    ROUND(cr.monetary, 2) AS lifetime_revenue

FROM customer_rfm cr
CROSS JOIN reference_date rd

WHERE
    EXTRACT(
        EPOCH FROM (
            rd.max_purchase_date - cr.last_purchase_date
        )
    ) / 86400 <= 90

    AND cr.frequency >= 4
    AND cr.monetary >= 600

ORDER BY lifetime_revenue DESC

LIMIT 20;


-- ============================================================
-- SET 18F — FINAL RFM CUSTOMER DATASET
-- ============================================================

WITH customer_rfm AS (

    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary

    FROM customers c

    JOIN orders o
        ON c.customer_id = o.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id
),

reference_date AS (

    SELECT
        MAX(o.order_purchase_timestamp) AS max_purchase_date

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
                    rd.max_purchase_date - cr.last_purchase_date
                )
            ) / 86400,
            2
        ) AS recency_days,

        cr.frequency,
        ROUND(cr.monetary, 2) AS monetary,

        CASE
            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 90
                THEN 5

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 180
                THEN 4

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
                    )
                 ) / 86400 <= 365
                THEN 3

            WHEN EXTRACT(
                    EPOCH FROM (
                        rd.max_purchase_date - cr.last_purchase_date
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
),

final_rfm AS (

    SELECT
        *,
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

    FROM scored
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
    rfm_score,
    customer_segment

FROM final_rfm

ORDER BY
    recency_score DESC,
    frequency_score DESC,
    monetary_score DESC;