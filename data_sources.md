# Data Sources

All raw data files are excluded from version control. Download links and licences are listed below.

---

#### Traffic Accident Data

- **Dataset:** Inimkannatanutega liiklusõnnetuste andmed (Traffic accidents with casualties)
- **Provider:** Eesti Transpordiamet via the Estonian Open Data Portal (Andmete teabevärav)
- **Dataset page:** https://andmed.eesti.ee/datasets/inimkannatanutega-liiklusonnetuste-andmed
- **Accessed:** June 2026
- **Licence:** CC BY 3.0

---

#### Road Width Data

- **Dataset:** TN.RoadTransportNetwork.RoadWidth
- **Provider:** Eesti topograafia andmekogu - Maa- ja Ruumiamet (Estonian Topographic Database, Land and Spatial Development Board)
- **Metadata:** https://metadata.geoportaal.ee/geonetwork/srv/eng/catalog.search#/metadata/bf38a8fc-96f1-4d34-9130-18160e489514
- **Service endpoint (WFS):** https://inspire.geoportaal.ee/geoserver/TN_transportetak/wfs, layer: TN.RoadTransportNetwork.RoadWidth
- **Accessed:** June 2026
- **Licence:** https://geoportaal.maaruum.ee/opendata-licence (CC BY 4.0)

---

#### Spatial Join

Accident points were joined to road width polygons using a spatial join in QGIS. Matches within 15 meters were retained. A preview of the spatial join result is in `data/map_preview.png`.

<img width="600" height="450" src="data/map_preview.png"/>
