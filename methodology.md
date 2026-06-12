# Methodology

## Data Preparation

### Spatial Join

Traffic accident locations were spatially matched to road segments to obtain road width information. The spatial join was performed in QGIS using a maximum search distance of 20 meters.

Join distance distribution:
- Average: 2.38 m
- 95th percentile: 13.6 m

Only joins with a distance of ≤ 15 meters were retained. A smaller threshold (10 m) resulted in significant data loss; 20 m increased the risk of incorrect matches.

### Data Filtering

Filters were applied consistently across all datasets.

1. **Time period:** 2018–2025, aligned with Transpordiamet's reporting period.
2. **Motor vehicle involvement:** only accidents involving at least one motor vehicle driver were included.
3. **Accident types:** three categories retained — vehicle collisions (`Kokkupõrge`), single-vehicle accidents (`Ühesõidukiõnnetus`), and pedestrian accidents (`Jalakäijaõnnetus`).
4. **Road environment:** non-standard environments excluded — parking lots, forest roads, pedestrian paths, squares, cycle paths.
5. **Road width:** segments narrower than 3 meters excluded. Estonian road design standards set typical lane widths at 3.0–3.25 meters; narrower lanes occur only in low-speed environments not relevant to this analysis.

### Data Cleaning

1. **Null handling:** rows with more than 1 NULL value across key features were removed. Rows with exactly 1 NULL were retained. Missing categorical values were replaced with `Unknown`.
2. **Outlier removal:** physically implausible injury counts were removed from the urban set (e.g. 7+ injured in a pedestrian accident). Rural data was inspected separately — high injury counts were confirmed plausible for multi-occupant rural collisions and retained.
3. **Speed limit cleaning:** non-standard speed limit values were remapped to the nearest valid bin: `{5→20, 10→20, 15→20, 25→30, 45→40, 60→70, 80→70}`.

### Known Data Gap

The `Joobes juht` (drunk driver) column was present in earlier Maanteamet releases but has since been removed from the dataset. This feature cannot be recovered and is acknowledged as a limitation.

---

## Dataset Construction

### Urban Training Set

Accidents from 14 Estonian settlements with populations over ~10,000:
Tallinn (8 districts), Tartu, Narva, Pärnu, Kohtla-Järve (2 districts), Viljandi, Maardu, Rakvere, Kuressaare, Sillamäe, Võru, Valga, Keila, Jõhvi.

Note: Ida-Virumaa is relatively overrepresented (Narva, Kohtla-Järve, Sillamäe, Jõhvi), which may influence results.

**Final urban training set:**
- 3,544 accidents
- 64 fatal accidents (67 total deaths)
- Fatality rate: 1.81%

### Rural Test Set

The rural set represents non-urban Estonia — accidents outside the 14 training settlements.

**Additional filter:** accidents with speed limit ≥ 90 km/h were excluded. These represent highway segments — a third distinct context with a ~10% fatality rate — not part of this experiment. The rural set therefore covers low-to-medium speed rural roads only.

**Final rural test set:**
- 1,421 accidents
- 70 fatal accidents (72 total deaths)
- Fatality rate: 4.93%

Urban and rural sets are confirmed fully disjoint (zero overlapping `accident_id` values).

### National Feasibility Set

The national set includes all of Estonia with no geographic restriction, used to establish whether the available features can support meaningful fatality prediction when training data volume is not a constraint.

**Final national set:**
- 7,178 accidents
- 357 fatal accidents
- Fatality rate: 4.97%

---

## Feature Engineering

All transformations are defined on the urban training set and applied identically to all other sets. This prevents distribution leakage from rural data into the feature engineering pipeline.

| Feature | Construction |
|---|---|
| `speed_limit` | Numeric, after remap to valid bins |
| `road_width_bin` | `pd.cut` into narrow / standard / wide / arterial |
| `hour_bin` | night (22–05) / rush (07–09, 15–18) / evening (19–21) / day |
| `is_weekend` | Binary, from day-of-week |
| `accident_type` | OHE, 3 categories |
| `accident_type_detailed` | OHE, ~10 subtypes |
| `road_condition` | OHE |
| `lighting` | OHE |
| `weather` | OHE (Estonian categorical from Maanteamet) |
| Participation flags | Binary: `no_safety_equipment`, `motorcyclist`, `pedestrian`, `elderly_driver`, `underage` |

