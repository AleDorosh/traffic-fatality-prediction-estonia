# Results: Traffic Accident Fatality Prediction in Estonia

## Overview

Binary classification predicting whether a traffic accident results in a fatality, using Estonian accident data from 2018–2025. The core experiment is a **distribution shift test**: train on urban accidents, evaluate on rural — two contexts with meaningfully different road conditions, speeds, and fatality rates.

---

## Data

All data sourced from the Estonian Road Administration (Maanteamet) accident registry.

| Set | Context | Accidents | Fatal accidents | Fatality rate | Role |
|---|---|---|---|---|---|
| Urban | 14 Estonian settlements | 3,544 | 64 | 1.81% | Train |
| Rural | Non-urban, speed < 90 km/h | 1,421 | 70 | 4.93% | Test (OOD) |
| National | All Estonia | 7,178 | 357 | 4.97% | Feasibility baseline |

The rural set excludes speed limits ≥ 90 km/h to remove highway segments (~2,200 rows, ~10% fatality rate), which represent a third distinct context not part of this experiment.

The national set is used as a feasibility baseline — not a test set. It answers whether the available features can support meaningful fatality prediction when training data is not the constraint.

Urban and rural sets are fully disjoint (zero overlapping `accident_id` values).

---

## Class Imbalance

At 1.81% fatality rate, the urban training set has approximately 1 fatal accident per 54 non-fatal. Standard accuracy is meaningless — a model predicting non-fatal for everything scores 98.2% while being entirely useless.

All models used `class_weight='balanced'` to penalise missed fatal predictions proportionally. Evaluation focused on ROC-AUC, PR-AUC, recall, and confusion matrices.

---

## Models Evaluated

**Logistic Regression** — selected as final model. `class_weight='balanced'`, `StandardScaler` fit on training data only.

**Random Forest** — rejected. Probability analysis showed mean predicted probability of ~0.03 for fatal cases vs ~0.02 for non-fatal — near-zero separation, no useful discrimination despite high accuracy. Known failure mode on severely imbalanced datasets with few positive cases.

**XGBoost** — rejected. Marginal AUC gain over LR but lower recall. RF probability collapse does not apply (XGBoost does assign higher probabilities to fatal cases), but the improvement does not justify added complexity.

---

## Results

### Urban Validation (80/20 stratified split)

| Metric | Value |
|---|---|
| ROC-AUC | 0.691 |
| PR-AUC | 0.062 |
| Recall (fatal) | 0.615 |
| Precision (fatal) | 0.044 |

Confusion matrix:

|  | Predicted non-fatal | Predicted fatal |
|---|---|---|
| **Actual non-fatal** | 523 (TN) | 173 (FP) |
| **Actual fatal** | 5 (FN) | 8 (TP) |

The model catches 8 of 13 fatal accidents in the urban validation set, missing 5.

---

### Urban → Rural (Main Experiment)

LR retrained on full urban set (3,544 rows), evaluated on rural test set:

| Threshold | ROC-AUC | PR-AUC | Recall | TP | FN |
|---|---|---|---|---|---|
| Default | 0.635 | 0.101 | 0.500 | 35 | 35 |
| Urban-calibrated (0.797) | 0.635 | 0.101 | 0.214 | 15 | 55 |

ROC-AUC degrades from 0.691 (urban val) to 0.635 on rural — a drop of 0.056 reflecting distribution shift. The urban-calibrated threshold does not transfer: rural fatal cases receive lower predicted probabilities, so applying the urban threshold reduces recall sharply.

---

### Rural → Urban (Flipped Experiment)

LR trained on rural (70 fatal), evaluated on urban (64 fatal):

| Direction | Train fatal | Test fatal | ROC-AUC | PR-AUC | Recall | TP | FN |
|---|---|---|---|---|---|---|---|
| Urban → Rural | 64 | 70 | 0.635 | 0.101 | 0.500 | 35 | 35 |
| Rural → Urban | 70 | 64 | 0.733 | 0.049 | 0.641 | 41 | 23 |

