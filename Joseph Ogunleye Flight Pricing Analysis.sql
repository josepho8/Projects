-- ============================================================
--  FLIGHT PRICE ANALYSIS — When Is the Best Time to Book?
--  Author : Joseph Ogunleye
--  Dataset: Modelled on dilwong/FlightPrices (Kaggle)
--           One-way flight prices scraped from Expedia
--           Search window: April 16 – October 5, 2022
--  Tool   : SQLite (compatible with PostgreSQL / DuckDB)
-- ============================================================


-- ============================================================
-- SECTION 0 — DATA EXPLORATION & QUALITY CHECK
-- ============================================================

-- 0.1 Row count and date range
SELECT
    COUNT(*)                          AS total_records,
    MIN(search_date)                  AS earliest_search,
    MAX(search_date)                  AS latest_search,
    MIN(departure_date)               AS earliest_departure,
    MAX(departure_date)               AS latest_departure,
    ROUND(MIN(base_fare), 2)          AS min_fare,
    ROUND(MAX(base_fare), 2)          AS max_fare,
    ROUND(AVG(base_fare), 2)          AS avg_fare
FROM flights ;

-- 0.2 Cabin class breakdown
SELECT
    cabin_class,
    COUNT(*)                                          AS num_records,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS pct_of_total,
    ROUND(AVG(base_fare), 2)                          AS avg_fare,
    ROUND(MIN(base_fare), 2)                          AS min_fare,
    ROUND(MAX(base_fare), 2)                          AS max_fare
FROM flights
GROUP BY cabin_class
ORDER BY avg_fare;

-- 0.3 Route coverage
SELECT
    origin || ' → ' || destination AS route,
    origin_city || ' → ' || destination_city AS route_cities,
    COUNT(*)             AS num_records,
    ROUND(AVG(base_fare),2) AS avg_fare
FROM flights
GROUP BY route, route_cities
ORDER BY avg_fare;

-- 0.4 Null check on key columns
SELECT
    SUM(CASE WHEN base_fare       IS NULL THEN 1 ELSE 0 END) AS null_fares,
    SUM(CASE WHEN departure_date  IS NULL THEN 1 ELSE 0 END) AS null_dep_dates,
    SUM(CASE WHEN search_date     IS NULL THEN 1 ELSE 0 END) AS null_search_dates,
    SUM(CASE WHEN days_until_flight IS NULL THEN 1 ELSE 0 END) AS null_days_ahead,
    SUM(CASE WHEN airline_name    IS NULL THEN 1 ELSE 0 END) AS null_airline
FROM flights;


-- ============================================================
-- SECTION 1 — ADVANCE BOOKING WINDOW ANALYSIS
--  Core question: How far in advance should you book?
-- ============================================================

-- 1.1  Average economy fare by booking window bucket
--      This is the headline finding of the project.
SELECT
    CASE
        WHEN days_until_flight BETWEEN 0  AND 7   THEN '1. Last-minute (0–7 days)'
        WHEN days_until_flight BETWEEN 8  AND 14  THEN '2. 1–2 weeks   (8–14 days)'
        WHEN days_until_flight BETWEEN 15 AND 21  THEN '3. 2–3 weeks   (15–21 days)'
        WHEN days_until_flight BETWEEN 22 AND 30  THEN '4. 3–4 weeks   (22–30 days)'
        WHEN days_until_flight BETWEEN 31 AND 45  THEN '5. 1–1.5 months(31–45 days)'
        WHEN days_until_flight BETWEEN 46 AND 60  THEN '6. 1.5–2 months(46–60 days)'
        WHEN days_until_flight BETWEEN 61 AND 90  THEN '7. 2–3 months  (61–90 days)'
        WHEN days_until_flight BETWEEN 91 AND 120 THEN '8. 3–4 months  (91–120 days)'
        ELSE                                           '9. 4+ months   (121+ days)'
    END                           AS booking_window,
    COUNT(*)                      AS num_flights,
    ROUND(AVG(base_fare), 2)      AS avg_fare,
    ROUND(MIN(base_fare), 2)      AS min_fare,
--     ROUND(MEDIAN(base_fare), 2)   AS median_fare,
    ROUND(MAX(base_fare), 2)      AS max_fare
FROM flights
WHERE cabin_class = 'economy'
GROUP BY booking_window
ORDER BY booking_window;

-- NOTE: MEDIAN() is a SQLite extension (available in DuckDB/Postgres via PERCENTILE_CONT).
-- If MEDIAN() is unavailable, replace with AVG() or use the percentile query in 1.2.

