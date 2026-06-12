# Predicting Traffic Accident Fatality in Estonia

Can a model trained only on urban accidents predict whether a rural crash will be fatal?  
That is the core question this project tries to answer.

---

## What this is

A binary classification project predicting whether a traffic accident results in a fatality, built on Estonian road accident data from [andmed.eesti.ee](https://andmed.eesti.ee). The main modelling goal is also a **distribution shift experiment**: train on urban accidents, test on rural, and measure how far the predictions hold up.

Built as a portfolio project. Follows on from a prior road width spatial analysis on the same dataset.

---

## The experiment design

The train/test split is geographic, not random. The model is trained on accidents from 14 Estonian urban settlements and tested on rural areas it has never seen.

| Set | Rows | Fatal accidents | Fatality rate | Role |
|---|---|---|---|---|
| Urban | 3,544 | 64 | 1.81% | Train |
| Rural (speed < 90 km/h) | 1,421 | 70 | 4.93% | Test (OOD) |
| National | 7,178 | 357 | 4.97% | Feasibility ceiling |

The prior probability shift between train and test (1.81% → 4.93%) is intentional — it is the thing being studied, not a flaw to correct. Urban and rural sets are confirmed disjoint (zero overlapping `accident_id`s).

The rural set excludes speed limits ≥ 90 km/h to remove highways, which represent a third distinct context not part of this experiment.

---

## Results

| Experiment | Train fatal | Test fatal | ROC-AUC | Recall |
|---|---|---|---|---|
| Urban → Rural | 64 | 70 | 0.635 | 0.500 |
| Rural → Urban (flipped) | 70 | 64 | 0.733 | 0.641 |
| National baseline (LR) | 286 | 71 | 0.780 | — |

**Key findings:**

- Distribution shift confirmed — urban → rural ROC-AUC drops 0.058 vs urban validation (0.691)
- The experiment is asymmetric — rural → urban achieves better AUC, suggesting rural features generalise more readily to urban than the reverse
- The urban-calibrated threshold does not transfer to rural — rural fatal cases receive lower predicted probabilities due to distribution shift, so recall falls when the urban threshold is applied
- The national baseline (ROC-AUC 0.780 with 357 fatal cases) confirms data volume was the primary constraint — the features carry real signal, 64 training fatals is simply too few to learn generalisable patterns
- Random Forest and XGBoost were evaluated but rejected — both fail to meaningfully separate fatal from non-fatal probability distributions on this dataset

**Final model:** Logistic Regression with `class_weight='balanced'`

---

## Repo structure

```
traffic-fatality-prediction-estonia/
│
├── data/
│   ├── map_preview.png
│   └── raw_data_sample.csv
│
├── sql/
│   ├── urban_setr.sql        # Training set: 14 Estonian cities, 2018-2025
│   ├── rural_set.sql        # Test set: rural areas, speed < 90 km/h
│   └── national_set.sql     # Feasibility set: all Estonia
│
├── notebook/
│   ├── 01_eda_urban_rural.ipynb       # Side-by-side EDA: urban vs rural
│   ├── 02_feature_engineering_urban.ipynb   # Feature engineering: urban training set
│   ├── 03_modelling_urban.ipynb       # LR and RF on urban, threshold calibration
│   ├── 04_evaluation.ipynb            # Urban → rural evaluation
│   ├── 05_flipped_experiment.ipynb    # Rural → urban (flipped)
│   └── 06_national_baseline.ipynb     # National feasibility baseline
│
├── fetch_weather.py    # ERA5 weather API fetch (excluded from final model)
├── results.md          # Full results table
└── README.md
```

Raw data files are not tracked. See **Data sources** below.

---

## Features

| Feature | Type | Notes |
|---|---|---|
| `speed_limit` | Numeric | Remapped to valid bins (20/30/40/50/70/90) |
| `road_width_bin` | OHE | narrow / standard / wide / arterial |
| `hour_bin` | OHE | night / rush / evening / day |
| `is_weekend` | Binary | |
| `accident_type` | OHE | 3 categories |
| `accident_type_detailed` | OHE | ~10 subtypes |
| `road_condition` | OHE | |
| `lighting` | OHE | |
| `weather` | OHE | Estonian categorical from Maanteamet |
| `no_safety_equipment` | Binary | Participation flag |
| `motorcyclist` | Binary | Participation flag |
| `pedestrian` | Binary | Participation flag |
| `elderly_driver` | Binary | Participation flag (65+) |
| `underage` | Binary | Participation flag |

**Dropped:** `settlement` (549 unique rural values, all map to zero when aligned to urban columns), weather API columns (ERA5 — no improvement in experiments), GPS coordinates, admin identifiers, leakage columns (`deaths`, `injured`).

---

## Methodological notes

**OHE fit on urban, applied to rural.** Rural categories not seen in urban training become all-zero columns. This is the correct behaviour for distribution shift evaluation — the model is genuinely blind to rural-specific road contexts.

**Threshold calibration does not transfer.** The threshold optimised on urban validation (F1-maximising) is too conservative for rural data. Both default and recalibrated threshold results are reported in notebook 04.

**drunk driver data absent.** The `Joobes juht` column was present in earlier Maanteamet releases but has since been removed. This is a known gap.

**Highway segment not modelled.** Accidents with speed limit ≥ 90 km/h (~2,200 rows, ~10% fatality rate) represent a third distinct context excluded from this experiment.

---

## Data sources

Data is from the Estonian Road Administration (Maanteamet) via the open data portal [andmed.eesti.ee](https://andmed.eesti.ee). Road geometry data was joined spatially using the Estonian road registry. Raw CSVs are not redistributed here.

Weather data was fetched from the ERA5 reanalysis API via `fetch_weather.py` but excluded from the final model after showing no improvement.

---

## Stack

Python · DuckDB · pandas · scikit-learn · matplotlib / seaborn · Jupyter