The flipped direction achieves higher ROC-AUC (+0.098) and better recall. The experiment is asymmetric — rural patterns generalise to urban more readily than the reverse. Rural training data is more varied in road conditions and accident types; the model appears to learn broader patterns that transfer across contexts, whereas urban training produces narrower patterns tied to specific city environments.

---

### National Baseline

LR trained on 80% of national set, evaluated on held-out 20%:

| Metric | Value |
|---|---|
| ROC-AUC | 0.780 |
| PR-AUC | 0.202 |
| Fatal mean prob | 0.621 |
| Non-fatal mean prob | 0.358 |
| Separation | 0.264 |

The national baseline confirms **data volume was the primary constraint** in the distribution shift experiment. With 286 training fatal cases (vs 64 urban), the same features and the same model achieve ROC-AUC 0.780 — a 0.145 point improvement over urban → rural. The probability separation is real and substantial. The features carry meaningful signal; 64 urban fatal cases is simply too few to learn generalisable patterns.

---

## Summary Table

| Experiment | Train fatal | Test fatal | ROC-AUC | PR-AUC | Recall |
|---|---|---|---|---|---|
| Urban val (LR) | 51* | 13 | 0.691 | 0.062 | 0.615 |
| Urban → Rural (LR) | 64 | 70 | 0.635 | 0.101 | 0.500 |
| Rural → Urban (LR) | 70 | 64 | 0.733 | 0.049 | 0.641 |
| National — LR | 286 | 71 | 0.780 | 0.202 | — |

*Urban val uses 80% of urban training data (3,544 × 0.8 ≈ 2,835 rows, ~51 fatal).

---

## Extensions Attempted

All extensions were implemented and evaluated. None produced meaningful performance gains on the primary metric.

| Extension | Outcome |
|---|---|
| Participation flags (motorcyclist, pedestrian, elderly, underage, no safety equipment) | No improvement in rural ROC-AUC |
| ERA5 weather API (precipitation, temperature, wind, snowfall) | No improvement; excluded from final model |
| XGBoost (`scale_pos_weight=54`) | Marginal AUC gain, lower recall; LR preferred |
| Highway filtering (speed < 90 rural) | Data quality improvement, not performance improvement |

The consistent failure to improve rural performance points to the fundamental constraint: **64 urban fatal training cases is insufficient** for a model to learn patterns that generalise across contexts. Feature engineering cannot compensate for a minority class this small.

---

## Limitations

**Small fatal class.** 64 urban fatal accidents is the primary constraint. The national baseline confirms the features have signal — the problem is data volume, not feature quality.

**Drunk driver data absent.** The `Joobes juht` (drunk driver) column was present in earlier Maanteamet releases but has been removed from the current dataset. This is a likely strong predictor of fatality and is a confirmed gap, not a pipeline issue.

**Highway segment not modelled.** ~2,200 accidents with speed ≥ 90 km/h, ~10% fatality rate — a third distinct context excluded from this experiment.

**No spatial features.** GPS coordinates available but not used as features.

**Ida-Virumaa overrepresentation.** 4 of 14 urban settlements are in Ida-Virumaa (Narva, Kohtla-Järve, Sillamäe, Jõhvi), which may bias the urban training set.

---

## Notebooks

| Notebook | Contents |
|---|---|
| `01_eda_urban_rural.ipynb` | Side-by-side EDA: urban vs rural |
| `02_feature_engineering_urban.ipynb` | Feature construction for urban training set |
| `03_modelling_urban.ipynb` | LR and RF training, threshold calibration |
| `04_evaluation.ipynb` | Urban → rural evaluation |
| `05_flipped_experiment.ipynb` | Rural → urban (flipped experiment) |
| `06_national_baseline.ipynb` | National feasibility baseline |
| `fetch_weather.py` | ERA5 weather API enrichment (excluded from final model) |
