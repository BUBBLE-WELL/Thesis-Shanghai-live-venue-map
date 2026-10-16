# Interactive venue map

- China: https://jiyiji.cn/webqing/shanghai-venue-map/
- Overseas (GitHub Pages): https://bubble-well.github.io/Thesis-Shanghai-live-venue-map/

Open `index.html` in a browser to explore the formal Shanghai venue inventory (n=67). It is the canonical GitHub Pages entrypoint; `interactive_venue_map.html` is retained only as a legacy development copy.

Use the layer control to switch between Amap, ShowStart, XHS, and cross-platform BGE. Click a marker for venue-level fields. The map uses the bundled CSV/GeoJSON files in `data/`. GitHub Pages uses Leaflet with CartoDB Positron. The China mirror keeps the Leaflet interaction and research layers but places them over a Tencent vector basemap, converts the WGS84 research coordinates to GCJ-02 at runtime, and limits Tencent's vector features to `base` beneath a light colour mask. This reduces visual noise without changing the underlying venue data.

## Prepare the China release

The repository intentionally contains an empty Tencent browser-key configuration. Generate a deployable, manifest-limited artifact from a local environment file instead of committing the key:

```powershell
& .\release\prepare-china-release.ps1 `
  -EnvFile "D:\MY\Thesis\interactive_venue_map_standalone\env.txt" `
  -OutputRoot "$env:TEMP\shanghai-venue-map-china"
```

The environment file must contain `TENCENT_MAP_API=<browser key>` or `TENCENT_MAP_KEY=<browser key>`. Restrict that browser key to the production domain in the Tencent console. On `jiyiji.cn`, the page selects Tencent automatically; append `?basemap=tencent` for local QA or `?basemap=carto` to force the overseas fallback. The packager copies only `release/china-public-files.txt`, injects the key into the output artifact, and runs the public-content leak scan.

The Mengtian boundary counter-case is excluded from the formal 67-venue display. The `data/` folder contains clean derived tables only; no raw screenshots, OCR, or observation long tables are bundled. BGE-derived text and venue summaries are included for development inspection, but raw embedding dumps are not.

## Anonymous product analytics

The canonical entrypoint sends privacy-minimized semantic events to the shared PostHog project with `app_id=venue_map`. Autocapture and session replay are disabled. Events cover data-load reliability, layer toggles, map exploration, venue popup cards, analysis-section reading, figure exposure, outbound links, active time, and core/full feature discovery. No venue-map interaction is linked to a named person.

Key monitoring events are:

- `venue_popup_opened`: emitted for every POI popup-card open with `venue_id`, `platform_layer`, `card_type=venue_popup`, and `engagement_unit=card`.
- `analysis_figure_viewed`: emitted once per figure per browser session after at least 35% of the figure remains visible for 1.2 seconds, with `figure_id`, `analysis_id`, and `engagement_unit=page`. Current stable IDs are `figure-4-5` and `anchor-probing-figure`.
- `map_data_load_failed`: emitted with `is_qa=false` when the bundled map data cannot load; this is the production reliability event monitored by the PostHog alert. Schema-seed events use `is_qa=true` and are excluded from the alert insight.