**Excluded features:**

- `settlement` — 549 unique rural values vs 22 urban; all rural settlements map to zero when OHE columns are aligned to urban, providing no signal
- Weather API columns (ERA5) — fetched via `fetch_weather.py` and tested; no improvement in ROC-AUC or recall across any experiment
- `deaths`, `injured` — direct leakage (source of target variable)
- GPS coordinates, admin identifiers, join distance — identifiers or noise

**OHE alignment:** one-hot encoding is fit on the urban training set. The rural test set is encoded separately and then aligned to the urban column space via `reindex` — categories present in rural but absent from urban become all-zero columns; urban-only categories absent from rural are added as zeros. This is the correct behaviour for distribution shift evaluation.

---

## Modelling

### Model Selection

Three models were evaluated on the urban validation set:

| Model | Outcome |
|---|---|
| Logistic Regression | Selected as final model |
| Random Forest | Rejected — near-zero probability separation between fatal and non-fatal cases |
| XGBoost | Rejected — marginal AUC gain, lower recall than LR |

Random Forest assigns mean predicted probability of ~0.03 to fatal cases vs ~0.02 to non-fatal — effectively no discrimination despite high accuracy. This is a known failure mode on severely imbalanced datasets with limited positive cases.

**Final model:** Logistic Regression with `class_weight='balanced'` and `StandardScaler`.

`class_weight='balanced'` penalises misclassification of fatal accidents proportionally to the imbalance ratio (~54× in urban). Without this, the model predicts non-fatal for all cases and achieves 98.2% accuracy while being entirely useless.

### Train / Validation / Test Protocol

- **Notebook 03:** 80/20 stratified split of urban data for model selection and threshold calibration
- **Notebook 04:** LR retrained on full urban set (3,544 rows), evaluated on rural test set
- **Notebook 05:** LR trained on rural, evaluated on urban (flipped experiment)
- **Notebook 06:** LR trained on 80% of national set, evaluated on held-out 20%

### Threshold Calibration

The default sklearn decision threshold (0.5) is inappropriate at 1.81% fatality rate. A calibrated threshold is found by maximising F1 on the urban validation set.

The calibrated threshold does not transfer to rural — rural fatal cases receive lower predicted probabilities due to distribution shift, so applying the urban-calibrated threshold reduces recall on rural. Both default and recalibrated results are reported in notebook 04.

---

## Evaluation Metrics

**Primary:** ROC-AUC — measures how well the model ranks fatal cases above non-fatal across all thresholds. Less sensitive to class imbalance than accuracy.

**Secondary:** PR-AUC (Average Precision) — precision-recall tradeoff, more informative than ROC-AUC when the positive class is rare.

**Reported in full:** recall, TP, FN — because in a safety context, false negatives (fatal accidents predicted as non-fatal) are the costly error.

Accuracy is not reported as a primary metric. At 1.81% fatality rate, predicting all non-fatal achieves 98.2% accuracy.

---

## Distribution Shift Experiments

### Urban → Rural (Main Experiment)

Train on urban, test on rural. Quantifies performance degradation when the model is applied to an unseen geographic context with different road characteristics, speed environments, and fatality rates.

### Rural → Urban (Flipped Experiment)

Train on rural, test on urban. Tests whether the shift is symmetric — does rural training transfer better to urban than the reverse?

### National Baseline

Train on 80% of the national set, test on held-out 20%. Removes geographic restriction to test whether data volume (64 urban fatal cases) or feature quality is the primary constraint on model performance.

---

## Limitations

- **64 urban fatal cases** is the fundamental constraint. The national baseline (ROC-AUC 0.780 with 357 fatal cases) confirms meaningful signal exists in the features — the urban experiment is data-limited, not feature-limited.
- **Drunk driver data absent** from current Maanteamet releases.
- **Highway segment excluded** — ~2,200 accidents with speed ≥ 90 km/h represent a third distinct context with ~10% fatality rate, not modelled here.
- **Ida-Virumaa overrepresentation** in the urban training set (4 of 14 settlements).
- **No temporal validation** — the model is trained on 2018–2025 as a single pool. Year-based splits were not used.
