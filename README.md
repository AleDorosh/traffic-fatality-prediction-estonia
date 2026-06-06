# Predicting Traffic Accident Fatality in Estonia

Can a model trained only on urban accidents predict whether a rural crash will be fatal?  
That's the core question this project tries to answer.

---

## What this is

A binary classification project predicting whether a traffic accident results in a fatality (fatal / non-fatal), built on Estonian road accident data from [andmed.eesti.ee](https://andmed.eesti.ee). The main modelling goal is also a **distribution shift experiment**: train on urban accidents, test on rural and national data, and see how far the predictions hold up.

Built as a portfolio project and 5-minute presentation piece. Follows on from a prior road width analysis on the same dataset.

---

## The dataset split (by design, not randomly)

| Split | N accidents | Deaths | Fatality rate | Purpose |
|---|---|---|---|---|
| Urban train | 3,533 | 67 | 1.9% | Training set |
| Urban holdout | ~700 | ~13 | ~1.9% | Same-distribution baseline |
| Rural test | 3,610 | 292 | 8.1% | Out-of-distribution test |
| National test | 7,160 | 356 | 5.0% | Blended real-world test |

Urban and rural sets are confirmed disjoint (zero overlapping `accident_id`s). The prior probability shift between sets (1.9% → 8.1%) is intentional — it's the thing being studied, not a flaw to correct.

---

## Repo structure

```
traffic-accident-severity-estonia/
│
├── sql/
│   ├── urban_filter.sql       # Training set: 14 Estonian cities, 2018–2025
│   ├── rural_filter.sql       # OOD test: non-urban, state road types only
│   └── national_filter.sql    # Blended test: all Estonia
│
├── notebooks/
│   ├── 01_eda_urban.ipynb
│   ├── 02_features.ipynb
│   ├── 03_baseline_logreg.ipynb
│   ├── 04_random_forest.ipynb
│   ├── 05_distribution_shift.ipynb
│   └── 06_xgboost.ipynb       # stretch goal
│
├── outputs/
│   ├── figures/               # All saved plots
│   └── models/                # Saved .pkl model files
│
├── data_sources.md            # Links to source data (raw CSVs not tracked)
└── README.md
```

Raw data files are excluded from version control (see `.gitignore`). Source and download instructions are in `data_sources.md`.

---

## Models

| Model | Role |
|---|---|
| Logistic Regression | Baseline — interpretable, fast, sets the floor |
| Random Forest | Main model — handles non-linearity, gives feature importances |
| K-Means (GPS coords → cluster ID) | Feature engineering step feeding into the above |
| XGBoost | Stretch goal (Day 6) |

---

## Key methodological decisions

**Outlier handling is context-specific.** Physically implausible pedestrian injury counts were removed from the urban training set. High-injury counts in rural data were retained (plausible for bus/van crashes on highways) but flagged with a binary `is_outlier` feature. `road_width = 35` was removed from all sets as a data entry error regardless of context.

**Speed limits 90/110 are kept in rural data.** They represent genuine distribution shift, not errors, and are part of what makes rural data rural.

**Prior probability shift is reported, not hidden.** Metrics are reported with and without threshold recalibration. Precision-recall curves alongside ROC, because with 1.9% fatality rate in training, accuracy is basically meaningless.

---

## Presentation

9 slides, ~5 minutes, mixed audience (technical and non-technical).

> *Hook: 67 deaths in 3,500 urban accidents — can a model learn to predict them, and does that learning transfer to rural roads where the rate is 4× higher?*

Arc: hook → data setup → features → accident hotspot map → models → results → transfer test → ethics → future work.

---

## Data sources

See `data_sources.md`. Data is from the Estonian Road Administration via the open data portal [andmed.eesti.ee](https://andmed.eesti.ee). Not redistributed here.

---

## Stack

Python · DuckDB · pandas · scikit-learn · XGBoost · matplotlib / seaborn · Jupyter



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
