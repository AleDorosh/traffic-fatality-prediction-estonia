# Results: Traffic Accident Fatality Prediction in Estonia

## Overview

This project trains a binary classifier to predict whether a traffic accident results in a fatality, using Estonian accident data from 2018–2025. The core experiment is a **distribution shift test**: train on urban accidents, evaluate on rural accidents — two contexts with meaningfully different road conditions, speeds, and fatality rates.

---

## Data

All data sourced from the Estonian Road Administration (Maanteeamet) accident registry. The dataset covers motor-vehicle-involved accidents only.

| Split | Context | Accidents | Fatal | Fatality Rate |
|---|---|---|---|---|
| Train | Urban (14 settlements) | 3,533 | 64 | 1.84% |
| Test | Truly rural (speed < 90 km/h) | 1,414 | 70 | 4.95% |

The original "rural" filter (everything outside the 14 urban settlements) contained 3,610 accidents but was dominated by intercity highways — 60% of rows had a speed limit of 90 km/h or above. These were removed to create a truly rural test set representing country roads and small settlements. The highway segment (speed ≥ 90, n=2,196, 222 fatal, ~10% fatality rate) was excluded from the main experiment.

A national dataset (urban + rural combined) was initially considered as a second test set but excluded — it overlaps with the training data and would produce artificially inflated results.

---

## Features

Raw data contained 22 columns. After feature engineering and dropping leakage-prone or low-variance columns, the final feature matrix contained the following:

| Feature | Type | Notes |
|---|---|---|
| `speed_limit` | Numeric | Edge values (5, 10, 25 km/h) remapped to 30 |
| `road_width_bin` | One-hot | 4 bins: narrow (3–5m), standard (6–9m), wide (10–14m), arterial (15m+) |
| `hour_bin` | One-hot | night (22–05), rush (07–09, 15–18), evening (19–21), day |
| `is_weekend` | Binary | 1 = Saturday or Sunday |
| `accident_type` | One-hot | Broad accident category |
| `accident_type_detailed` | One-hot | Detailed accident category |
| `road_condition` | One-hot | Dry, wet, icy, etc. |
| `lighting` | One-hot | Daylight, artificial, darkness |
| `settlement` | One-hot | Urban sub-area (district/town) |
| `no_safety_equipment` | Binary | Safety equipment not used (seatbelt, helmet, reflector) |
| `motorcyclist` | Binary | Motorcyclist involved |
| `pedestrian` | Binary | Pedestrian involved |
| `elderly_driver` | Binary | Driver aged 65+ involved |
| `underage` | Binary | Underage person involved |
| `precipitation` | Numeric | mm/hour — from Open-Meteo historical API |
| `temperature_2m` | Numeric | °C — from Open-Meteo historical API |
| `wind_speed_10m` | Numeric | km/h — from Open-Meteo historical API |
| `snowfall` | Numeric | cm/hour — from Open-Meteo historical API |

**Dropped columns and reasons:**

- `deaths`, `injured` — direct leakage (they define the target)
- `road_type_detailed`, `road_surface_condition` — leakage risk / near-constant values
- `accident_scenario` — 65 unique text values, many appearing only once
- `road_type` — subsumed by `road_width_bin`
- `x_coord`, `y_coord` — raw GPS coordinates without a spatial feature to structure them
- `accident_id`, `accident_time`, `county`, `municipality` — identifiers and high-cardinality admin fields
- `involving_motorvehicle_driver` — zero variance across all datasets (motor vehicle involvement is a dataset filter)
- `weather` (categorical) — replaced by continuous Open-Meteo variables
- `visibility` — not available in Open-Meteo historical archive API

---

## Class Imbalance

At 1.84% fatality rate, the training set has approximately 1 fatal accident per 54 non-fatal. Standard accuracy is meaningless in this context — a model predicting "non-fatal" for every accident would score 98.2% accuracy while being completely useless.

All models used `class_weight='balanced'` (or equivalent) to penalise missed fatal predictions proportionally more than missed non-fatal predictions. Evaluation focused on ROC-AUC, PR-AUC, recall, and the confusion matrix rather than accuracy.

---

## Models Evaluated

Three models were trained and evaluated:

**Logistic Regression** — linear baseline. Sensitive to feature scale, so features were standardised (StandardScaler fit on training data only). Used `class_weight='balanced'`.

**Random Forest** — ensemble of 500 decision trees. Does not require scaling. Used `class_weight='balanced'`. **Failed** — probability analysis showed the model assigned lower average probabilities to fatal cases (mean 0.011) than to non-fatal cases (mean 0.022), meaning it learned nothing useful about the minority class. Ruled out.

**XGBoost** — gradient boosted trees, 500 estimators, `scale_pos_weight=54`. Showed marginal improvement in ranking metrics over Logistic Regression but caught fewer fatal accidents outright.

---

## Results

### Urban Validation (80/20 split, stratified)

Logistic Regression evaluated on the held-out 20% of urban data:

