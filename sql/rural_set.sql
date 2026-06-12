-- rural_set.sql
-- Produces the cleaned rural testing dataset from the raw accident export.
-- Input:  accidents_full (raw, with spatial join at 20m)
-- Output: rural_set (1421 rows, 72 fatalities)
-- Dialect: DuckDB

CREATE TABLE rural_set AS
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
-- participation flags
    "Turvavarustust mitte kasutanud isiku osalusel" AS no_safety_equipment,
    "Mootorratturi osalusel" AS motorcyclist,
    "Jalakäija osalusel" AS pedestrian,
    "Eaka (65+) mootorsõidukijuhi osalusel" AS elderly_driver,
    "Alaealise osalusel" AS underage,
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
-- Include only urban traffic environments with pop greater than 10k
AND "Asustusüksus" NOT IN (
'Kesklinna linnaosa', 'Lasnamäe linnaosa', 'Põhja-Tallinna linnaosa', 
'Mustamäe linnaosa', 'Haabersti linnaosa' , 'Kristiine linnaosa', 
'Nõmme linnaosa','Pirita linnaosa',  
'Tartu linn', 'Narva linn', 'Pärnu linn', 
'Järve linnaosa', 'Ahtme linnaosa', 'Viljandi linn', 
'Maardu linn', 'Rakvere linn', 'Kuressaare linn', 
'Sillamäe linn', 'Võru linn', 'Valga linn', 'Keila linn', 'Jõhvi linn'
)
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
-- Keep only roads with width greater than 3 m and smaller than 35m
AND road_width >= 3
AND road_width < 35
-- Keep speed limit under 90km/h
AND speed_limit < 90;

-- Step 1: Remove duplicate accident IDs from spatial join multi-match
DELETE FROM rural_set
WHERE accident_id IN (
    SELECT accident_id FROM rural_set
    GROUP BY accident_id HAVING COUNT(*) > 1
);
SELECT 'After dedup: ' || COUNT(*) FROM rural_set;

-- Step 2: Remove rows missing speed_limit (non-negotiable feature)
DELETE FROM rural_set 
WHERE speed_limit IS NULL;
SELECT 'After speed_limit NULL drop: ' || COUNT(*) FROM rural_set;

-- Step 3: Remove all rows where more > 3 value is NULL
DELETE FROM rural_set
WHERE 
(accident_scenario IS NULL)::INT + (road_condition IS NULL)::INT +
(road_surface_condition IS NULL)::INT + (weather IS NULL)::INT + (lighting IS NULL)::INT +
(speed_limit IS NULL)::INT > 3;
SELECT 'After > 1 NULL drop: ' || COUNT(*) FROM rural_set;

-- Replace NULL values in secondary columns with UNKNOWN
UPDATE rural_set
SET 
    accident_scenario = COALESCE(accident_scenario, 'Unknown'),
    road_condition = COALESCE(road_condition, 'Unknown'),
    road_surface_condition = COALESCE(road_surface_condition, 'Unknown'),
    weather = COALESCE(weather, 'Unknown'),
    lighting = COALESCE(lighting, 'Unknown');

-- Replace Pole teada, Teadmata etc values in secondary columns with UNKNOWN
UPDATE rural_set
SET accident_scenario = 'Unknown'
WHERE accident_scenario = 'Tundmatu liikluskonflikt.';

UPDATE rural_set
SET lighting = 'Unknown'
WHERE lighting = 'Teadmine puudub';

UPDATE rural_set
SET road_condition = 'Unknown'
WHERE road_condition = 'Teadmine puudub';

UPDATE rural_set
SET road_surface_condition = 'Unknown'
WHERE road_surface_condition = 'Pole teada';

UPDATE rural_set
SET weather = 'Unknown'
WHERE weather = 'Pole teada';

-- Step 6. Check if all rows were imported
SELECT 
	COUNT(*) AS rows,
 	SUM(deaths) AS fatalities
FROM rural_set;

