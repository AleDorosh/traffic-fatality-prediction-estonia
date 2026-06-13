# Methodology

This document covers the full data preparation, feature engineering, and modelling pipeline for the traffic accident fatality prediction project. For a shorter overview of the project and results, see `README.md`.

---

## Data Preparation

### Spatial Join

Traffic accident locations were spatially matched to road segments to obtain road width information. The spatial join was performed in QGIS using a maximum search distance of 20 meters.

Join distance distribution:
- Average: 2.38 m
- 95th percentile: 13.6 m

Only joins with a distance of 15 meters or less were retained. A 10m threshold resulted in significant data loss; 20m increased the risk of incorrect matches where the nearest road segment was not the one the accident actually occurred on.

### Data Filtering

The same filters were applied consistently across all three datasets.

1. **Time period:** 2018-2025, aligned with Transpordiamet's reporting period.
2. **Motor vehicle involvement:** only accidents where at least one motor vehicle driver was involved. This excludes pure cyclist-vs-cyclist incidents and pedestrian falls with no vehicle.
3. **Accident types:** three categories retained - vehicle collisions (`Kokkupõrge`), single-vehicle accidents (`Ühesõidukiõnnetus`), and pedestrian accidents (`Jalakäijaõnnetus`). These cover the main scenarios where a motor vehicle directly causes harm.
4. **Road environment:** non-standard environments excluded - parking lots, forest roads, pedestrian paths, squares, cycle paths. These introduce noise and are not representative of standard road traffic.
5. **Road width:** segments narrower than 3 meters or wider than 34 meters were excluded. Narrower than 3m corresponds to footpaths and alleys rather than traffic lanes, based on Estonian road design standards where typical lane widths start at 3.0 meters. Wider than 34m is outside the plausible range for any Estonian road context and most likely reflects data entry errors in the road geometry source.

### Data Cleaning

1. **Null handling:** rows with more than 3 NULL values across key features were removed. Rows with 3 or fewer NULLs were retained - individual missing values are common for legitimate accidents where not all fields were recorded, and removing them would discard real data unnecessarily. Missing categorical values were replaced with `Unknown`.
2. **Outlier removal:** injury counts were inspected across both urban and rural sets. All values were confirmed plausible given the accident context - multi-occupant collisions can produce high injury counts even at moderate speeds - and no rows were removed on this basis.
3. **Speed limit cleaning:** non-standard speed limit values were remapped to the nearest valid bin: `{5->20, 10->20, 15->20, 25->30, 45->40, 60->70, 80->70}`. These edge values appeared in small numbers and likely reflect data entry inconsistencies.

### Known Data Gap

The `Joobes juht` (drunk driver) column was present in earlier Maanteamet releases but has since been removed from the dataset. This is a confirmed gap - the column is absent from the raw source data, not lost in the pipeline. It would likely be a strong predictor of fatality.

---

## Dataset Construction

### Urban Training Set

Accidents from 14 Estonian settlements with populations over ~10,000: Tallinn (8 districts), Tartu, Narva, Parnu, Kohtla-Jarve (2 districts), Viljandi, Maardu, Rakvere, Kuressaare, Sillamae, Voru, Valga, Keila, Johvi.

Note: Ida-Virumaa is relatively overrepresented (Narva, Kohtla-Jarve, Sillamae, Johvi - 4 of 14 settlements), which may bias the model toward accident patterns specific to that region.

**Final urban training set:**
- 3,544 accidents
- 64 fatal accidents (67 total deaths)
- Fatality rate: 1.81%

### Rural Test Set

Accidents outside the 14 urban settlements, with an additional filter: speed limit >= 90 km/h excluded. These highway accidents have a ~10% fatality rate and represent a third distinct context - a different experiment in itself. Keeping them in would make the rural set unrepresentative of country roads and small settlements.

**Final rural test set:**
- 1,421 accidents
- 70 fatal accidents (72 total deaths)
- Fatality rate: 4.93%

Urban and rural sets are confirmed fully disjoint (zero overlapping `accident_id` values).

### National Feasibility Set

All accidents passing the shared filters, with no geographic restriction. Used to establish a performance ceiling - how well could the model do if data volume were not a constraint?

**Final national set:**
- 7,178 accidents
- 357 fatal accidents
- Fatality rate: 4.97%

---

## Feature Engineering

All transformations are defined on the urban training set and applied identically to the rural and national sets. This prevents any information from the test sets leaking into the feature engineering pipeline.

| Feature | Construction |
|---|---|
| `speed_limit` | Numeric, after remap to valid bins |
| `road_width_bin` | `pd.cut` into narrow (3-5m) / standard (6-9m) / wide (10-14m) / arterial (15m+) |
| `hour_bin` | night (22-05) / rush (07-09, 15-18) / evening (19-21) / day |
| `is_weekend` | Binary, from day-of-week |
| `accident_type` | OHE, 3 categories |
| `accident_type_detailed` | OHE, ~10 subtypes |
| `road_condition` | OHE |
| `lighting` | OHE |
| `weather` | OHE (Estonian categorical from Maanteamet) |
| Participation flags | Binary: `no_safety_equipment`, `motorcyclist`, `pedestrian`, `elderly_driver`, `underage` |

