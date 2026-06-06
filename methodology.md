# Methodology

### Data Preparation

#### Spatial join
Traffic accident locations were spatially matched to road segments to obtain road width information. The spatial join was performed in QGIS using a maximum search distance of 20 meters.
The distribution of join distances showed:
* average distance: 2.38 m
* 95th percentile: 13.6 m

#### Data Filtering Methodology
The original traffic accident dataset contains records from multiple years and accident types.
Several filters were applied to align the data with the research goal.

1. Only joins with a distance of 15 meters or less were retained to reduce spatial mismatches. A smaller threshold (10 m) resulted in significant data loss, while 20 m increased the risk of incorrect matches.
2. The analysis focuses on the period 2018–2025. This time frame aligns with Transpordiamet's traffic accident reporting period and reflects the most recent traffic conditions.
3. Cities and towns with populations over ~10,000 were selected (14 total): Tallinn, Tartu, Narva, Pärnu, Kohtla-Järve, Viljandi, Maardu, Rakvere, Kuressaare, Sillamäe, Võru, Valga, Keila, Jõhvi. These locations are geographically distributed across Estonia and represent a variety of urban characteristics.
Note: Ida-Virumaa is relatively overrepresented (Narva, Kohtla-Järve, Sillamäe, Jõhvi), which may influence results. This is acknowledged as a limitation.
4. The analysis includes three main accident types: vehicle collisions, single-vehicle accidents, and accidents involving pedestrians, cyclists, and micromobility users.
5. Only accidents involving at least one motor vehicle driver were included.
6. Accidents in non-standard environments (e.g. parking lots, forest roads, pedestrian paths, squares) were excluded.
7. Only road segments with a width of ≥ 3 meters were included. According to Estonian road design standards, typical traffic lane widths range between 3.0 and 3.25 meters, with narrower lanes (around 2.75 meters) occurring only in low-speed environments.

After filtering the dataset contained 3,742 accidents, including 68 fatalities and 4,265 injuries.

#### Data Cleaning Methodology
The dataset was cleaned to improve consistency and reliability. At the time of cleaning, no official documentation was available (accessed later on 18.03.2026), so decisions were based on data inspection.

1. Duplicate rows were identified by accident_id. These rows had identical values except for road_width, likely due to the spatial join matching multiple road segments. All these rows were removed, as there was no way to tell which row had correct data.
2. Extreme values that were inconsistent with accident context and likely represent data entry errors were removed (e.g. unusually high injury counts for low-speed or pedestrian accidents).
3. Rows with more than 1 NULL value were removed. Rows with 1 NULL value were retained. Missing values were replaced with 'Unknown'. Values such as "Pole teada" and "Teadmata" were also standardized to 'Unknown'.
4. One row with `road_width = 35` was removed across all datasets. This value is physically implausible for any Estonian road context and is treated as a data entry error regardless of location.

#### Final Dataset (Urban Training Set)
* 3,533 accidents
* 67 deaths across 64 accidents
* 4,019 injured across 3,469 accidents
* Average road width: 9.19 m

#### Variables Used
* accident identifiers (accident id and time)
* accident severity (injuries, fatalities)
* location (county, municipality, settlement)
* accident characteristics (accident type and scenario)
* road characteristics (road width, speed limit, road type)
* environmental conditions (weather, lighting, road surface)
* spatial join quality (distance to matched road segment)

---

### Distribution Shift Evaluation

The urban dataset described above serves as the training set. To evaluate how well the model generalises beyond its training distribution, two additional test sets were constructed from the same source data. This setup allows the model's performance to be assessed across three levels of distributional similarity: same distribution (urban holdout), out-of-distribution rural, and blended national.

Urban and rural sets were confirmed to be fully disjoint (zero overlapping `accident_id` values).

#### Rural Test Set

The rural test set was constructed to represent non-urban Estonia: state-maintained roads outside the 14 cities used for training.

**Filtering**

1. All accidents within the 14 urban settlements used in training were excluded.
2. The same accident type filters applied to the urban set were used (vehicle collisions, single-vehicle accidents, pedestrian/cyclist/micromobility accidents).
3. Accidents in non-standard environments (e.g. parking lots, forest roads, pedestrian paths, squares) were excluded.
4. Only accidents involving at least one motor vehicle driver were included.
5. The same 2018–2025 time frame was applied.

**Cleaning**

The rural set was cleaned using the same general pipeline as the urban set, with two deliberate exceptions:

1. **High injury count outliers were retained.** Urban outlier removal targeted physically implausible pedestrian injury counts. In a rural context, multi-occupant vehicle crashes on higher-speed roads can produce comparably high counts and are plausible. Rather than removing these rows, a binary `is_outlier` flag was added to allow the model to account for them without discarding real signal.
2. **Speed limits of 90 and 110 km/h were retained.** These values do not appear in the urban training set. They represent genuine distributional shift — a defining feature of rural roads — rather than data errors. Removing them would artificially narrow the test set.

**Final Rural Test Set**
* 3,610 accidents
* 292 deaths
* Fatality rate: 8.1%

Note: the fatality rate is approximately four times higher than in the urban training set (1.9%). This prior probability shift is expected and is part of what is being studied. Metrics are reported both with and without threshold recalibration to make this shift explicit.

---

#### National Test Set

The national test set includes all of Estonia and is constructed by combining the urban training locations with the rural test set, plus any remaining accidents that passed the shared filters but fell outside both.

**Purpose**

The national set represents real-world deployment conditions: a model trained on urban data applied to a mixed population of accident contexts. It sits between the urban holdout (same distribution) and the rural set (pure out-of-distribution) in terms of expected generalisation difficulty.

**Filtering**

The same accident type, driver involvement, road type, time period, and environment filters were applied as in the urban and rural sets. No geographic restriction was applied beyond these shared criteria.

**Cleaning**

The same cleaning pipeline was applied. The `road_width = 35` removal and NULL handling rules were applied consistently. The `is_outlier` flag used in the rural set is carried through to the national set.

**Final National Test Set**
* 7,160 accidents
* 356 deaths
* Fatality rate: 5.0%

The national fatality rate (5.0%) sits between the urban (1.9%) and rural (8.1%) rates, consistent with the blended composition of the set.