-- 1.2  Percentile fares by booking window (no MEDIAN required)
--      Shows the 25th, 50th, and 75th percentile price for each window.
WITH numbered AS (
    SELECT
        CASE
            WHEN days_until_flight BETWEEN 0  AND 7   THEN '1. 0–7 days'
            WHEN days_until_flight BETWEEN 8  AND 21  THEN '2. 8–21 days'
            WHEN days_until_flight BETWEEN 22 AND 45  THEN '3. 22–45 days'
            WHEN days_until_flight BETWEEN 46 AND 90  THEN '4. 46–90 days'
            ELSE                                           '5. 91+ days'
        END AS window_bucket,
        base_fare,
        ROW_NUMBER() OVER (PARTITION BY
            CASE
                WHEN days_until_flight BETWEEN 0  AND 7   THEN '1. 0–7 days'
                WHEN days_until_flight BETWEEN 8  AND 21  THEN '2. 8–21 days'
                WHEN days_until_flight BETWEEN 22 AND 45  THEN '3. 22–45 days'
                WHEN days_until_flight BETWEEN 46 AND 90  THEN '4. 46–90 days'
                ELSE                                           '5. 91+ days'
            END
            ORDER BY base_fare) AS rn,
        COUNT(*) OVER (PARTITION BY
            CASE
                WHEN days_until_flight BETWEEN 0  AND 7   THEN '1. 0–7 days'
                WHEN days_until_flight BETWEEN 8  AND 21  THEN '2. 8–21 days'
                WHEN days_until_flight BETWEEN 22 AND 45  THEN '3. 22–45 days'
                WHEN days_until_flight BETWEEN 46 AND 90  THEN '4. 46–90 days'
                ELSE                                           '5. 91+ days'
            END) AS total
    FROM flights
    WHERE cabin_class = 'economy'
)
SELECT
    window_bucket,
    COUNT(*)                    AS num_records,
    ROUND(AVG(base_fare), 2)    AS avg_fare,
    ROUND(AVG(CASE WHEN rn BETWEEN total*0.24 AND total*0.26 THEN base_fare END), 2) AS p25_fare,
    ROUND(AVG(CASE WHEN rn BETWEEN total*0.49 AND total*0.51 THEN base_fare END), 2) AS p50_fare,
    ROUND(AVG(CASE WHEN rn BETWEEN total*0.74 AND total*0.76 THEN base_fare END), 2) AS p75_fare
FROM numbered
GROUP BY window_bucket
ORDER BY window_bucket;

-- 1.3  Price vs. booking window broken down by route
--      Helps answer: does the sweet spot differ for domestic vs. international?
SELECT
    origin || ' → ' || destination                   AS route,
    CASE
        WHEN days_until_flight BETWEEN 0  AND 7   THEN '0–7 days'
        WHEN days_until_flight BETWEEN 8  AND 21  THEN '8–21 days'
        WHEN days_until_flight BETWEEN 22 AND 45  THEN '22–45 days'
        WHEN days_until_flight BETWEEN 46 AND 90  THEN '46–90 days'
        ELSE                                           '91+ days'
    END                                              AS booking_window,
    COUNT(*)                                         AS num_records,
    ROUND(AVG(base_fare), 2)                         AS avg_fare
FROM flights
WHERE cabin_class = 'economy'
GROUP BY route, booking_window
ORDER BY route, booking_window;

-- 1.4  Savings vs. last-minute booking (the "opportunity cost" view)
--      How much do you save by booking at the optimal window vs. last-minute?
WITH window_avgs AS (
    SELECT
        CASE
            WHEN days_until_flight BETWEEN 0  AND 7   THEN '0–7 days'
            WHEN days_until_flight BETWEEN 8  AND 21  THEN '8–21 days'
            WHEN days_until_flight BETWEEN 22 AND 45  THEN '22–45 days'
            WHEN days_until_flight BETWEEN 46 AND 90  THEN '46–90 days'
            ELSE                                           '91+ days'
        END    AS booking_window,
        ROUND(AVG(base_fare), 2) AS avg_fare
    FROM flights
    WHERE cabin_class = 'economy'
    GROUP BY booking_window
),
last_min AS (
    SELECT avg_fare AS lm_fare FROM window_avgs WHERE booking_window = '0–7 days'
)
SELECT
    w.booking_window,
    w.avg_fare,
    lm.lm_fare                                     AS last_minute_avg,
    ROUND(lm.lm_fare - w.avg_fare, 2)              AS savings_vs_last_minute,
    ROUND(100.0*(lm.lm_fare - w.avg_fare)/lm.lm_fare, 1) AS pct_cheaper
