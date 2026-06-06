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

"Before we look at model performance — just look at the fatality rates. Urban: 1.9%. Rural: 8.1%. National: 5.0%. The model was trained on the left bar. The question is whether it understands the right one."
rain:      urban_filter     (3,533 accidents, 1.9% fatal)
    |
    ├── Test A: urban holdout    (80/20 split of urban, same distribution)
    ├── Test B: rural_filter     (3,610 accidents, 8.1% fatal — OOD)
    └── Test C: national_filter  (7,160 accidents, 5.0% fatal — blended OOD)
