# ✈️ Flight Price Analysis — When Is the Best Time to Book?

A SQL-based exploratory data analysis project examining flight pricing patterns to answer one practical question: **when should you book to get the best fare?**

---

## 📌 Project Overview

This project analyzes 50,000 one-way flight price observations across 10 major routes to identify the optimal booking window, day of week, season, and departure time for the lowest fares. The analysis is structured as a series of progressive SQL queries moving from basic exploration to advanced window functions.

**Key finding:** Booking **22–45 days before departure** yields average economy fares ~51% cheaper than last-minute bookings (0–7 days).

---

## 📂 Repository Structure

```
flight-price-analysis/
│
├── analysis.sql          # All SQL queries — 9 sections, fully commented
├── flight_prices.csv     # Dataset (50,000 rows)
├── flight_prices.db      # SQLite database (ready to query)
└── README.md             # This file
```

---

## 🗄️ Data Source

**Dataset modelled on:** [`dilwong/FlightPrices`](https://www.kaggle.com/datasets/dilwong/flightprices) (Kaggle)

The original dataset contains real one-way flight prices scraped from **Expedia** between **April 16 – October 5, 2022**. The dataset in this project preserves the same schema, column definitions, pricing relationships, and statistical distributions as the source data. Pricing behaviour (advance booking curves, day-of-week patterns, seasonal peaks) is calibrated to match documented airline pricing research.

**Original data columns reproduced:**
- `search_date` — date the price was observed on Expedia
- `departure_date` — scheduled flight departure date
- `days_until_flight` — days between search and departure (derived)
- `origin` / `destination` — IATA airport codes
- `airline_name` / `airline_code`
- `cabin_class` — economy, premium economy, business, first
- `num_stops` / `is_nonstop`
- `base_fare` — one-way ticket price in USD
- `is_refundable`
- `seats_remaining`

**Routes covered:**

| Route | Cities |
|-------|--------|
| YYC → YYZ | Calgary → Toronto |
| YYC → YVR | Calgary → Vancouver |
| YYC → YUL | Calgary → Montreal |
| YYZ → LAX | Toronto → Los Angeles |
| YYZ → JFK | Toronto → New York |
| YYZ → LHR | Toronto → London |
| YVR → SFO | Vancouver → San Francisco |
| YVR → NRT | Vancouver → Tokyo |
| YUL → CDG | Montreal → Paris |
| YYC → ORD | Calgary → Chicago |

---

## 🛠️ How to Run

### Option 1 — SQLite (easiest, no setup)
```bash
# Open the database directly
sqlite3 flight_prices.db

# Run the full analysis
.read analysis.sql
```

### Option 2 — DuckDB (recommended for performance)
```bash
pip install duckdb
duckdb

-- Inside DuckDB
CREATE TABLE flights AS SELECT * FROM read_csv_auto('flight_prices.csv');
.read analysis.sql
```

### Option 3 — Load CSV into PostgreSQL
```sql
CREATE TABLE flights (
    flight_id            SERIAL PRIMARY KEY,
    search_date          DATE,
    departure_date       DATE,
    days_until_flight    INTEGER,
    origin               VARCHAR(4),
    destination          VARCHAR(4),
    origin_city          TEXT,
    destination_city     TEXT,
    airline_code         VARCHAR(4),
    airline_name         TEXT,
    cabin_class          TEXT,
    num_stops            INTEGER,
    is_nonstop           BOOLEAN,
    departure_time       TIME,
    departure_hour       INTEGER,
    departure_dow        TEXT,
    departure_month      INTEGER,
    departure_month_name TEXT,
    base_fare            NUMERIC(10,2),
    is_refundable        BOOLEAN,
    seats_remaining      INTEGER
);

\COPY flights FROM 'flight_prices.csv' CSV HEADER;
```

---

## 🔍 Analysis Sections

| Section | Topic | Key Technique |
|---------|-------|---------------|
| 0 | Data exploration & quality | Aggregations, null checks |
| 1 | **Advance booking window** | CASE bucketing, CTEs, savings calc |
| 2 | Day-of-week effects | GROUP BY, RANK() window function |
| 3 | Seasonal & monthly trends | Month aggregation, CASE seasons |
| 4 | Airline comparison | Conditional aggregation (CASE+AVG) |
| 5 | Departure time analysis | Hour bucketing, RANK() |
| 6 | Cabin class & stops | Multi-dimension aggregation |
| 7 | **Advanced window functions** | PERCENT_RANK, rolling averages, ROW_NUMBER |
| 8 | Refundability & scarcity signals | Conditional aggregation |
| 9 | Executive summary | UNION ALL, CTE + RANK() |

---

## 📊 Key Findings

### 1. Booking Window is the Biggest Driver of Price

| Days Before Flight | Avg Economy Fare | vs. Last-Minute |
|--------------------|-----------------|-----------------|
| 0–7 days (last-minute) | $531 | baseline |
| 8–21 days | $340 | **-36%** |
| **22–45 days ✓ sweet spot** | **$261** | **-51%** |
| 46–90 days | $276 | -48% |
| 91+ days | $299 | -44% |

**Book 22–45 days ahead** for the lowest fares. Prices rise sharply after that and spike heavily inside 7 days.

### 2. Day of Week Matters

Cheapest departure days: **Tuesday and Wednesday**
Most expensive: **Friday and Sunday** (peak business/leisure travel)

### 3. Avoid Summer — Fly in Fall

| Season | Avg Economy Fare |
|--------|-----------------|
| Summer (Jun–Aug) | Highest |
| Winter (Dec) | High (holiday peak) |
| **Fall (Sep–Oct) ✓** | **Lowest** |
| Spring (Mar–May) | Moderate |

### 4. Nonstop vs. Connecting

Connecting flights average **~12% cheaper** than nonstop on economy class. The premium is highest on international routes.

### 5. Early Morning Flights Are Cheaper

Flights departing 6–8am tend to have lower average fares than midday or evening departures.

---

## 💡 SQL Concepts Demonstrated

- `GROUP BY` with multi-column aggregations
- `CASE WHEN` bucketing for custom segments
- Common Table Expressions (`WITH` / CTEs)
- Window functions: `RANK()`, `PERCENT_RANK()`, `ROW_NUMBER()`, `FIRST_VALUE()`
- Rolling averages with `ROWS BETWEEN N PRECEDING AND CURRENT ROW`
- `HAVING` clauses for post-aggregation filtering
- Self-joins via CTEs for savings calculations
- `UNION ALL` for summary output formatting
- Conditional aggregation: `AVG(CASE WHEN ... THEN ... END)`

---

## 👤 Author

**Joseph Ogunleye**
Financial Data Analyst | MSc Data Science & Analytics, University of Calgary

[LinkedIn](https://www.linkedin.com/in/joseph-ogunleye/) · [GitHub](https://github.com/josepho8) · [Portfolio](https://josepho8.github.io)

---

## 📄 License

This project is for portfolio and educational purposes. The dataset schema is modelled on publicly available Kaggle data — see [dilwong/FlightPrices](https://www.kaggle.com/datasets/dilwong/flightprices) for the original source.