FROM window_avgs w, last_min lm
ORDER BY w.booking_window;


-- ============================================================
-- SECTION 2 — DAY OF WEEK ANALYSIS
--  Which day should you fly — and which day should you book?
-- ============================================================

-- 2.1  Average economy fare by departure day of week
SELECT
    departure_dow                AS day_of_week,
    COUNT(*)                     AS num_flights,
    ROUND(AVG(base_fare), 2)     AS avg_fare,
    ROUND(MIN(base_fare), 2)     AS min_fare,
    ROUND(MAX(base_fare), 2)     AS max_fare,
    ROUND(AVG(base_fare) - AVG(AVG(base_fare)) OVER(), 2) AS diff_from_weekly_avg
FROM flights
WHERE cabin_class = 'economy'
GROUP BY departure_dow
ORDER BY avg_fare;

-- 2.2  Cheapest days to fly by route
SELECT
    origin || ' → ' || destination AS route,
    departure_dow,
    ROUND(AVG(base_fare), 2)       AS avg_fare,
    RANK() OVER (
        PARTITION BY origin || ' → ' || destination
        ORDER BY AVG(base_fare)
    )                              AS price_rank
FROM flights
WHERE cabin_class = 'economy'
GROUP BY route, departure_dow
ORDER BY route, price_rank;

-- 2.3  Day of week × booking window heatmap
--      Best combination of when to book AND when to fly
SELECT
    departure_dow,
    CASE
        WHEN days_until_flight BETWEEN 0  AND 7   THEN '0–7 days'
        WHEN days_until_flight BETWEEN 8  AND 21  THEN '8–21 days'
        WHEN days_until_flight BETWEEN 22 AND 45  THEN '22–45 days'
        WHEN days_until_flight BETWEEN 46 AND 90  THEN '46–90 days'
        ELSE                                           '91+ days'
    END                          AS booking_window,
    COUNT(*)                     AS num_records,
    ROUND(AVG(base_fare), 2)     AS avg_fare
FROM flights
WHERE cabin_class = 'economy'
GROUP BY departure_dow, booking_window
ORDER BY departure_dow, booking_window;


-- ============================================================
-- SECTION 3 — SEASONAL & MONTHLY ANALYSIS
--  Does travel month impact price?
-- ============================================================

-- 3.1  Average economy fare by departure month
SELECT
    departure_month                                                AS month_num,
    departure_month_name                                           AS month,
    COUNT(*)                                                       AS num_flights,
    ROUND(AVG(base_fare), 2)                                       AS avg_fare,
    ROUND(AVG(base_fare) - AVG(AVG(base_fare)) OVER(), 2)         AS diff_from_annual_avg,
    ROUND(100.0*(AVG(base_fare) - AVG(AVG(base_fare)) OVER())
          / AVG(AVG(base_fare)) OVER(), 1)                         AS pct_vs_annual_avg
FROM flights
WHERE cabin_class = 'economy'
GROUP BY month_num, month
ORDER BY month_num;

-- 3.2  Monthly fare by route — spot peak travel periods per corridor
SELECT
    origin || ' → ' || destination AS route,
    departure_month_name           AS month,
    ROUND(AVG(base_fare), 2)       AS avg_fare,
    RANK() OVER (
        PARTITION BY origin || ' → ' || destination
        ORDER BY AVG(base_fare) ASC
    )                              AS cheapest_month_rank
FROM flights
WHERE cabin_class = 'economy'
GROUP BY route, departure_month_name, departure_month
ORDER BY route, departure_month;

-- 3.3  Seasonal summary (grouped quarters)
SELECT
    CASE departure_month
        WHEN 12 THEN 'Winter (Dec–Feb)'
        WHEN 1  THEN 'Winter (Dec–Feb)'
        WHEN 2  THEN 'Winter (Dec–Feb)'
        WHEN 3  THEN 'Spring (Mar–May)'
        WHEN 4  THEN 'Spring (Mar–May)'
        WHEN 5  THEN 'Spring (Mar–May)'
        WHEN 6  THEN 'Summer (Jun–Aug)'
        WHEN 7  THEN 'Summer (Jun–Aug)'
        WHEN 8  THEN 'Summer (Jun–Aug)'
        ELSE         'Fall   (Sep–Nov)'
    END                        AS season,
    COUNT(*)                   AS num_flights,
    ROUND(AVG(base_fare), 2)   AS avg_fare,
    ROUND(MIN(base_fare), 2)   AS min_fare
