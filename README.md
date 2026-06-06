# traffic-accident-severity-estonia-
Estonia has detailed records of every traffic accident with casualty. I trained a machine learning model on urban accidents. My question was, does it still work on roads it's never seen?

"Data cleaning was implemented in DuckDB SQL rather than pandas to keep the transformation logic explicit, version-controlled, and reproducible without a running database server." 

"To prevent distribution leakage, the global test set explicitly excludes the 14 urban settlements used during training. The test set therefore represents rural roads, highways, and smaller settlements — environments the model was never trained on."

-- Set 1: urban_train (your existing script, 2018-2025, 14 cities)

-- Set 2: rural_test
-- Same filters EXCEPT: exclude 14 cities, exclude highways maybe?
-- Keep speed 90/110 here — that's what makes it rural

-- Set 3: national_test  
-- No location filter at all — full Estonia
-- This is urban + rural combined, so it's a superset check