**Excluded features and reasons:**

- `deaths`, `injured` - direct leakage; these define the target variable
- `settlement` - 549 unique rural values vs 22 urban; when the rural set is aligned to the urban feature space, all rural settlements map to zero, providing no signal to the model
- GPS coordinates, admin identifiers (`county`, `municipality`), join distance - identifiers or noise with no predictive structure

**OHE alignment:** one-hot encoding categories are learned from the urban training set. When the rural set is encoded, any rural-only categories (not seen in urban training) are dropped, and any urban-only categories absent from rural are added as zero columns. This ensures the model always receives the same feature space it was trained on - a necessary step for valid distribution shift evaluation.

---

## Modelling

### Model Selection

Two models were evaluated on the urban validation set:

| Model | Outcome |
|---|---|
| Logistic Regression | Selected as final model |
| Random Forest | Rejected - near-zero probability separation between fatal and non-fatal cases |

Random Forest assigned a mean predicted probability of ~0.03 to fatal cases and ~0.02 to non-fatal - effectively no discrimination. With only 64 fatal training cases, averaging 500 decision trees dilutes the minority class signal into noise. This is a known failure mode on severely imbalanced datasets with few positive cases.

**Final model:** Logistic Regression with `class_weight='balanced'` and `StandardScaler`.

`class_weight='balanced'` tells the model to penalise misclassification of fatal accidents ~54x more than non-fatal ones (proportional to the imbalance ratio). Without this, the model predicts non-fatal for everything and scores 98.2% accuracy while being entirely useless.

### Train / Validation / Test Protocol

- **Notebook 03:** 80/20 stratified split of urban data for model selection and threshold calibration
- **Notebook 04:** LR retrained on full urban set (3,544 rows), evaluated on rural test set
- **Notebook 05:** LR trained on rural, evaluated on urban (flipped experiment)
- **Notebook 06:** LR trained on 80% of national set, evaluated on held-out 20%

### Threshold Calibration

The default sklearn decision threshold (0.5) is inappropriate at 1.81% fatality rate - the model's probability estimates for fatal accidents rarely reach 50%. A calibrated threshold is found by maximising F1 on the urban validation set.

The calibrated threshold does not transfer to rural: rural fatal accidents receive lower confidence scores because the model encounters an unfamiliar context, so a threshold set for urban probability distributions is too high for rural ones. Recall drops from 0.500 to 0.214 when the urban-calibrated threshold is applied to rural. Both results are reported in notebook 04.

---

## Evaluation Metrics

**ROC-AUC** - measures how well the model ranks fatal cases above non-fatal ones across all decision thresholds. Interpretation: if shown a random fatal and a random non-fatal accident, how often does the model correctly identify which is which? 0.5 = random, 1.0 = perfect. Less sensitive to class imbalance than accuracy.

**PR-AUC (Average Precision)** - summarises the precision-recall tradeoff. More informative than ROC-AUC when the positive class is rare, because it directly captures how well the model balances catching fatals against false alarms.

**Recall** - of all accidents that were actually fatal, the fraction correctly flagged. The primary operational metric: in a safety context, missed fatals (false negatives) are the costly error.

**Accuracy** is not reported as a primary metric. At 1.81% fatality rate, predicting non-fatal for everything achieves 98.2% accuracy.

---

## Distribution Shift Experiments

### Urban to Rural (Main Experiment)

Train on urban, test on rural. Quantifies how much performance degrades when the model is applied to a context it was never trained on - different road types, speed environments, lighting conditions, and fatality rates.

### Rural to Urban (Flipped Experiment)

Train on rural, test on urban. Tests whether the shift is symmetric. The result is asymmetric - rural to urban achieves higher AUC (0.733 vs 0.635) and better recall (0.641 vs 0.500), suggesting rural training data is more varied and produces patterns that generalise more broadly.

### National Baseline

Train on 80% of the national set, test on held-out 20%. Removes the geographic restriction to test whether data volume or feature quality is the primary constraint. The national baseline (ROC-AUC 0.780 with 286 training fatals) confirms that the features carry real signal - the urban experiment was data-limited, not feature-limited.

---

## Limitations

- **64 urban fatal cases** - the fundamental constraint. The national baseline (ROC-AUC 0.780 with 357 fatal cases) confirms meaningful signal exists; the urban experiment is data-limited, not feature-limited.
- **Drunk driver data absent** - `Joobes juht` removed from current Maanteamet releases; confirmed absent from source, not a pipeline issue.
- **Highway segment excluded** - ~2,200 accidents at speed >= 90 km/h, ~10% fatality rate; a third distinct context not modelled here.
- **Ida-Virumaa overrepresentation** - 4 of 14 urban settlements from one region.
- **No temporal validation** - model trained on 2018-2025 as a single pool; year-based splits not used.
- **No spatial features** - GPS coordinates available but not used as model inputs.
