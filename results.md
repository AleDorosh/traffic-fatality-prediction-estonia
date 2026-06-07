# Results: Traffic Accident Fatality Prediction in Estonia

## Overview

This project trains a binary classifier to predict whether a traffic accident results in a fatality, using Estonian accident data from 2011–2023. The core experiment is a **distribution shift test**: train on urban accidents, evaluate on rural accidents — two contexts with meaningfully different road conditions, speeds, and fatality rates.

---

## Data

All data sourced from the Estonian Road Administration (Maanteeamet) accident registry. The dataset covers motor-vehicle-involved accidents only.

| Split | Context | Accidents | Fatal | Fatality Rate |
|---|---|---|---|---|
| Train | Urban (14 settlements) | 3,533 | 64 | 1.84% |
| Test | Rural (everything else) | 3,610 | 292 | 8.09% |

The fatality rate difference alone is a key finding: rural roads are more than four times as deadly as urban roads despite lower traffic volume. This reflects higher speeds, longer emergency response times, and different road infrastructure.

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
| `weather` | One-hot | Clear, cloudy, snowy, rain, etc. |
| `lighting` | One-hot | Daylight, artificial, darkness |
| `settlement` | One-hot | Urban sub-area (district/town) |

**Dropped columns and reasons:**

- `deaths`, `injured` — direct leakage (they define the target)
- `road_type_detailed`, `road_surface_condition` — leakage risk / near-constant values
- `accident_scenario` — 65 unique text values, many appearing only once
- `road_type` — subsumed by `road_width_bin`
- `x_coord`, `y_coord` — raw GPS coordinates without a spatial feature to structure them
- `accident_id`, `accident_time`, `county`, `municipality` — identifiers and high-cardinality admin fields
- `involving_motorvehicle_driver` — zero variance across all datasets (motor vehicle involvement is a dataset filter)

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

### Rural Test Set (Distribution Shift)

Both Logistic Regression and XGBoost retrained on the full urban set (no validation split) and evaluated on rural:

| Model | ROC-AUC | PR-AUC | Recall | TP | FN |
|---|---|---|---|---|---|
| Logistic Regression | 0.600 | 0.103 | 0.836 | 244 | 48 |
| XGBoost | 0.607 | 0.114 | 0.795 | 232 | 60 |

XGBoost shows marginally better discrimination (ROC-AUC +0.007, PR-AUC +0.011) but catches 12 fewer fatal accidents than Logistic Regression (232 vs 244 TP, 60 vs 48 FN).

**Final model: Logistic Regression.** In a road safety context, false negatives — fatal accidents the model fails to flag — are the costlier error. LR's higher recall (0.836 vs 0.795) outweighs XGBoost's marginal AUC gain. LR is also more interpretable.

---

## Distribution Shift Finding

ROC-AUC drops from 0.691 (urban validation) to 0.600 (rural test) — a meaningful degradation of 0.091 points. The model trained on urban accident patterns does not transfer cleanly to rural roads.

This is expected: rural accidents involve higher speed limits, different road widths, different lighting conditions, and different accident type distributions. The urban-trained model has never seen many of the patterns that characterise rural fatalities.

Recall, however, holds up better than expected — 0.836 on rural vs 0.769 on urban validation. The model remains reasonably sensitive to fatal accidents even outside its training context, at the cost of a high false alarm rate (precision 0.097 on rural vs 0.047 on urban).

---

## Limitations

**Small fatal class.** Only 64 fatal accidents in the urban training set. This limits what any model can learn about the conditions that distinguish fatal from non-fatal outcomes.

**Weather data quality.** The `weather` column in the raw data is self-reported at time of accident recording and contains a high proportion of unknown values. The "Unknown" category showed a suspiciously high fatality rate (~6%), likely reflecting reporting bias — severe accidents may be less likely to have complete weather records.

**No spatial features.** GPS coordinates were available but not used after the decision to drop K-Means clustering (unfamiliar method, added complexity without clear benefit at this dataset size).

**Rural generalisation.** The model was trained exclusively on urban data. A model trained on a mix of urban and rural data would likely perform better on rural prediction, but would not serve the distribution shift experiment.

---

## Planned Extensions

**Accurate weather data.** Replace the categorical weather field with continuous variables (precipitation mm, temperature, wind speed, visibility) sourced from the Estonian Weather Service or Open-Meteo historical API, joined on GPS coordinates and accident timestamp. This would address the most significant known data quality issue and potentially improve rural performance where weather conditions are more extreme and variable.

---

## Notebooks

| Notebook | Contents |
|---|---|
| `01_eda_urban.ipynb` | Exploratory data analysis on urban training set |
| `02_feature_engineering.ipynb` | Feature construction, encoding, cleaning |
| `03_modelling.ipynb` | Logistic Regression and Random Forest training and evaluation |
| `03b_xgboost.ipynb` | XGBoost training and comparison against LR |
| `04_evaluation.ipynb` | Rural test set evaluation and distribution shift analysis |