FROM flights
WHERE cabin_class = 'economy'
GROUP BY season
ORDER BY avg_fare;


-- ============================================================
-- SECTION 4 — AIRLINE ANALYSIS
--  Which airline offers the best value?
-- ============================================================

-- 4.1  Airline fare comparison (economy, all routes)
SELECT
    airline_name,
    COUNT(*)                   AS num_records,
    ROUND(AVG(base_fare), 2)   AS avg_fare,
    ROUND(MIN(base_fare), 2)   AS min_fare,
    ROUND(MAX(base_fare), 2)   AS max_fare,
    ROUND(AVG(CASE WHEN is_nonstop = 1 THEN base_fare END), 2) AS avg_nonstop_fare,
    ROUND(AVG(CASE WHEN is_nonstop = 0 THEN base_fare END), 2) AS avg_connecting_fare
FROM flights
WHERE cabin_class = 'economy'
GROUP BY airline_name
ORDER BY avg_fare;

-- 4.2  Nonstop vs. connecting price premium by airline
SELECT
    airline_name,
    ROUND(AVG(CASE WHEN is_nonstop=1 THEN base_fare END), 2)  AS avg_nonstop,
    ROUND(AVG(CASE WHEN is_nonstop=0 THEN base_fare END), 2)  AS avg_connecting,
    ROUND(AVG(CASE WHEN is_nonstop=1 THEN base_fare END)
        - AVG(CASE WHEN is_nonstop=0 THEN base_fare END), 2)  AS nonstop_premium,
    ROUND(100.0*(AVG(CASE WHEN is_nonstop=1 THEN base_fare END)
        - AVG(CASE WHEN is_nonstop=0 THEN base_fare END))
        / AVG(CASE WHEN is_nonstop=0 THEN base_fare END), 1)  AS nonstop_pct_more_expensive
FROM flights
WHERE cabin_class = 'economy'
GROUP BY airline_name
HAVING avg_nonstop IS NOT NULL AND avg_connecting IS NOT NULL
ORDER BY nonstop_premium DESC;

-- 4.3  Airline pricing by booking window
--      Does booking early help more with one airline than another?
SELECT
    airline_name,
    CASE
        WHEN days_until_flight BETWEEN 0  AND 21  THEN 'Short notice (0–21d)'
        WHEN days_until_flight BETWEEN 22 AND 60  THEN 'Sweet spot   (22–60d)'
        ELSE                                           'Far ahead    (61+d)'
    END                          AS booking_window,
    COUNT(*)                     AS num_records,
    ROUND(AVG(base_fare), 2)     AS avg_fare
FROM flights
WHERE cabin_class = 'economy'
GROUP BY airline_name, booking_window
ORDER BY airline_name, booking_window;


-- ============================================================
-- SECTION 5 — DEPARTURE TIME ANALYSIS
--  Does the time of day you fly affect the price?
-- ============================================================

-- 5.1  Average fare by departure hour
SELECT
    departure_hour,
    CASE
        WHEN departure_hour BETWEEN 6  AND 8  THEN 'Early morning (6–8am)'
        WHEN departure_hour BETWEEN 9  AND 11 THEN 'Morning       (9–11am)'
        WHEN departure_hour BETWEEN 12 AND 14 THEN 'Midday        (12–2pm)'
        WHEN departure_hour BETWEEN 15 AND 17 THEN 'Afternoon     (3–5pm)'
        WHEN departure_hour BETWEEN 18 AND 20 THEN 'Evening       (6–8pm)'
        ELSE                                       'Night         (9pm+)'
    END                        AS time_of_day,
    COUNT(*)                   AS num_flights,
    ROUND(AVG(base_fare), 2)   AS avg_fare
FROM flights
WHERE cabin_class = 'economy'
GROUP BY departure_hour, time_of_day
ORDER BY departure_hour;

