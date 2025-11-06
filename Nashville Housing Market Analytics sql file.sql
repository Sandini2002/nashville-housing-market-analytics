--create table--
CREATE TABLE housing (
    "id" INT,
    "Unnamed: 0" INT,
    "Parcel ID" TEXT,
    "Land Use" TEXT,
    "Property Address" TEXT,
    "Suite/ Condo   #" TEXT,
    "Property City" TEXT,
    "Sale Date" TEXT,
    "Sale Price" NUMERIC,
    "Legal Reference" TEXT,
    "Sold As Vacant" TEXT,
    "Multiple Parcels Involved in Sale" TEXT,
    "Owner Name" TEXT,
    "Address" TEXT,
    "City" TEXT,
    "State" TEXT,
    "Acreage" NUMERIC,
    "Tax District" TEXT,
    "Neighborhood" TEXT,
    "image" TEXT,
    "Land Value" NUMERIC,
    "Building Value" NUMERIC,
    "Total Value" NUMERIC,
    "Finished Area" NUMERIC,
    "Foundation Type" TEXT,
    "Year Built" INT,
    "Exterior Wall" TEXT,
    "Grade" TEXT,
    "Bedrooms" INT,
    "Full Bath" INT,
    "Half Bath" INT
);
--count--
SELECT COUNT(*) FROM housing;

-- inspect first
SELECT "Sale Date" FROM housing LIMIT 5;

-- if format like 2013-01-24 => cast directly
-- if like 01/24/2013 use to_date with 'MM/DD/YYYY'
ALTER TABLE housing ADD COLUMN sale_date_date DATE;
UPDATE housing
SET sale_date_date = COALESCE(
    NULLIF("Sale Date",'')::DATE,
    to_date("Sale Date",'MM/DD/YYYY')
);

-- optional: keep only rows with valid date
--Normalize “Sold As Vacant” → Y/N--
ALTER TABLE housing ADD COLUMN sold_vacant_yn CHAR(1);

UPDATE housing
SET sold_vacant_yn = CASE
  WHEN UPPER("Sold As Vacant") IN ('Y','YES','TRUE') THEN 'Y'
  WHEN UPPER("Sold As Vacant") IN ('N','NO','FALSE') THEN 'N'
  ELSE NULL
END;
--Remove duplicates--
DROP TABLE IF EXISTS housing_clean;

CREATE TABLE housing_clean AS
SELECT *
FROM (
  SELECT h.*,
         ROW_NUMBER() OVER (
            PARTITION BY "Parcel ID", sale_date_date, "Sale Price"
            ORDER BY "Sale Price" DESC
         ) AS rn
  FROM housing h
) t
WHERE rn = 1;

SELECT COUNT(*) FROM housing_clean;

---Analytics part--
--1.Transactions by Year--
SELECT EXTRACT(YEAR FROM sale_date_date)::INT AS year,
       COUNT(*) AS transactions
FROM housing_clean
WHERE sale_date_date IS NOT NULL
GROUP BY year
ORDER BY year;

--2.Median Sale Price by Year--
SELECT EXTRACT(YEAR FROM sale_date_date)::INT AS year,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY "Sale Price") AS median_sale_price
FROM housing_clean
WHERE sale_date_date IS NOT NULL
GROUP BY year
ORDER BY year;

--Top 10 Neighborhoods by Median Price (min 50 sales — to avoid noise)--
SELECT "Neighborhood",
       COUNT(*) AS sales,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY "Sale Price")::NUMERIC,2) AS median_price
FROM housing_clean
GROUP BY "Neighborhood"
HAVING COUNT(*) >= 50
ORDER BY median_price DESC
LIMIT 10;

--views--
CREATE OR REPLACE VIEW vw_yearly_sales AS
SELECT EXTRACT(YEAR FROM sale_date_date)::INT AS year,
       COUNT(*) AS transactions
FROM housing_clean
WHERE sale_date_date IS NOT NULL
GROUP BY year
ORDER BY year;

CREATE OR REPLACE VIEW vw_yearly_median_price AS
SELECT EXTRACT(YEAR FROM sale_date_date)::INT AS year,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY "Sale Price") AS median_sale_price
FROM housing_clean
WHERE sale_date_date IS NOT NULL
GROUP BY year
ORDER BY year;

CREATE OR REPLACE VIEW vw_top_neighborhoods AS
SELECT "Neighborhood",
       COUNT(*) AS sales,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY "Sale Price") AS median_price
FROM housing_clean
GROUP BY "Neighborhood"
HAVING COUNT(*) >= 50
ORDER BY median_price DESC
LIMIT 10;









