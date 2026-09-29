-- ============================================================
-- Review and customer satisfaction analysis
-- ============================================================

-- 1. Overall review score

SELECT
    ROUND(AVG(review_score), 2) AS average_review_score,
    MIN(review_score) AS minimum_score,
    MAX(review_score) AS maximum_score,
    COUNT(*) AS total_reviews
FROM reviews;


-- 2. Review score distribution

SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM reviews
GROUP BY review_score
ORDER BY review_score;


-- 3. Positive vs negative reviews

SELECT
    CASE
        WHEN review_score >= 4 THEN 'Positive'
        WHEN review_score = 3 THEN 'Neutral'
        ELSE 'Negative'
    END AS review_category,
    COUNT(*) AS review_count,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM reviews
GROUP BY review_category
ORDER BY review_count DESC;


-- 4. Average review score by delivery performance

SELECT
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'On time / early'
        ELSE 'Late'
    END AS delivery_performance,
    COUNT(*) AS review_count,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM reviews r
JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance
ORDER BY average_review_score DESC;


-- 5. Review score by actual delivery time

WITH delivery_reviews AS (
    SELECT
        CASE
            WHEN EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400 <= 7
                THEN '0-7 days'

            WHEN EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400 <= 14
                THEN '8-14 days'

            WHEN EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400 <= 21
                THEN '15-21 days'

            ELSE '22+ days'
        END AS delivery_time_group,

        r.review_score

    FROM reviews r
    JOIN orders o
        ON r.order_id = o.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    delivery_time_group,
    COUNT(*) AS review_count,
    ROUND(AVG(review_score)::numeric, 2)
        AS average_review_score
FROM delivery_reviews
GROUP BY delivery_time_group
ORDER BY
    CASE delivery_time_group
        WHEN '0-7 days' THEN 1
        WHEN '8-14 days' THEN 2
        WHEN '15-21 days' THEN 3
        WHEN '22+ days' THEN 4
    END;


-- 6. Review score by customer state

SELECT
    c.customer_state,
    COUNT(*) AS review_count,
    ROUND(AVG(r.review_score), 2)
        AS average_review_score,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE r.review_score >= 4
        ) / COUNT(*),
        2
    ) AS positive_review_percentage
FROM reviews r
JOIN orders o
    ON r.order_id = o.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY c.customer_state
HAVING COUNT(*) >= 100
ORDER BY average_review_score DESC;


-- 7. Reviews with and without written comments

SELECT
    CASE
        WHEN review_comment_message IS NULL
             OR TRIM(review_comment_message) = ''
            THEN 'No comment'
        ELSE 'Has comment'
    END AS comment_status,
    COUNT(*) AS review_count,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM reviews
GROUP BY comment_status
ORDER BY review_count DESC;


-- 8. Comment availability by review score

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    COUNT(*) FILTER (
        WHERE review_comment_message IS NOT NULL
          AND TRIM(review_comment_message) <> ''
    ) AS reviews_with_comments,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_comment_message IS NOT NULL
              AND TRIM(review_comment_message) <> ''
        ) / COUNT(*),
        2
    ) AS comment_percentage
FROM reviews
GROUP BY review_score
ORDER BY review_score;


-- 9. Average comment length by review score

SELECT
    review_score,

    COUNT(*) FILTER (
        WHERE review_comment_message IS NOT NULL
          AND TRIM(review_comment_message) <> ''
    ) AS comments,

    ROUND(
        AVG(
            LENGTH(TRIM(review_comment_message))
        ) FILTER (
            WHERE review_comment_message IS NOT NULL
              AND TRIM(review_comment_message) <> ''
        )::numeric,
        2
    ) AS average_comment_length,

    MAX(
        LENGTH(TRIM(review_comment_message))
    ) FILTER (
        WHERE review_comment_message IS NOT NULL
          AND TRIM(review_comment_message) <> ''
    ) AS maximum_comment_length

FROM reviews
GROUP BY review_score
ORDER BY review_score;


-- 10. Negative reviews: comments vs no comments

SELECT
    CASE
        WHEN review_comment_message IS NULL
             OR TRIM(review_comment_message) = ''
            THEN 'No comment'
        ELSE 'Has comment'
    END AS comment_status,
    COUNT(*) AS negative_reviews,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM reviews
WHERE review_score <= 2
GROUP BY comment_status
ORDER BY negative_reviews DESC;


-- 11. Are late orders more likely to have written comments?

SELECT
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'On time / early'
        ELSE 'Late'
    END AS delivery_performance,
    COUNT(*) AS review_count,
    COUNT(*) FILTER (
        WHERE r.review_comment_message IS NOT NULL
          AND TRIM(r.review_comment_message) <> ''
    ) AS reviews_with_comments,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE r.review_comment_message IS NOT NULL
              AND TRIM(r.review_comment_message) <> ''
        ) / COUNT(*),
        2
    ) AS comment_percentage
FROM reviews r
JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance
ORDER BY delivery_performance;


-- 12. Average review score based on whether customer wrote a comment

SELECT
    CASE
        WHEN review_comment_message IS NULL
             OR TRIM(review_comment_message) = ''
            THEN 'No comment'
        ELSE 'Has comment'
    END AS comment_status,
    COUNT(*) AS review_count,
    ROUND(AVG(review_score), 2) AS average_review_score
FROM reviews
GROUP BY comment_status
ORDER BY average_review_score DESC;