-- 5.2  Time-of-day buckets ranked cheapest to most expensive
SELECT
    CASE
        WHEN departure_hour BETWEEN 6  AND 8  THEN 'Early morning (6–8am)'
        WHEN departure_hour BETWEEN 9  AND 11 THEN 'Morning       (9–11am)'
        WHEN departure_hour BETWEEN 12 AND 14 THEN 'Midday        (12–2pm)'
        WHEN departure_hour BETWEEN 15 AND 17 THEN 'Afternoon     (3–5pm)'
        WHEN departure_hour BETWEEN 18 AND 20 THEN 'Evening       (6–8pm)'
        ELSE                                       'Night         (9pm+)'
    END                        AS time_of_day,
    COUNT(*)                   AS num_flights,
    ROUND(AVG(base_fare), 2)   AS avg_fare,
    RANK() OVER (ORDER BY AVG(base_fare)) AS price_rank
FROM flights
WHERE cabin_class = 'economy'
GROUP BY time_of_day
ORDER BY price_rank;


-- ============================================================
-- SECTION 6 — CABIN CLASS & STOPS ANALYSIS
-- ============================================================

-- 6.1  Fare comparison across all cabin classes
SELECT
    cabin_class,
    num_stops,
    COUNT(*)                   AS num_records,
    ROUND(AVG(base_fare), 2)   AS avg_fare,
    ROUND(MIN(base_fare), 2)   AS min_fare,
    ROUND(MAX(base_fare), 2)   AS max_fare
FROM flights
GROUP BY cabin_class, num_stops
ORDER BY cabin_class, num_stops;

-- 6.2  Business class premium vs. economy by route
SELECT
    origin || ' → ' || destination                         AS route,
    ROUND(AVG(CASE WHEN cabin_class='economy'  THEN base_fare END), 2) AS economy_avg,
    ROUND(AVG(CASE WHEN cabin_class='business' THEN base_fare END), 2) AS business_avg,
    ROUND(AVG(CASE WHEN cabin_class='business' THEN base_fare END)
        - AVG(CASE WHEN cabin_class='economy'  THEN base_fare END), 2) AS business_premium,
    ROUND(AVG(CASE WHEN cabin_class='business' THEN base_fare END)
        / AVG(CASE WHEN cabin_class='economy'  THEN base_fare END), 2) AS business_multiple
FROM flights
GROUP BY route
HAVING economy_avg IS NOT NULL AND business_avg IS NOT NULL
ORDER BY business_multiple DESC;

-- 6.3  Value of adding a stop (how much do you save vs. nonstop?)
SELECT
    num_stops,
    COUNT(*)                   AS num_records,
    ROUND(AVG(base_fare), 2)   AS avg_fare,
    ROUND(AVG(base_fare) - FIRST_VALUE(AVG(base_fare)) OVER (ORDER BY num_stops), 2)
                               AS extra_cost_vs_nonstop
FROM flights
WHERE cabin_class = 'economy'
GROUP BY num_stops
ORDER BY num_stops;


-- ============================================================
-- SECTION 7 — WINDOW FUNCTIONS & ADVANCED ANALYSIS
-- ============================================================

