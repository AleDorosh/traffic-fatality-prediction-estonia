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


    his is a clean, well-motivated design with a clear narrative progression — each test set is progressively further from the training distribution. That's actually a recognised evaluation pattern in ML called distribution shift analysis and worth naming as such in your report and README. It elevates the project from "I trained a classifier" to "I systematically evaluated how performance degrades under distribution shift."
One thing to flag for your Python notebook — when you evaluate on rural and national, report metrics both with and without recalibrating the decision threshold. Your model will be calibrated to ~2% fatality rate, so the default 0.5 threshold will almost certainly underpredict fatalities on rural data. Adjusting the threshold to match the rural prior (or using a precision-recall curve rather than ROC) will give a fairer picture of whether the features transfer, separate from the calibration problem.
