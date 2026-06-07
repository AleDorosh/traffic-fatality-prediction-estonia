
"""
fetch_weather.py
----------------
Fetches historical hourly weather from Open-Meteo for each accident
in urban_filter.csv and rural_filter.csv, then saves enriched versions.
 
Requirements:
    pip3 install pandas openmeteo-requests requests-cache retry-requests pyproj --break-system-packages
 
Usage:
    Place this script in the same folder as urban_filter.csv and rural_filter.csv
    then run:
        python3 fetch_weather.py
"""
 
import time
import shutil
import pandas as pd
import numpy as np
import requests
from pathlib import Path
from pyproj import Transformer
 
# ── Config ───────────────────────────────────────────────────────────────────
INPUT_FILES = {
    'urban': Path('urban_filter.csv'),
    'rural': Path('rural_filter.csv'),
}
 
WEATHER_VARS = [
    'precipitation',
    'temperature_2m',
    'wind_speed_10m',
    'visibility',
    'snowfall',
]
 
# L-EST97 (EPSG:3301) → WGS84 (EPSG:4326)
transformer = Transformer.from_crs('EPSG:3301', 'EPSG:4326', always_xy=True)
 
OPEN_METEO_URL = 'https://archive-api.open-meteo.com/v1/archive'
API_DELAY = 0.2  # seconds between requests
 
# ── Coordinate conversion ─────────────────────────────────────────────────────
def lest97_to_wgs84(x, y):
    lon, lat = transformer.transform(x, y)
    return lat, lon
 
 
# ── API call ──────────────────────────────────────────────────────────────────
def fetch_hourly_weather(lat, lon, date_str, hour):
    nan_result = {v: np.nan for v in WEATHER_VARS}
    try:
        params = {
            'latitude':        lat,
            'longitude':       lon,
            'start_date':      date_str,
            'end_date':        date_str,
            'hourly':          ','.join(WEATHER_VARS),
            'timezone':        'Europe/Tallinn',
            'wind_speed_unit': 'kmh',
        }
        resp = requests.get(OPEN_METEO_URL, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
 
        hourly = data.get('hourly', {})
        times  = hourly.get('time', [])
 
        if not times:
            return nan_result
 
        target_time = f'{date_str}T{hour:02d}:00'
        if target_time not in times:
            return nan_result
 
        idx = times.index(target_time)
        return {v: hourly[v][idx] for v in WEATHER_VARS}
 
    except Exception:
        return nan_result
 
 
# ── Process one dataset ───────────────────────────────────────────────────────
def enrich_dataset(name, path):
    print(f'\n{"="*55}')
    print(f'  Processing {name}: {path}')
    print(f'{"="*55}')
 
    df = pd.read_csv(path)
    print(f'  Loaded {len(df):,} rows')
 
    df['accident_time'] = pd.to_datetime(df['accident_time'])
    df['_date']         = df['accident_time'].dt.strftime('%Y-%m-%d')
    df['_hour']         = df['accident_time'].dt.hour
    df['_missing_time'] = (df['_hour'] == 0) & (df['accident_time'].dt.minute == 0)
 
    print('  Converting L-EST97 → WGS84...')
    df['_lat'] = np.nan
    df['_lon'] = np.nan
    valid = df[['x_coord', 'y_coord']].dropna()
    for idx, row in valid.iterrows():
        lat, lon = lest97_to_wgs84(row['x_coord'], row['y_coord'])
        df.at[idx, '_lat'] = lat
        df.at[idx, '_lon'] = lon
 
    for v in WEATHER_VARS:
        df[v] = np.nan
 
    total   = len(df)
    success = 0
    skipped = 0
 
    print(f'  Fetching weather for {total:,} accidents...')
    for i, (idx, row) in enumerate(df.iterrows()):
        if i % 200 == 0 and i > 0:
            print(f'  ... {i:,}/{total:,} done ({success} ok, {skipped} skipped)')
 
        if pd.isna(row['_lat']) or pd.isna(row['_lon']) or row['_missing_time']:
            skipped += 1
            continue
 
        weather = fetch_hourly_weather(
            lat      = row['_lat'],
            lon      = row['_lon'],
            date_str = row['_date'],
            hour     = int(row['_hour']),
        )
 
        for v in WEATHER_VARS:
            df.at[idx, v] = weather[v]
 
        if not all(np.isnan(w) if isinstance(w, float) else False for w in weather.values()):
            success += 1
 
        time.sleep(API_DELAY)
 
    print(f'  Done. {success:,} fetched, {skipped} skipped')
 
    df = df.drop(columns=['_date', '_hour', '_missing_time', '_lat', '_lon'])
 
    backup = path.with_suffix('.csv.bak')
    if not backup.exists():
        shutil.copy(path, backup)
        print(f'  Backup saved → {backup}')
 
    df.to_csv(path, index=False)
    print(f'  Saved → {path}')
 
    print(f'\n  Weather column fill rates:')
    for v in WEATHER_VARS:
        filled = df[v].notna().sum()
        print(f'    {v:<25} {filled:,}/{total:,} ({filled/total*100:.1f}%)')
 
 
# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print('Weather enrichment script')
    print(f'Variables : {WEATHER_VARS}')
    print(f'API delay : {API_DELAY}s per row')
    print(f'Est. time : ~{7100 * API_DELAY / 60:.0f} min for both datasets')
 
    for name, path in INPUT_FILES.items():
        enrich_dataset(name, path)
 
    print('\nAll done. Re-run notebook 02 to pick up the new weather columns.')
 