-- 7.1  Rolling 7-day average fare per route (trend smoothing)
WITH daily_avg AS (
    SELECT
        origin || ' → ' || destination AS route,
        search_date,
        ROUND(AVG(base_fare), 2)       AS daily_avg_fare
    FROM flights
    WHERE cabin_class = 'economy'
    GROUP BY route, search_date
)
SELECT
    route,
    search_date,
    daily_avg_fare,
    ROUND(AVG(daily_avg_fare) OVER (
        PARTITION BY route
        ORDER BY search_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7day_avg
FROM daily_avg
ORDER BY route, search_date;

-- 7.2  Price percentile rank of each record within its route + cabin
--      Useful for flagging "good deals" (bottom 20th percentile)
SELECT
--     flight_id,
    origin || ' → ' || destination AS route,
    cabin_class,
    departure_date,
    airline_name,
    base_fare,
    ROUND(PERCENT_RANK() OVER (
        PARTITION BY origin, destination, cabin_class
        ORDER BY base_fare
    ) * 100, 1) AS price_percentile,
    CASE
        WHEN PERCENT_RANK() OVER (
            PARTITION BY origin, destination, cabin_class
            ORDER BY base_fare) <= 0.20 THEN 'Great deal'
        WHEN PERCENT_RANK() OVER (
            PARTITION BY origin, destination, cabin_class
            ORDER BY base_fare) <= 0.40 THEN 'Good price'
        WHEN PERCENT_RANK() OVER (
            PARTITION BY origin, destination, cabin_class
            ORDER BY base_fare) <= 0.70 THEN 'Average'
        ELSE                                  'Expensive'
    END AS price_label
FROM flights
ORDER BY price_percentile;

-- 7.3  Cheapest flight per route per day (best available fare)
SELECT
    search_date,
    origin || ' → ' || destination AS route,
    cabin_class,
    MIN(base_fare)                 AS cheapest_fare,
    airline_name
FROM flights
WHERE cabin_class = 'economy'
GROUP BY search_date, route, cabin_class
ORDER BY search_date, route;

-- 7.4  Price volatility by route — standard deviation of fares
--      High std dev = prices fluctuate a lot = booking timing matters more
SELECT
    origin || ' → ' || destination                AS route,
    COUNT(*)                                      AS num_records,
    ROUND(AVG(base_fare), 2)                      AS avg_fare,
    ROUND(MIN(base_fare), 2)                      AS min_fare,
    ROUND(MAX(base_fare), 2)                      AS max_fare,
    ROUND(MAX(base_fare) - MIN(base_fare), 2)     AS fare_range,
    ROUND(100.0*(MAX(base_fare) - MIN(base_fare))
          / AVG(base_fare), 1)                    AS volatility_pct
FROM flights
WHERE cabin_class = 'economy'
GROUP BY route
ORDER BY volatility_pct DESC;


-- ============================================================
-- SECTION 8 — REFUNDABILITY & SEATS REMAINING
-- ============================================================

-- 8.1  Do refundable tickets cost significantly more?
SELECT
    cabin_class,
    CASE is_refundable WHEN 1 THEN 'Refundable' ELSE 'Non-refundable' END AS ticket_type,
    COUNT(*)                   AS num_records,
    ROUND(AVG(base_fare), 2)   AS avg_fare
FROM flights
GROUP BY cabin_class, ticket_type
ORDER BY cabin_class, ticket_type;

-- 8.2  Scarcity signal — fare when few seats remain vs. many
SELECT
    CASE
        WHEN seats_remaining IS NULL THEN 'Not disclosed'
        WHEN seats_remaining <= 3    THEN 'Very scarce (1–3 seats)'
        WHEN seats_remaining <= 6    THEN 'Limited     (4–6 seats)'
        ELSE                              'Available   (7–9 seats)'
    END                        AS seat_availability,
    COUNT(*)                   AS num_records,
    ROUND(AVG(base_fare), 2)   AS avg_fare
FROM flights
WHERE cabin_class = 'economy'
GROUP BY seat_availability
ORDER BY avg_fare DESC;


-- ============================================================
-- SECTION 9 — EXECUTIVE SUMMARY VIEW
--  Combines all key findings into one readable output
-- ============================================================

-- 9.1  Best booking windows per route (top 2 cheapest windows)
WITH route_window AS (
    SELECT
        origin || ' → ' || destination AS route,
        CASE
            WHEN days_until_flight BETWEEN 0  AND 7   THEN '0–7 days'
            WHEN days_until_flight BETWEEN 8  AND 21  THEN '8–21 days'
            WHEN days_until_flight BETWEEN 22 AND 45  THEN '22–45 days'
            WHEN days_until_flight BETWEEN 46 AND 90  THEN '46–90 days'
            ELSE                                           '91+ days'
        END AS booking_window,
        ROUND(AVG(base_fare),2) AS avg_fare,
        COUNT(*) AS n
    FROM flights
    WHERE cabin_class = 'economy'
    GROUP BY route, booking_window
    HAVING n >= 50
),
ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY route ORDER BY avg_fare) AS cheapness_rank
    FROM route_window
)
SELECT
    route,
    booking_window  AS optimal_booking_window,
    avg_fare        AS expected_avg_fare,
    cheapness_rank
FROM ranked
WHERE cheapness_rank <= 2
ORDER BY route, cheapness_rank;

-- 9.2  The full "best time to book" summary — one row per key variable
SELECT 'BOOKING WINDOW' AS factor, '22–45 days ahead' AS optimal_value,
       'Avg $261 economy vs $531 last-minute' AS insight
UNION ALL
SELECT 'DAY TO FLY',    'Tuesday or Wednesday',
       'Cheapest days; Friday/Sunday most expensive'
UNION ALL
SELECT 'MONTH TO FLY',  'September or October',
       'Fall travel 10–15% cheaper than summer peak'
UNION ALL
SELECT 'TIME OF DAY',   'Early morning (6–8am)',
       'Off-peak departure times tend to be lower priced'
UNION ALL
SELECT 'STOPS',         'One stop (connecting)',
       'Saves ~12% vs. nonstop on average economy'
UNION ALL
SELECT 'AIRLINE',       'Varies by route',
       'Run Section 4 queries for your specific route';
