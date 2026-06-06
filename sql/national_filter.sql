-- national_filter.sql
-- Produces the cleaned national testing dataset from the raw accident export.
-- Input:  accidents_full (raw, with spatial join at 20m)
-- Output: national_filter (7,160 rows, 356 fatalities)
-- Dialect: DuckDB

CREATE TABLE national_filter AS
SELECT
-- accident identifiers
    "Juhtumi nr" AS accident_id,
    "Toimumisaeg" AS accident_time,
-- severity
    "Hukkunuid" AS deaths,
    "Vigastatuid" AS injured,
-- location
    "Maakond" AS county,
	"Omavalitsus" AS municipality,
    "Asustusüksus" AS settlement,
-- accident characteristics
    "Mootorsõidukijuhi osalusel" AS involving_motorvehicle_driver,
    "Liiklusõnnetuse liik" AS accident_type,
    "Liiklusõnnetuse liik (detailne)" AS accident_type_detailed,
    "Tüüpskeem" AS accident_scenario,
-- road characteristics
    "Tee tüüp" AS road_type,
    "Tee tüüp (detailne)" AS road_type_detailed,
    road_width,
    "Lubatud sõidukiirus" AS speed_limit,
-- environment
    "Tee seisund" AS road_condition,
    "Teekatte seisund" AS road_surface_condition,
    "Ilmastik" AS weather,
    "Valgustus" AS lighting,
    
    distance AS join_distance,
    "X koordinaat" AS x_coord,
	  "Y koordinaat" AS y_coord
FROM accidents_full
WHERE 
-- Filter out joins with a distance greater than 15 m
distance <= 15
-- Set analysis period to 2018–2025
AND "Toimumisaeg" >= '2018-01-01' 
AND "Toimumisaeg" <  '2026-01-01'
-- Retain only accidents where vehicles are directly involved
AND "Liiklusõnnetuse liik" IN (
'Ühesõidukiõnnetus', 
'Kokkupõrge', 
'Jalakäijaõnnetus'
)
AND "Mootorsõidukijuhi osalusel" = TRUE
-- Exclude non-standard road traffic environments
AND "Tee tüüp (detailne)" NOT IN (
'Parkla', 'Metsatee', 'Muu koht', 'Väljak',
'Jalg- ja jalgrattatee', 'Jalgrattatee', 'Jalgtee'
)
-- Keep only roads with width greater than 3 m 
AND road_width >= 3;

-- Step 1: Remove duplicate accident IDs from spatial join multi-match
DELETE FROM national_filter
WHERE accident_id IN (
    SELECT accident_id FROM national_filter
    GROUP BY accident_id HAVING COUNT(*) > 1
);
SELECT 'After dedup: ' || COUNT(*) FROM national_filter;

-- Step 2: Remove rows missing speed_limit (non-negotiable feature)
DELETE FROM national_filter 
WHERE speed_limit IS NULL;
SELECT 'After speed_limit NULL drop: ' || COUNT(*) FROM national_filter;

-- Step 3: Remove all rows where more > 1 value is NULL
DELETE FROM national_filter
WHERE 
(accident_scenario IS NULL)::INT + (road_condition IS NULL)::INT +
(road_surface_condition IS NULL)::INT + (weather IS NULL)::INT + (lighting IS NULL)::INT +
(speed_limit IS NULL)::INT > 1;
SELECT 'After > 1 NULL drop: ' || COUNT(*) FROM national_filter;

-- Replace NULL values in secondary columns with UNKNOWN
UPDATE national_filter
SET 
    accident_scenario = COALESCE(accident_scenario, 'Unknown'),
    road_condition = COALESCE(road_condition, 'Unknown'),
    road_surface_condition = COALESCE(road_surface_condition, 'Unknown'),
    weather = COALESCE(weather, 'Unknown'),
    lighting = COALESCE(lighting, 'Unknown');


-- Flag only the physically implausible cases
-- A pedestrian accident injuring 7+ people is implausible
-- A highway collision injuring 20+ is plausible but worth flagging
ALTER TABLE national_filter ADD COLUMN outlier_flag BOOLEAN DEFAULT FALSE;

UPDATE national_filter SET outlier_flag = TRUE
WHERE (injured >= 7 AND accident_type = 'Jalakäijaõnnetus')
OR injured >= 20;

-- Remove unrealistic values
DELETE
FROM national_filter
WHERE road_width = 35;
SELECT 'After unrealistic value drop: ' || COUNT(*) FROM national_filter;

-- Replace Pole teada, Teadmata etc values in secondary columns with UNKNOWN
UPDATE national_filter
SET accident_scenario = 'Unknown'
WHERE accident_scenario = 'Tundmatu liikluskonflikt.';

UPDATE national_filter
SET lighting = 'Unknown'
WHERE lighting = 'Teadmine puudub';

UPDATE national_filter
SET road_condition = 'Unknown'
WHERE road_condition = 'Teadmine puudub';

UPDATE national_filter
SET road_surface_condition = 'Unknown'
WHERE road_surface_condition = 'Pole teada';

UPDATE national_filter
SET weather = 'Unknown'
WHERE weather = 'Pole teada';

-- Check if all rows were imported
SELECT COUNT(*)
FROM national_filter;

SELECT *
FROM national_filter
LIMIT 200;