| Metric | Value |
|---|---|
| ROC-AUC | 0.691 |
| PR-AUC | 0.062 |
| Recall (fatal) | 0.769 |
| Precision (fatal) | 0.047 |

Confusion matrix:

|  | Predicted non-fatal | Predicted fatal |
|---|---|---|
| **Actual non-fatal** | 489 (TN) | 205 (FP) |
| **Actual fatal** | 3 (FN) | 10 (TP) |

The model caught 10 of 13 fatal accidents in the validation set, missing 3. The 205 false alarms reflect the aggressive class weighting needed to surface the minority class.

### Rural Test Set — Distribution Shift (Urban → Rural)

Both Logistic Regression and XGBoost retrained on the full urban set (no validation split) and evaluated on the truly rural test set (speed < 90):

| Model | ROC-AUC | PR-AUC | Recall | TP | FN |
|---|---|---|---|---|---|
| Logistic Regression | 0.604 | 0.083 | 0.529 | 37 | 33 |
| XGBoost | — | — | — | — | — |

**Final model: Logistic Regression.** The model catches 37 of 70 rural fatal accidents, missing 33. ROC-AUC degrades from 0.691 on urban validation to 0.604 on rural — a drop of 0.087 points reflecting the distribution shift between contexts.

---

## Distribution Shift Experiments

### Urban → Rural

ROC-AUC drops from 0.691 to 0.604. The model trained on urban patterns partially transfers to rural but loses discrimination ability. Rural accidents involve higher speeds, different road geometry, different lighting conditions, and different accident type distributions that the urban-trained model has not seen.

### Flipped Experiment: Rural → Urban

Training on rural (speed < 90, 70 fatal cases) and testing on urban (64 fatal cases) produced a striking asymmetry:

| Direction | ROC-AUC | Recall | TP | FN |
|---|---|---|---|---|
| Urban → Rural | 0.604 | 0.529 | 37 | 33 |
| Rural → Urban | 0.732 | 0.031 | 2 | 62 |

The rural-trained model achieves higher ROC-AUC (0.732) — better theoretical discrimination — but fails completely in practice. Even at a threshold of 0.01 it catches only 21 of 64 urban fatals. The model assigns low probabilities to urban accidents regardless of threshold, because it never learned the specific conditions that make urban accidents fatal.

**The experiment is not symmetric.** Urban patterns partially transfer to rural; rural patterns do not transfer to urban. This likely reflects the greater homogeneity of urban accidents — a narrower, more consistent set of conditions — which the rural model, trained on a more varied context, cannot reproduce.

---

## Extensions Attempted

Four extensions were implemented after the baseline. None produced meaningful gains in the primary metric.

**Participation flags.** Five binary columns added: no safety equipment used, motorcyclist involved, pedestrian involved, elderly driver (65+), underage person involved. Fatality rates for motorcyclist (3.91%) and no safety equipment (3.39%) were notably above the 1.84% baseline. Rural ROC-AUC unchanged.

**Accurate weather data.** The original categorical `weather` column (self-reported, high unknown rate) was replaced with four continuous variables from the Open-Meteo historical API: precipitation, temperature, wind speed, and snowfall, joined on GPS coordinates and accident hour. Fill rate was 99.2%. Rural ROC-AUC unchanged.

**XGBoost.** Marginal AUC improvement over Logistic Regression but lower recall — ruled out in favour of LR.

**Highway filtering.** Removing high-speed roads (≥ 90 km/h) from the rural test set reduced it from 3,610 to 1,414 rows and created a cleaner rural context. This is a data quality improvement rather than a performance improvement — it corrects a misleading framing of the original experiment.

The consistent failure to improve rural performance points to the fundamental constraint: **64 urban fatal training cases are insufficient** for a model to learn patterns that generalise across contexts. Better features cannot compensate for a minority class this small.

---

## Limitations

**Small fatal class.** Only 64 fatal accidents in the urban training set. This is the primary constraint on model performance and generalisability.

**Drunk driver data unavailable.** The drunk driver flag was present in the source data but missing from the processed dataset due to a data pipeline issue. This is likely a strong predictor of fatality and its absence is a gap in the feature set.

**No spatial features.** GPS coordinates were available but not used. K-Means clustering on accident locations was considered as a way to capture spatial hotspots but not implemented.

**Highway segment not analysed.** The 2,196 highway accidents (speed ≥ 90, ~10% fatality rate) were excluded from the main experiment. This is a third distinct context that could be studied separately.

---

## Notebooks

| Notebook | Contents |
|---|---|
| `01_eda_urban.ipynb` | Exploratory data analysis on urban training set |
| `02_feature_engineering.ipynb` | Feature construction, encoding, cleaning |
| `03_modelling.ipynb` | Logistic Regression and Random Forest training and evaluation |
| `03b_xgboost.ipynb` | XGBoost training and comparison against LR |
| `04_evaluation.ipynb` | Rural test set evaluation — urban → rural direction |
| `05_flipped_experiment.ipynb` | Flipped experiment — rural → urban direction |
| `fetch_weather.py` | Open-Meteo API weather enrichment script |
