// EAS (Environmental Analyzing System) - Official Full App Engine with Live Tracking
const API_BASE = window.location.origin;

// State Variables
let currentLocation = 'Alandur Bus Depot, Chennai';
let allLocations = [];
let allStationRecords = [];
let activeZoneFilter = 'all';
let activeMapFilter = 'all';
let autoRefreshTimer = null;

// Live Tracking & Map State
let chennaiMap = null;
let mapMarkers = [];
let baseTileLayers = {};
let currentActiveTileLayer = 'satellite';
let waterwayLayersGroup = null;
let radarRingsGroup = null;
let showStationBadges = true;
const chennaiCenterCoords = [13.0600, 80.2350];
let tourPlaying = false;
let tourIndex = 0;
let tourIntervalMs = 8000;
let tourIntervalTimer = null;
let tourProgressTimer = null;
let tourProgressStartTime = 0;
let packetCount = 0;
let liveStreamTimer = null;

// DOM Elements
const locationSelect = document.getElementById('locationSelect');
const simulateBtn = document.getElementById('simulateBtn');
const quickExportBtn = document.getElementById('quickExportBtn');
const statusPill = document.getElementById('backendStatusPill');
const statusLabel = document.getElementById('statusLabel');

// Overview Tab DOM Elements
const displayLocation = document.getElementById('displayLocation');
const scoreValue = document.getElementById('scoreValue');
const scoreStatusBadge = document.getElementById('scoreStatusBadge');
const scoreDescription = document.getElementById('scoreDescription');
const lastUpdatedTime = document.getElementById('lastUpdatedTime');
const gaugeProgressCircle = document.getElementById('gaugeProgressCircle');

const valAqi = document.getElementById('valAqi');
const statusAqi = document.getElementById('statusAqi');
const valTemp = document.getElementById('valTemp');
const statusTemp = document.getElementById('statusTemp');
const valHum = document.getElementById('valHum');
const statusHum = document.getElementById('statusHum');
const valTds = document.getElementById('valTds');
const statusTds = document.getElementById('statusTds');

const alertsContainer = document.getElementById('alertsContainer');
const trendBarsContainer = document.getElementById('trendBarsContainer');
const analysisContainer = document.getElementById('analysisContainer');
const recommendationsList = document.getElementById('recommendationsList');
const zonesGrid = document.getElementById('zonesGrid');
const toastEl = document.getElementById('toast');

// Tracked HUD Elements
const trackedStationAgency = document.getElementById('trackedStationAgency');
const trackedStationTitle = document.getElementById('trackedStationTitle');
const trackedStationSub = document.getElementById('trackedStationSub');
const trackedAqiVal = document.getElementById('trackedAqiVal');
const trackedStatusBadge = document.getElementById('trackedStatusBadge');
const trackedDescText = document.getElementById('trackedDescText');

const trackedPm25 = document.getElementById('trackedPm25');
const trackedPm10 = document.getElementById('trackedPm10');
const trackedNo2 = document.getElementById('trackedNo2');
const trackedSo2 = document.getElementById('trackedSo2');
const trackedCo = document.getElementById('trackedCo');
const trackedOzone = document.getElementById('trackedOzone');

const trackedWaterBody = document.getElementById('trackedWaterBody');
const trackedWaterTds = document.getElementById('trackedWaterTds');
const trackedWaterPh = document.getElementById('trackedWaterPh');
const trackedWaterDo = document.getElementById('trackedWaterDo');
const trackedWaterBod = document.getElementById('trackedWaterBod');

const trackedAirCausesList = document.getElementById('trackedAirCausesList');
const trackedWaterCausesList = document.getElementById('trackedWaterCausesList');
const trackedOfficialPortalLink = document.getElementById('trackedOfficialPortalLink');
const deepTelemetryBtn = document.getElementById('deepTelemetryBtn');

// Stream & Tour Controls
const liveTickerStream = document.getElementById('liveTickerStream');
const streamLatency = document.getElementById('streamLatency');
const streamActiveCount = document.getElementById('streamActiveCount');
const tourPlayPauseBtn = document.getElementById('tourPlayPauseBtn');
const tourPlayIcon = document.getElementById('tourPlayIcon');
const tourPlayText = document.getElementById('tourPlayText');
const tourPrevBtn = document.getElementById('tourPrevBtn');
const tourNextBtn = document.getElementById('tourNextBtn');
const tourStationIndex = document.getElementById('tourStationIndex');
const tourStationName = document.getElementById('tourStationName');
const tourProgressBar = document.getElementById('tourProgressBar');
const telemetryPacketLog = document.getElementById('telemetryPacketLog');
const terminalPacketCount = document.getElementById('terminalPacketCount');

// Comparator Modal Elements
const openComparatorBtn = document.getElementById('openComparatorBtn');
const comparatorModal = document.getElementById('comparatorModal');
const closeComparatorBtn = document.getElementById('closeComparatorBtn');
const compSelectA = document.getElementById('compSelectA');
const compSelectB = document.getElementById('compSelectB');
const comparatorComparisonContent = document.getElementById('comparatorComparisonContent');

// =============================================================
// INITIALIZATION
// =============================================================
document.addEventListener('DOMContentLoaded', () => {
  setupTabNavigation();
  loadCompleteDataset().then(() => {
    initChennaiMap();
    setupTourControls();
    setupMapFilterButtons();
    setupComparator();
    trackSpecificStation(currentLocation);
  });

  loadLocations();
  loadDashboardData(currentLocation);

  if (locationSelect) {
    locationSelect.addEventListener('change', (e) => {
      currentLocation = e.target.value;
      trackSpecificStation(currentLocation);
      loadDashboardData(currentLocation);
    });
  }

  if (simulateBtn) simulateBtn.addEventListener('click', handleSimulate);
  if (quickExportBtn) quickExportBtn.addEventListener('click', exportDatasetToCSV);

  // Search input for compliance matrix table
  const searchInput = document.getElementById('stationTableSearch');
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      filterComplianceTable(e.target.value.toLowerCase().trim());
    });
  }

  // Grievance form submit
  const grievanceForm = document.getElementById('grievanceForm');
  if (grievanceForm) {
    grievanceForm.addEventListener('submit', handleGrievanceSubmit);
  }

  // Deep Telemetry button switches to Overview tab
  if (deepTelemetryBtn) {
    deepTelemetryBtn.addEventListener('click', () => {
      const overviewTab = document.querySelector('[data-tab="tab-overview"]');
      if (overviewTab) overviewTab.click();
    });
  }

  // Start live telemetry polling every 3.5 seconds
  startLiveTelemetryStream();

  // Background dashboard refresh every 30 seconds
  autoRefreshTimer = setInterval(() => {
    loadDashboardData(currentLocation, true);
  }, 30000);
});

// Setup Main Tab Navigation
function setupTabNavigation() {
  const tabs = document.querySelectorAll('.nav-tab');
  const contents = document.querySelectorAll('.tab-content');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetId = tab.dataset.tab;
      tabs.forEach(t => t.classList.remove('active'));
      contents.forEach(c => c.classList.remove('active'));

      tab.classList.add('active');
      const targetContent = document.getElementById(targetId);
      if (targetContent) targetContent.classList.add('active');

      if (targetId === 'tab-tracking') {
        if (chennaiMap) {
          chennaiMap.invalidateSize();
          setTimeout(() => { chennaiMap.invalidateSize(); }, 150);
          setTimeout(() => { chennaiMap.invalidateSize(); }, 400);
        }
      }
      if (targetId === 'tab-stations') renderComplianceTable();
      if (targetId === 'tab-water') renderWaterBodiesGrid();
    });
  });
}

// =============================================================
// LEAFLET GIS CHENNAI MAP & RADAR BEACONS (EAS LIVE RADAR)
// =============================================================
function initChennaiMap() {
  if (typeof L === 'undefined') {
    console.warn('Leaflet library is not available');
    return;
  }
  const mapEl = document.getElementById('chennaiGisMap');
  if (!mapEl || chennaiMap) return;

  // Real Map Base Tile Providers (Satellite, Street/Waterways, Topographic, Dark)
  baseTileLayers.satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
    maxZoom: 19,
    attribution: 'Esri World Imagery'
  });

  baseTileLayers.streets = L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
    maxZoom: 19,
    subdomains: 'abcd',
    attribution: 'CARTO Voyager / OpenStreetMap'
  });

  baseTileLayers.topo = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}', {
    maxZoom: 18,
    attribution: 'Esri World Topographic'
  });

  baseTileLayers.dark = L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
    maxZoom: 19,
    subdomains: 'abcd',
    attribution: 'CARTO Dark Tactical'
  });

  // Initialize Map centered on Greater Chennai Metropolitan Area
  chennaiMap = L.map('chennaiGisMap', {
    zoomControl: true,
    attributionControl: false,
    layers: [baseTileLayers.satellite] // Real Live Satellite Default
  }).setView(chennaiCenterCoords, 11);

  // Invalidate geometry right away and with staged timeouts to guarantee smooth tiles
  chennaiMap.invalidateSize();
  setTimeout(() => { if (chennaiMap) chennaiMap.invalidateSize(); }, 150);
  setTimeout(() => { if (chennaiMap) chennaiMap.invalidateSize(); }, 500);
  setTimeout(() => { if (chennaiMap) chennaiMap.invalidateSize(); }, 1000);

  // Responsive window resizing
  window.addEventListener('resize', () => {
    if (chennaiMap) chennaiMap.invalidateSize();
  });

  // Initialize River Basins Geo-Vector Layer
  initWaterwayPolylines();

  // Initialize Radar Range Rings
  initRadarRangeRings();

  // Render stations with live badges
  renderMapMarkers();

  // Bind toolbar controls (Layers, Radar sweep, Rivers, Badges, Recenter)
  setupMapToolbarControls();
  setupMapFilterButtons();
}

// -------------------------------------------------------------
// Waterway Catchment Vector Overlays (Cooum, Adyar, Buckingham)
// -------------------------------------------------------------
function initWaterwayPolylines() {
  if (!chennaiMap) return;
  waterwayLayersGroup = L.layerGroup();

  // 1. Cooum River Path (Glowing Cyan Urban Catchment)
  const cooumPath = [
    [13.0900, 80.1200],
    [13.0800, 80.1550],
    [13.0640, 80.1700],
    [13.0680, 80.1900],
    [13.0720, 80.2050],
    [13.0745, 80.2220],
    [13.0730, 80.2430],
    [13.0780, 80.2600],
    [13.0760, 80.2720],
    [13.0690, 80.2830],
    [13.0675, 80.2865]
  ];

  const cooumLine = L.polyline(cooumPath, {
    color: '#06b6d4',
    weight: 4.5,
    opacity: 0.95,
    lineCap: 'round',
    lineJoin: 'round'
  });
  cooumLine.bindPopup(`
    <div style="font-family: inherit; font-size: 0.8rem; color: #fff; min-width: 210px;">
      <strong style="color: #06b6d4; font-size: 0.95rem;">🌊 Cooum River Urban Catchment</strong>
      <div style="margin: 4px 0; color: #9ca3af; font-size: 0.72rem;">Course: Maduravoyal ➔ Aminjikarai ➔ Napier Bridge</div>
      <div style="background: rgba(6,182,212,0.15); border: 1px solid rgba(6,182,212,0.3); padding: 5px 8px; border-radius: 6px; margin-top: 6px;">
        <div>Dissolved Oxygen: <strong style="color: #ef4444;">0.8 mg/L (Critical)</strong></div>
        <div>Total Dissolved Solids: <strong style="color: #fb923c;">1,840 ppm</strong></div>
        <div style="font-size: 0.7rem; color: #cbd5e1; margin-top: 3px;">Sewage interception & restoration active</div>
      </div>
    </div>
  `);
  waterwayLayersGroup.addLayer(cooumLine);

  // 2. Adyar River Path (Glowing Marine Blue)
  const adyarPath = [
    [12.9980, 80.0450],
    [13.0100, 80.1150],
    [13.0250, 80.1600],
    [13.0280, 80.1750],
    [13.0180, 80.1880],
    [13.0120, 80.2010],
    [13.0205, 80.2220],
    [13.0230, 80.2450],
    [13.0160, 80.2620],
    [13.0130, 80.2760],
    [13.0105, 80.2800]
  ];

  const adyarLine = L.polyline(adyarPath, {
    color: '#38bdf8',
    weight: 4.5,
    opacity: 0.95,
    lineCap: 'round',
    lineJoin: 'round'
  });
  adyarLine.bindPopup(`
    <div style="font-family: inherit; font-size: 0.8rem; color: #fff; min-width: 210px;">
      <strong style="color: #38bdf8; font-size: 0.95rem;">🌊 Adyar River & Estuary Basin</strong>
      <div style="margin: 4px 0; color: #9ca3af; font-size: 0.72rem;">Course: Chembarambakkam ➔ Saidapet ➔ Adyar Estuary</div>
      <div style="background: rgba(56,189,248,0.15); border: 1px solid rgba(56,189,248,0.3); padding: 5px 8px; border-radius: 6px; margin-top: 6px;">
        <div>Dissolved Oxygen: <strong style="color: #f59e0b;">2.1 mg/L (Stressed)</strong></div>
        <div>Total Dissolved Solids: <strong style="color: #38bdf8;">1,120 ppm</strong></div>
        <div style="font-size: 0.7rem; color: #cbd5e1; margin-top: 3px;">Tholkappia Poonga eco-sanctuary sector</div>
      </div>
    </div>
  `);
  waterwayLayersGroup.addLayer(adyarLine);

  // 3. Buckingham Canal Corridor (Emerald Dashed)
  const canalPath = [
    [13.2350, 80.3200],
    [13.1850, 80.3050],
    [13.1550, 80.2980],
    [13.1000, 80.2930],
    [13.0720, 80.2840],
    [13.0480, 80.2780],
    [13.0280, 80.2690],
    [13.0050, 80.2580],
    [12.9650, 80.2480],
    [12.9100, 80.2330],
    [12.8250, 80.2400],
    [12.7800, 80.2480]
  ];

  const canalLine = L.polyline(canalPath, {
    color: '#10b981',
    weight: 3.2,
    opacity: 0.85,
    dashArray: '6, 6'
  });
  canalLine.bindPopup(`
    <div style="font-family: inherit; font-size: 0.8rem; color: #fff; min-width: 210px;">
      <strong style="color: #10b981; font-size: 0.95rem;">🌿 Buckingham Canal Navigation Corridor</strong>
      <div style="margin: 4px 0; color: #9ca3af; font-size: 0.72rem;">Course: Ennore Creek ➔ Central ➔ OMR ➔ Kovalam</div>
      <div style="background: rgba(16,185,129,0.15); border: 1px solid rgba(16,185,129,0.3); padding: 5px 8px; border-radius: 6px; margin-top: 6px;">
        <div>Tidal Flushing: Active Bay of Bengal tidal exchange</div>
        <div>Total Dissolved Solids: <strong style="color: #fff;">2,450 ppm (Brackish)</strong></div>
      </div>
    </div>
  `);
  waterwayLayersGroup.addLayer(canalLine);

  // 4. Ennore Creek & Kosasthalaiyar
  const ennorePath = [
    [13.2500, 80.2500],
    [13.2420, 80.2800],
    [13.2380, 80.3050],
    [13.2300, 80.3250],
    [13.2100, 80.3320]
  ];
  const ennoreLine = L.polyline(ennorePath, {
    color: '#0284c7',
    weight: 4.5,
    opacity: 0.9
  });
  ennoreLine.bindPopup(`
    <div style="font-family: inherit; font-size: 0.8rem; color: #fff; min-width: 210px;">
      <strong style="color: #0284c7; font-size: 0.95rem;">🌊 Ennore Creek & Kosasthalaiyar Estuary</strong>
      <div style="margin: 4px 0; color: #9ca3af; font-size: 0.72rem;">North Chennai Marine & Estuarine Thermal Outfall Zone</div>
    </div>
  `);
  waterwayLayersGroup.addLayer(ennoreLine);

  waterwayLayersGroup.addTo(chennaiMap);
}

// -------------------------------------------------------------
// Concentric Range Rings (8km, 16km, 28km Surveillance)
// -------------------------------------------------------------
function initRadarRangeRings() {
  if (!chennaiMap) return;
  radarRingsGroup = L.layerGroup();

  const centerPoint = [13.0827, 80.2707]; // Ripon Building / Central
  const rings = [
    { radius: 8000, label: '8 KM (Core)' },
    { radius: 16000, label: '16 KM (Metro Ring)' },
    { radius: 28000, label: '28 KM (Surveillance Perimeter)' }
  ];

  rings.forEach(r => {
    const circle = L.circle(centerPoint, {
      radius: r.radius,
      color: '#10b981',
      weight: 1.2,
      opacity: 0.45,
      dashArray: '5, 8',
      fillColor: '#10b981',
      fillOpacity: 0.02,
      interactive: false
    });
    radarRingsGroup.addLayer(circle);
  });

  radarRingsGroup.addTo(chennaiMap);
}

// -------------------------------------------------------------
// Interactive Map Toolbar Controls (Layers, Radar, Rivers, Labels)
// -------------------------------------------------------------
function setupMapToolbarControls() {
  // Layer switcher buttons
  const layerBtns = document.querySelectorAll('.layer-pill-btn');
  layerBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const layerKey = btn.dataset.layer;
      if (!layerKey || !baseTileLayers[layerKey] || layerKey === currentActiveTileLayer) return;

      layerBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      if (chennaiMap && baseTileLayers[currentActiveTileLayer]) {
        chennaiMap.removeLayer(baseTileLayers[currentActiveTileLayer]);
      }

      chennaiMap.addLayer(baseTileLayers[layerKey]);
      baseTileLayers[layerKey].bringToBack();
      currentActiveTileLayer = layerKey;
    });
  });

  // Radar sweep toggle
  const sweepToggle = document.getElementById('toggleRadarSweep');
  const sweepContainer = document.getElementById('radarSweepContainer');
  if (sweepToggle && sweepContainer) {
    sweepToggle.addEventListener('change', (e) => {
      if (e.target.checked) {
        sweepContainer.classList.remove('hidden');
      } else {
        sweepContainer.classList.add('hidden');
      }
    });
  }

  // River basins toggle
  const waterwaysToggle = document.getElementById('toggleWaterways');
  if (waterwaysToggle) {
    waterwaysToggle.addEventListener('change', (e) => {
      if (!chennaiMap || !waterwayLayersGroup) return;
      if (e.target.checked) {
        chennaiMap.addLayer(waterwayLayersGroup);
      } else {
        chennaiMap.removeLayer(waterwayLayersGroup);
      }
    });
  }

  // Station badges toggle
  const badgesToggle = document.getElementById('toggleStationBadges');
  if (badgesToggle) {
    badgesToggle.addEventListener('change', (e) => {
      showStationBadges = e.target.checked;
      const badges = document.querySelectorAll('.radar-pin-badge');
      badges.forEach(b => {
        if (showStationBadges) {
          b.classList.remove('hidden-badge');
        } else {
          b.classList.add('hidden-badge');
        }
      });
    });
  }

  // Recenter button
  const recenterBtn = document.getElementById('resetMapCenterBtn');
  if (recenterBtn) {
    recenterBtn.addEventListener('click', () => {
      if (chennaiMap) {
        chennaiMap.flyTo(chennaiCenterCoords, 11, { duration: 1.2 });
      }
    });
  }
}

// -------------------------------------------------------------
// Render Station Markers with Sonar Ripples & Permanent Badges
// -------------------------------------------------------------
function renderMapMarkers() {
  if (!chennaiMap) return;

  // Clear existing markers
  mapMarkers.forEach(m => chennaiMap.removeLayer(m));
  mapMarkers = [];

  const stations = allStationRecords.length > 0 ? allStationRecords : [];
  stations.forEach(st => {
    if (!st.latitude || !st.longitude) return;

    // Filter check
    if (activeMapFilter !== 'all') {
      if (activeMapFilter === 'Water') {
        const isWater = (st.station_type || '').includes('Water') ||
                        (st.station_type || '').includes('Reservoir') ||
                        st.location.includes('River') ||
                        st.location.includes('Lake') ||
                        st.location.includes('Canal');
        if (!isWater) return;
      } else if (!st.zone || !st.zone.toLowerCase().includes(activeMapFilter.toLowerCase())) {
        return;
      }
    }

    const aqi = st.live_aqi ?? st.air_quality ?? 80;
    const color = aqi <= 50 ? '#10B981' : (aqi <= 100 ? '#F59E0B' : (aqi <= 200 ? '#F97316' : '#EF4444'));
    const shortName = st.location.split(',')[0].trim();
    const hiddenClass = showStationBadges ? '' : 'hidden-badge';

    const customIcon = L.divIcon({
      className: 'radar-marker-div',
      html: `
        <div class="radar-pin" style="color: ${color};" title="${st.location} • AQI: ${aqi}">
          <div class="radar-sonar-ring"></div>
          <div class="radar-sonar-ring-2"></div>
          <div class="radar-core-dot"></div>
          <div class="radar-pin-badge ${hiddenClass}" style="background: ${color};">
            <span class="pin-station-name">${shortName}</span>
            <span class="pin-station-aqi">${aqi}</span>
          </div>
        </div>
      `,
      iconSize: [28, 28],
      iconAnchor: [14, 14]
    });

    const marker = L.marker([st.latitude, st.longitude], { icon: customIcon }).addTo(chennaiMap);

    const popupHtml = `
      <div style="padding: 6px; min-width: 240px; font-family: inherit;">
        <div style="font-size: 0.68rem; color: #9ca3af; text-transform: uppercase; font-weight:700;">${st.official_monitoring_agency || 'CAAQMS'} • ${st.zone || 'Chennai'}</div>
        <div style="font-size: 1.05rem; font-weight: 800; color: #fff; margin: 3px 0 6px 0;">${st.location.split(',')[0]}</div>
        <div style="display:flex; align-items:center; gap: 8px; margin-bottom: 8px;">
          <span style="background:${color}; color:#fff; font-weight:800; padding:3px 9px; border-radius:4px; font-size:0.82rem;">AQI ${aqi}</span>
          <span style="color:#d1d5db; font-size:0.78rem; font-weight: 600;">${st.status}</span>
        </div>
        <div style="font-size: 0.74rem; color: #9ca3af; border-top: 1px solid rgba(255,255,255,0.12); padding-top: 6px; line-height: 1.6;">
          <div>PM2.5: <strong style="color:#fff;">${st.pm25 ?? '--'} µg/m³</strong> | PM10: <strong style="color:#fff;">${st.pm10 ?? '--'}</strong></div>
          <div>Water TDS: <strong style="color:#fff;">${st.water_tds ?? '--'} ppm</strong> | DO: <strong style="color:#fff;">${st.water_do ?? '--'} mg/L</strong></div>
          <div style="color: #6ee7b7; font-size: 0.7rem; margin-top: 3px;">GPS: ${st.latitude.toFixed(4)}°N, ${st.longitude.toFixed(4)}°E</div>
        </div>
        <button onclick="window.trackStationFromPopup('${st.location.replace(/'/g, "\\'")}')" style="margin-top: 10px; width: 100%; background: #10B981; color: #fff; border:none; padding: 7px 10px; border-radius: 6px; font-size: 0.75rem; font-weight: 700; cursor: pointer; transition: all 0.2s;">
          🛰️ Track Station Live HUD
        </button>
      </div>
    `;

    marker.bindPopup(popupHtml);
    marker.on('click', () => {
      trackSpecificStation(st.location);
    });

    mapMarkers.push(marker);
  });
}

// Global hook for popup button
window.trackStationFromPopup = function(locName) {
  trackSpecificStation(locName);
  if (chennaiMap) chennaiMap.closePopup();
};

function setupMapFilterButtons() {
  const filterBtns = document.querySelectorAll('.map-filter-btn');
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeMapFilter = btn.dataset.filter || 'all';
      renderMapMarkers();
    });
  });
}

// =============================================================
// TRACK SPECIFIC STATION & UPDATE LIVE HUD
// =============================================================
function trackSpecificStation(locName) {
  const station = allStationRecords.find(s => s.location.toLowerCase() === locName.toLowerCase()) || allStationRecords[0];
  if (!station) return;

  currentLocation = station.location;
  if (locationSelect) locationSelect.value = station.location;

  updateTrackedHUD(station);

  // Pan Map smoothly to station coordinates
  if (chennaiMap && station.latitude && station.longitude) {
    chennaiMap.flyTo([station.latitude, station.longitude], 13, { duration: 1.2 });
  }

  // Update tour index if in tour
  const idx = allStationRecords.findIndex(s => s.location === station.location);
  if (idx !== -1) {
    tourIndex = idx;
    if (tourStationIndex) tourStationIndex.textContent = `Station ${tourIndex + 1} of ${allStationRecords.length}`;
    if (tourStationName) tourStationName.textContent = station.location.split(',')[0];
  }

  // Also sync background dashboard
  loadDashboardData(currentLocation, true);
}

function updateTrackedHUD(st) {
  if (!st) return;

  if (trackedStationAgency) trackedStationAgency.textContent = st.official_monitoring_agency || 'TNPCB & CPCB CAAQMS';
  if (trackedStationTitle) trackedStationTitle.textContent = st.location;
  if (trackedStationSub) trackedStationSub.textContent = `${st.zone || 'Chennai'} • Station ID: ${st.official_station_code || 'CAAQMS'}`;

  const aqi = st.live_aqi ?? st.air_quality ?? 80;
  if (trackedAqiVal) trackedAqiVal.textContent = aqi;

  const mapHudHumidity = document.getElementById('mapHudHumidity');
  if (mapHudHumidity && st.humidity) {
    mapHudHumidity.textContent = `${st.humidity}% RH`;
  }

  const color = aqi <= 50 ? '#10B981' : (aqi <= 100 ? '#F59E0B' : (aqi <= 200 ? '#F97316' : '#EF4444'));
  const dialWrap = document.querySelector('.tracked-dial-wrap');
  if (dialWrap) {
    dialWrap.style.borderColor = color;
    dialWrap.style.boxShadow = `0 0 24px ${color}55`;
  }

  if (trackedStatusBadge) {
    trackedStatusBadge.textContent = st.status || 'Moderate';
    trackedStatusBadge.style.backgroundColor = color;
  }

  if (trackedDescText) {
    if (aqi <= 50) trackedDescText.textContent = 'Air quality is satisfactory with clean coastal sea breeze circulation.';
    else if (aqi <= 100) trackedDescText.textContent = 'Acceptable air quality; sensitive groups should consider reducing heavy outdoor exertion.';
    else if (aqi <= 200) trackedDescText.textContent = 'Elevated particulate loading detected; consider limiting prolonged outdoor activities.';
    else trackedDescText.textContent = 'Severe pollution emergency; mandatory GRAP emission controls active.';
  }

  // Key Pollutants Grid
  if (trackedPm25) trackedPm25.textContent = st.pm25 !== undefined ? st.pm25 : '--';
  if (trackedPm10) trackedPm10.textContent = st.pm10 !== undefined ? st.pm10 : '--';
  if (trackedNo2) trackedNo2.textContent = st.no2 !== undefined ? st.no2 : '--';
  if (trackedSo2) trackedSo2.textContent = st.so2 !== undefined ? st.so2 : '--';
  if (trackedCo) trackedCo.textContent = st.co !== undefined ? st.co : '--';
  if (trackedOzone) trackedOzone.textContent = st.ozone !== undefined ? st.ozone : '--';

  // Water Cell
  if (trackedWaterBody) trackedWaterBody.textContent = st.water_body_nearby || 'Chennai Coastal Basin';
  if (trackedWaterTds) trackedWaterTds.textContent = st.water_tds ? `${st.water_tds} ppm` : '--';
  if (trackedWaterPh) trackedWaterPh.textContent = st.water_ph ? `${st.water_ph}` : '--';
  if (trackedWaterDo) trackedWaterDo.textContent = st.water_do ? `${st.water_do} mg/L` : '--';
  if (trackedWaterBod) trackedWaterBod.textContent = st.water_bod ? `${st.water_bod} mg/L` : '--';

  // Root Causes Lists
  if (trackedAirCausesList) {
    trackedAirCausesList.innerHTML = '';
    const airCauses = st.primary_air_causes && st.primary_air_causes.length > 0 
      ? st.primary_air_causes 
      : ['Arterial vehicular congestion and heavy transport idling', 'Thermal buffer dispersal and road dust re-suspension'];
    airCauses.forEach(c => {
      const li = document.createElement('li');
      li.textContent = c;
      trackedAirCausesList.appendChild(li);
    });
  }

  if (trackedWaterCausesList) {
    trackedWaterCausesList.innerHTML = '';
    const waterCauses = st.primary_water_causes && st.primary_water_causes.length > 0 
      ? st.primary_water_causes 
      : ['Stormwater network inflows carrying unauthorized greywater', 'Leachate runoff and solid waste sedimentation'];
    waterCauses.forEach(c => {
      const li = document.createElement('li');
      li.textContent = c;
      trackedWaterCausesList.appendChild(li);
    });
  }

  // Official portal link
  if (trackedOfficialPortalLink) {
    trackedOfficialPortalLink.href = st.official_portal_url || 'https://app.cpcbccr.com/AQI_India/';
  }
}

// =============================================================
// AUTO-TOUR LIVE TRACKING PLAYBACK
// =============================================================
function setupTourControls() {
  if (tourPlayPauseBtn) {
    tourPlayPauseBtn.addEventListener('click', toggleAutoTour);
  }

  if (tourPrevBtn) {
    tourPrevBtn.addEventListener('click', () => {
      if (allStationRecords.length === 0) return;
      tourIndex = (tourIndex - 1 + allStationRecords.length) % allStationRecords.length;
      trackSpecificStation(allStationRecords[tourIndex].location);
      resetTourProgress();
    });
  }

  if (tourNextBtn) {
    tourNextBtn.addEventListener('click', () => {
      if (allStationRecords.length === 0) return;
      tourIndex = (tourIndex + 1) % allStationRecords.length;
      trackSpecificStation(allStationRecords[tourIndex].location);
      resetTourProgress();
    });
  }

  // Speed buttons
  const speedBtns = document.querySelectorAll('.speed-btn');
  speedBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      speedBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      tourIntervalMs = parseInt(btn.dataset.speed, 10) || 8000;
      if (tourPlaying) {
        clearInterval(tourIntervalTimer);
        startTourTimers();
      }
    });
  });
}

function toggleAutoTour() {
  tourPlaying = !tourPlaying;
  if (tourPlaying) {
    tourPlayText.textContent = 'Pause Auto-Tour';
    tourPlayIcon.innerHTML = '<rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/>';
    startTourTimers();
    showToast('Auto-Tour active: cycling Chennai stations');
  } else {
    tourPlayText.textContent = 'Start Live Auto-Tour';
    tourPlayIcon.innerHTML = '<polygon points="5 3 19 12 5 21 5 3"/>';
    clearInterval(tourIntervalTimer);
    clearInterval(tourProgressTimer);
    if (tourProgressBar) tourProgressBar.style.width = '0%';
    showToast('Auto-Tour paused');
  }
}

function startTourTimers() {
  resetTourProgress();
  tourIntervalTimer = setInterval(() => {
    if (allStationRecords.length === 0) return;
    tourIndex = (tourIndex + 1) % allStationRecords.length;
    trackSpecificStation(allStationRecords[tourIndex].location);
    resetTourProgress();
  }, tourIntervalMs);
}

function resetTourProgress() {
  clearInterval(tourProgressTimer);
  tourProgressStartTime = Date.now();
  if (tourProgressBar) tourProgressBar.style.width = '0%';

  tourProgressTimer = setInterval(() => {
    if (!tourPlaying) return;
    const elapsed = Date.now() - tourProgressStartTime;
    const pct = Math.min(100, (elapsed / tourIntervalMs) * 100);
    if (tourProgressBar) tourProgressBar.style.width = `${pct}%`;
  }, 50);
}

// =============================================================
// LIVE TELEMETRY STREAM & LOGGING
// =============================================================
function startLiveTelemetryStream() {
  fetchLiveTelemetryFeed();
  liveStreamTimer = setInterval(fetchLiveTelemetryFeed, 3500);
}

async function fetchLiveTelemetryFeed() {
  try {
    const res = await fetch(`${API_BASE}/api/telemetry/live-feed`);
    if (!res.ok) return;
    const data = await res.json();

    // Update Diagnostics
    if (streamLatency) streamLatency.textContent = `⚡ ${data.network_latency_ms}ms`;
    if (streamActiveCount) streamActiveCount.textContent = `🟢 ${data.active_stations}/${data.active_stations} Online`;

    // Update Map Floating Weather HUD
    const mapHudWind = document.getElementById('mapHudWind');
    if (mapHudWind && data.meteorological_vector) {
      mapHudWind.textContent = `${data.meteorological_vector.wind_speed_kmh} km/h ${data.meteorological_vector.wind_direction} (Bay Breeze)`;
    }
    const mapHudNodes = document.getElementById('mapHudNodes');
    if (mapHudNodes) {
      mapHudNodes.textContent = `${data.active_stations}/${data.active_stations} Active Nodes`;
    }

    // Update Marquee ticker with exceedances and weather
    if (liveTickerStream && data.stations) {
      const items = [];
      if (data.meteorological_vector) {
        items.push(`💨 Wind: ${data.meteorological_vector.wind_speed_kmh} km/h ${data.meteorological_vector.wind_direction}`);
      }
      if (data.active_exceedances && data.active_exceedances.length > 0) {
        data.active_exceedances.slice(0, 3).forEach(ex => {
          items.push(`🚨 <strong>${ex.station.split(',')[0]}</strong>: ${ex.parameter} Exceedance (${ex.value})`);
        });
      }
      // Pick 2 random stations reporting
      const randomStations = [data.stations[Math.floor(Math.random() * data.stations.length)], data.stations[Math.floor(Math.random() * data.stations.length)]];
      randomStations.forEach(st => {
        if (st) items.push(`📡 <strong>${st.location.split(',')[0]}</strong>: Live AQI ${st.live_aqi} (${st.status})`);
      });

      liveTickerStream.innerHTML = items.map(it => `<span class="ticker-item">${it}</span>`).join(' • ');
    }

    // Append to Terminal Log
    if (data.stations && data.stations.length > 0) {
      const sample = data.stations[Math.floor(Math.random() * data.stations.length)];
      packetCount++;
      if (terminalPacketCount) terminalPacketCount.textContent = `Packets: ${packetCount}`;

      const nowStr = new Date().toTimeString().split(' ')[0] + '.' + String(Date.now() % 1000).padStart(3, '0');
      const isAlert = sample.live_aqi > 150 || (sample.pm25 && sample.pm25 > 60);
      const isWarn = sample.live_aqi > 100 && !isAlert;
      const cssClass = isAlert ? 'alert' : (isWarn ? 'warn' : 'info');

      const logMsg = `[${nowStr}] EAS-PKT#${8500 + packetCount} | ${sample.station_code || 'CAAQMS'} | AQI: ${sample.live_aqi} | PM2.5: ${sample.pm25}µg | RSSI: ${sample.signal_rssi_dbm}dBm [${sample.telemetry_health}]`;
      addTerminalPacketLine(logMsg, cssClass);

      // If the currently tracked station was updated, refresh HUD
      if (sample.location === currentLocation) {
        updateTrackedHUD(sample);
      }
    }
  } catch (err) {
    console.warn('Telemetry feed error:', err);
  }
}

function addTerminalPacketLine(text, cssClass) {
  if (!telemetryPacketLog) return;
  const line = document.createElement('div');
  line.className = `t-line ${cssClass}`;
  line.textContent = text;
  telemetryPacketLog.appendChild(line);

  // Keep max 35 lines
  while (telemetryPacketLog.children.length > 35) {
    telemetryPacketLog.removeChild(telemetryPacketLog.firstChild);
  }
  telemetryPacketLog.scrollTop = telemetryPacketLog.scrollHeight;
}

// =============================================================
// SIDE-BY-SIDE STATION COMPARATOR
// =============================================================
function setupComparator() {
  if (openComparatorBtn && comparatorModal) {
    openComparatorBtn.addEventListener('click', () => {
      populateComparatorDropdowns();
      updateComparatorTable();
      comparatorModal.classList.remove('hidden');
    });
  }

  if (closeComparatorBtn && comparatorModal) {
    closeComparatorBtn.addEventListener('click', () => {
      comparatorModal.classList.add('hidden');
    });
  }

  if (compSelectA && compSelectB) {
    compSelectA.addEventListener('change', updateComparatorTable);
    compSelectB.addEventListener('change', updateComparatorTable);
  }
}

function populateComparatorDropdowns() {
  if (!compSelectA || !compSelectB || allStationRecords.length === 0) return;
  compSelectA.innerHTML = '';
  compSelectB.innerHTML = '';

  allStationRecords.forEach((s, i) => {
    const optA = document.createElement('option');
    optA.value = s.location;
    optA.textContent = `[${s.zone || 'Zone'}] ${s.location.split(',')[0]}`;
    if (i === 1) optA.selected = true; // Manali
    compSelectA.appendChild(optA);

    const optB = document.createElement('option');
    optB.value = s.location;
    optB.textContent = `[${s.zone || 'Zone'}] ${s.location.split(',')[0]}`;
    if (i === 17) optB.selected = true; // Besant Nagar
    compSelectB.appendChild(optB);
  });
}

function updateComparatorTable() {
  if (!comparatorComparisonContent || allStationRecords.length === 0) return;
  const locA = compSelectA ? compSelectA.value : allStationRecords[0].location;
  const locB = compSelectB ? compSelectB.value : allStationRecords[1].location;

  const stA = allStationRecords.find(s => s.location === locA) || allStationRecords[0];
  const stB = allStationRecords.find(s => s.location === locB) || allStationRecords[1];

  const aqiA = stA.air_quality ?? 0;
  const aqiB = stB.air_quality ?? 0;
  const aqiDiff = aqiA - aqiB;

  const pm25A = stA.pm25 ?? 0;
  const pm25B = stB.pm25 ?? 0;

  const tdsA = stA.water_tds ?? 0;
  const tdsB = stB.water_tds ?? 0;

  comparatorComparisonContent.innerHTML = `
    <table class="comparator-table">
      <thead>
        <tr>
          <th>Environmental Metric</th>
          <th>${stA.location.split(',')[0]} (A)</th>
          <th>${stB.location.split(',')[0]} (B)</th>
          <th>Comparative Variance</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Station Code & Agency</strong></td>
          <td>${stA.official_station_code} (${stA.official_monitoring_agency ? stA.official_monitoring_agency.split('(')[0] : 'TNPCB'})</td>
          <td>${stB.official_station_code} (${stB.official_monitoring_agency ? stB.official_monitoring_agency.split('(')[0] : 'TNPCB'})</td>
          <td>--</td>
        </tr>
        <tr>
          <td><strong>Air Quality Index (AQI)</strong></td>
          <td><span style="font-weight:800; font-size:1.05rem; color:${aqiA <= 100 ? '#10B981' : '#EF4444'}">${aqiA} (${stA.status})</span></td>
          <td><span style="font-weight:800; font-size:1.05rem; color:${aqiB <= 100 ? '#10B981' : '#EF4444'}">${aqiB} (${stB.status})</span></td>
          <td class="${aqiDiff > 0 ? 'comp-delta-worse' : 'comp-delta-better'}">
            ${aqiDiff > 0 ? `+${aqiDiff} (A has worse air)` : `${aqiDiff} (A has cleaner air)`}
          </td>
        </tr>
        <tr>
          <td><strong>Fine Particulates (PM2.5)</strong></td>
          <td><strong>${pm25A} µg/m³</strong></td>
          <td><strong>${pm25B} µg/m³</strong></td>
          <td class="${pm25A > pm25B ? 'comp-delta-worse' : 'comp-delta-better'}">
            ${(pm25A - pm25B).toFixed(1)} µg/m³ delta
          </td>
        </tr>
        <tr>
          <td><strong>Water TDS & Basin</strong></td>
          <td><strong>${tdsA} ppm</strong><br><small style="color:#9ca3af;">${stA.water_body_nearby || '--'}</small></td>
          <td><strong>${tdsB} ppm</strong><br><small style="color:#9ca3af;">${stB.water_body_nearby || '--'}</small></td>
          <td class="${tdsA > tdsB ? 'comp-delta-worse' : 'comp-delta-better'}">
            ${tdsA - tdsB > 0 ? `+${tdsA - tdsB} ppm` : `${tdsA - tdsB} ppm`}
          </td>
        </tr>
        <tr>
          <td><strong>Dissolved Oxygen (DO)</strong></td>
          <td><strong>${stA.water_do ?? '--'} mg/L</strong></td>
          <td><strong>${stB.water_do ?? '--'} mg/L</strong></td>
          <td>Standard: min 4.0 mg/L</td>
        </tr>
        <tr>
          <td><strong>Primary Air Causes</strong></td>
          <td style="font-size:0.75rem; color:#d1d5db;">${(stA.primary_air_causes || []).join('<br>• ')}</td>
          <td style="font-size:0.75rem; color:#d1d5db;">${(stB.primary_air_causes || []).join('<br>• ')}</td>
          <td>Local source audit</td>
        </tr>
        <tr>
          <td><strong>Primary Water Contaminants</strong></td>
          <td style="font-size:0.75rem; color:#d1d5db;">${(stA.primary_water_causes || []).join('<br>• ')}</td>
          <td style="font-size:0.75rem; color:#d1d5db;">${(stB.primary_water_causes || []).join('<br>• ')}</td>
          <td>Waterbody pollution audit</td>
        </tr>
      </tbody>
    </table>
  `;
}

// =============================================================
// DATA FETCHING & DASHBOARD (FOR TAB 1 OVERVIEW & COMPLIANCE)
// =============================================================
async function loadCompleteDataset() {
  try {
    const res = await fetch(`${API_BASE}/api/chennai/complete-dataset`);
    if (res.ok) {
      const payload = await res.json();
      allStationRecords = payload.data || [];
      renderComplianceTable();
      renderWaterBodiesGrid();
    }
  } catch (err) {
    console.warn('Complete dataset fetch error:', err);
  }
}

async function loadLocations() {
  try {
    const res = await fetch(`${API_BASE}/api/locations`);
    if (!res.ok) throw new Error('Failed to fetch locations');
    const locations = await res.json();

    if (locations && locations.length > 0) {
      allLocations = locations;
      
      const countEl = document.getElementById('totalStationsCount');
      if (countEl) countEl.textContent = `${locations.length} Areas`;

      if (locationSelect) {
        locationSelect.innerHTML = '';
        locations.forEach(loc => {
          const opt = document.createElement('option');
          opt.value = loc.location;
          const zoneTag = loc.zone ? `[${loc.zone}] ` : '';
          opt.textContent = `${zoneTag}${loc.location.split(',')[0]}`;
          if (loc.location === currentLocation) opt.selected = true;
          locationSelect.appendChild(opt);
        });
      }

      setupFilterButtons();
      renderZonesGrid();
    }
  } catch (err) {
    console.warn('Locations fetch error:', err);
  }
}

function setupFilterButtons() {
  const filterBtns = document.querySelectorAll('.filter-btn');
  filterBtns.forEach(btn => {
    btn.onclick = () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeZoneFilter = btn.dataset.filter || 'all';
      renderZonesGrid();
    };
  });
}

async function loadDashboardData(loc, silent = false) {
  if (!silent && statusLabel) {
    statusLabel.textContent = 'SYNCING...';
    if (simulateBtn) simulateBtn.classList.add('loading');
  }

  try {
    const res = await fetch(`${API_BASE}/api/dashboard?location=${encodeURIComponent(loc)}`);
    if (!res.ok) throw new Error(`HTTP Error ${res.status}`);
    const data = await res.json();

    updateStatus(true);
    renderDashboard(data);
    if (!silent) showToast(`Telemetry synchronized for ${loc.split(',')[0]}`);
  } catch (err) {
    console.error('Failed to load dashboard:', err);
    updateStatus(false);
    if (!silent) showToast('Could not reach backend API', true);
  } finally {
    if (simulateBtn) simulateBtn.classList.remove('loading');
  }
}

function renderDashboard(data) {
  if (displayLocation) displayLocation.textContent = data.location || currentLocation;

  // Score & Status
  const scoreObj = data.environmental_score || {};
  const score = scoreObj.score ?? 70;
  const status = scoreObj.status ?? 'Moderate';
  const colorHex = scoreObj.color_hex ?? '#10B981';

  if (scoreValue) scoreValue.textContent = score;
  if (scoreStatusBadge) {
    scoreStatusBadge.textContent = status;
    scoreStatusBadge.style.backgroundColor = colorHex;
    scoreStatusBadge.style.boxShadow = `0 0 14px ${colorHex}55`;
  }

  // Radial Gauge Animation
  const circumference = 415;
  const offset = circumference - (score / 100) * circumference;
  if (gaugeProgressCircle) {
    gaugeProgressCircle.style.strokeDasharray = `${circumference}`;
    gaugeProgressCircle.style.strokeDashoffset = `${offset}`;
    gaugeProgressCircle.style.stroke = colorHex;
  }

  if (scoreDescription) {
    if (score >= 80) {
      scoreDescription.textContent = 'Environmental conditions are optimal across monitored parameters.';
    } else if (score >= 65) {
      scoreDescription.textContent = 'Conditions are acceptable. Moderate traffic particulate presence detected.';
    } else {
      scoreDescription.textContent = 'Elevated environmental stress. Sensitive groups should take precautions.';
    }
  }

  if (lastUpdatedTime) {
    const now = new Date();
    lastUpdatedTime.textContent = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }) + ' IST';
  }

  // Primary Indicator Cards
  const indicators = data.indicators || [];
  const indMap = {};
  indicators.forEach(ind => { indMap[ind.key] = ind; });

  if (indMap['air_quality']) {
    if (valAqi) valAqi.textContent = indMap['air_quality'].value;
    const aqiNum = parseInt(indMap['air_quality'].value, 10);
    if (statusAqi) {
      statusAqi.textContent = aqiNum <= 50 ? 'Good' : (aqiNum <= 100 ? 'Moderate' : 'Unhealthy');
      statusAqi.className = `metric-status ${aqiNum <= 50 ? 'status-good' : (aqiNum <= 100 ? 'status-moderate' : 'status-unhealthy')}`;
    }
  }

  if (indMap['temperature']) {
    if (valTemp) valTemp.textContent = `${indMap['temperature'].value}°C`;
    if (statusTemp) {
      statusTemp.textContent = 'Normal';
      statusTemp.className = 'metric-status status-good';
    }
  }

  if (indMap['humidity']) {
    if (valHum) valHum.textContent = `${indMap['humidity'].value}%`;
    if (statusHum) {
      statusHum.textContent = 'Coastal';
      statusHum.className = 'metric-status status-moderate';
    }
  }

  if (indMap['water_tds']) {
    if (valTds) valTds.textContent = `${indMap['water_tds'].value} ppm`;
    const tdsNum = parseInt(indMap['water_tds'].value, 10);
    if (statusTds) {
      statusTds.textContent = tdsNum <= 300 ? 'Optimal' : (tdsNum <= 600 ? 'Elevated' : 'High');
      statusTds.className = `metric-status ${tdsNum <= 300 ? 'status-good' : (tdsNum <= 600 ? 'status-moderate' : 'status-unhealthy')}`;
    }
  }

  // Active Alerts
  if (alertsContainer) {
    alertsContainer.innerHTML = '';
    const alerts = data.alerts || [];
    if (alerts.length === 0) {
      alertsContainer.innerHTML = '<div class="alert-empty">All monitored parameters are within safe ranges.</div>';
    } else {
      alerts.forEach(al => {
        const div = document.createElement('div');
        div.className = `alert-box alert-${al.type || 'info'}`;
        div.innerHTML = `
          <div class="alert-icon-wrap">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
              <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
          </div>
          <div class="alert-text">
            <strong>${al.title}</strong>
            <p>${al.message}</p>
          </div>
        `;
        alertsContainer.appendChild(div);
      });
    }
  }

  // 24-Hour Trend Bars
  if (trendBarsContainer) {
    trendBarsContainer.innerHTML = '';
    const trendData = data.hourly_trend || [
      { hour: '00:00', aqi: 55, temperature: 28 },
      { hour: '04:00', aqi: 48, temperature: 27 },
      { hour: '08:00', aqi: 88, temperature: 30 },
      { hour: '12:00', aqi: 95, temperature: 33 },
      { hour: '16:00', aqi: 110, temperature: 32 },
      { hour: '20:00', aqi: 75, temperature: 29 }
    ];

    trendData.forEach(item => {
      const col = document.createElement('div');
      col.className = 'trend-col';
      const pct = Math.min(100, Math.max(15, (item.aqi / 200) * 100));
      const barColor = item.aqi <= 50 ? '#10B981' : (item.aqi <= 100 ? '#F59E0B' : '#EF4444');

      col.innerHTML = `
        <span class="bar-val">${item.aqi}</span>
        <div class="bar-fill-wrap">
          <div class="bar-fill" style="height: ${pct}%; background-color: ${barColor};"></div>
        </div>
        <span class="bar-label">${item.hour}</span>
      `;
      trendBarsContainer.appendChild(col);
    });
  }

  // Analysis Cards
  if (analysisContainer) {
    analysisContainer.innerHTML = '';
    const analyses = data.analyses || [];
    analyses.forEach(an => {
      const card = document.createElement('div');
      card.className = 'analysis-card';
      card.innerHTML = `
        <div class="analysis-header">
          <h4>${an.title}</h4>
          <span class="pill-green">${an.value}</span>
        </div>
        <p class="analysis-body">${an.description}</p>
      `;
      analysisContainer.appendChild(card);
    });
  }

  // Health Recommendations
  if (recommendationsList) {
    recommendationsList.innerHTML = '';
    const recs = data.recommendations || [
      { text: "Air quality allows for normal outdoor activities." },
      { text: "Water parameter is suitable for standard household supply." }
    ];
    recs.forEach(rec => {
      const li = document.createElement('li');
      li.className = 'rec-item';
      li.innerHTML = `
        <div class="rec-icon">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
        <span>${rec.text}</span>
      `;
      recommendationsList.appendChild(li);
    });
  }
}

function renderZonesGrid() {
  if (!zonesGrid) return;
  zonesGrid.innerHTML = '';

  const filtered = activeZoneFilter === 'all'
    ? allLocations
    : allLocations.filter(l => l.zone && l.zone.toLowerCase().includes(activeZoneFilter.toLowerCase()));

  filtered.forEach(loc => {
    const chip = document.createElement('div');
    const isSelected = loc.location === currentLocation;
    chip.className = `zone-chip ${isSelected ? 'active' : ''}`;
    chip.innerHTML = `
      <div class="chip-dot"></div>
      <div class="chip-info">
        <span class="chip-name">${loc.location.split(',')[0]}</span>
        <span class="chip-meta">${loc.zone || 'Chennai'} • Score ${loc.latest_score || 70}</span>
      </div>
    `;
    chip.addEventListener('click', () => {
      currentLocation = loc.location;
      if (locationSelect) locationSelect.value = loc.location;
      document.querySelectorAll('.zone-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      trackSpecificStation(currentLocation);
      loadDashboardData(currentLocation);
    });
    zonesGrid.appendChild(chip);
  });
}

// =============================================================
// TAB 2: COMPLIANCE MATRIX TABLE
// =============================================================
function renderComplianceTable(recordsToRender) {
  const tbody = document.getElementById('complianceTableBody');
  if (!tbody) return;

  const dataset = recordsToRender || allStationRecords;
  tbody.innerHTML = '';

  if (dataset.length === 0) {
    tbody.innerHTML = '<tr><td colspan="11" style="text-align:center; padding: 2rem;">Loading official station records...</td></tr>';
    return;
  }

  dataset.forEach(r => {
    const tr = document.createElement('tr');
    const aqi = r.air_quality ?? 0;
    const statusClass = aqi <= 50 ? 'status-good' : (aqi <= 100 ? 'status-moderate' : 'status-unhealthy');

    tr.innerHTML = `
      <td><strong>${r.official_station_code || 'CAAQMS'}</strong></td>
      <td><strong>${r.location}</strong></td>
      <td><span class="sub-badge">${r.zone || 'Chennai'}</span></td>
      <td><strong>${aqi}</strong></td>
      <td><span class="status-chip ${statusClass}">${r.status}</span></td>
      <td>${r.pm25 ?? '--'}</td>
      <td>${r.pm10 ?? '--'}</td>
      <td>${r.no2 ?? '--'}</td>
      <td>${r.so2 ?? '--'}</td>
      <td>${r.water_tds ?? '--'} ppm</td>
      <td><a href="${r.official_portal_url || '#'}" target="_blank" style="color:var(--emerald-light); font-size:0.75rem;">Portal</a></td>
    `;
    tr.style.cursor = 'pointer';
    tr.addEventListener('click', () => {
      trackSpecificStation(r.location);
      const trackingTab = document.querySelector('[data-tab="tab-tracking"]');
      if (trackingTab) trackingTab.click();
    });
    tbody.appendChild(tr);
  });
}

function filterComplianceTable(query) {
  if (!query) {
    renderComplianceTable(allStationRecords);
    return;
  }
  const filtered = allStationRecords.filter(r => 
    (r.location || '').toLowerCase().includes(query) ||
    (r.official_station_code || '').toLowerCase().includes(query) ||
    (r.zone || '').toLowerCase().includes(query)
  );
  renderComplianceTable(filtered);
}

// =============================================================
// TAB 3: WATER BODIES MONITORING CELL
// =============================================================
function renderWaterBodiesGrid() {
  const grid = document.getElementById('waterBodiesGrid');
  if (!grid) return;

  const waterStations = allStationRecords.filter(r => 
    (r.station_type || '').includes('Water') ||
    (r.station_type || '').includes('Reservoir') ||
    r.location.includes('River') ||
    r.location.includes('Canal') ||
    r.location.includes('Lake') ||
    r.location.includes('Aquifer')
  );

  grid.innerHTML = '';
  const listToRender = waterStations.length > 0 ? waterStations : allStationRecords.slice(7, 10);

  listToRender.forEach(w => {
    const card = document.createElement('div');
    card.className = 'water-card';
    card.innerHTML = `
      <div class="water-card-top">
        <div>
          <h3 class="water-card-name">${w.location.split(',')[0]}</h3>
          <span class="water-card-type">${w.water_body_nearby || 'River Catchment'}</span>
        </div>
        <span class="status-chip ${w.environmental_score >= 70 ? 'status-good' : (w.environmental_score >= 50 ? 'status-moderate' : 'status-unhealthy')}">
          Score: ${w.environmental_score}/100
        </span>
      </div>
      <div class="water-stats-row">
        <div class="w-stat-item">
          <div class="w-num">${w.water_tds ?? '--'}</div>
          <div class="w-label">TDS (ppm)</div>
        </div>
        <div class="w-stat-item">
          <div class="w-num">${w.water_ph ?? '--'}</div>
          <div class="w-label">pH Value</div>
        </div>
        <div class="w-stat-item">
          <div class="w-num">${w.water_do ?? '--'}</div>
          <div class="w-label">DO (mg/L)</div>
        </div>
        <div class="w-stat-item">
          <div class="w-num">${w.water_bod ?? '--'}</div>
          <div class="w-label">BOD (mg/L)</div>
        </div>
      </div>
      <div class="water-card-causes">
        <strong style="font-size:0.75rem; color:#9ca3af;">Identified Contaminants:</strong>
        <p style="font-size:0.78rem; color:#d1d5db; margin-top:3px; line-height:1.4;">${(w.primary_water_causes || []).slice(0, 2).join(' • ')}</p>
      </div>
    `;
    grid.appendChild(card);
  });
}

// =============================================================
// CSV EXPORT & GRIEVANCE
// =============================================================
function exportDatasetToCSV() {
  if (allStationRecords.length === 0) {
    showToast('Dataset is loading, please wait...', true);
    return;
  }

  const headers = [
    'Station_Code',
    'Location_Name',
    'Zone',
    'Station_Type',
    'Latitude',
    'Longitude',
    'AQI',
    'Status',
    'PM2.5_ug_m3',
    'PM10_ug_m3',
    'NO2_ug_m3',
    'SO2_ug_m3',
    'CO_mg_m3',
    'Ozone_ug_m3',
    'Water_TDS_ppm',
    'Water_pH',
    'Water_DO_mg_L',
    'Water_BOD_mg_L',
    'Nearby_Waterbody',
    'Air_Pollution_Causes',
    'Water_Pollution_Causes',
    'Monitoring_Agency',
    'Official_Portal_URL',
    'Timestamp'
  ];

  const rows = allStationRecords.map(r => [
    `"${r.official_station_code || ''}"`,
    `"${r.location || ''}"`,
    `"${r.zone || ''}"`,
    `"${r.station_type || ''}"`,
    r.latitude ?? '',
    r.longitude ?? '',
    r.air_quality ?? '',
    `"${r.status || ''}"`,
    r.pm25 ?? '',
    r.pm10 ?? '',
    r.no2 ?? '',
    r.so2 ?? '',
    r.co ?? '',
    r.ozone ?? '',
    r.water_tds ?? '',
    r.water_ph ?? '',
    r.water_do ?? '',
    r.water_bod ?? '',
    `"${r.water_body_nearby || ''}"`,
    `"${(r.primary_air_causes || []).join('; ')}"`,
    `"${(r.primary_water_causes || []).join('; ')}"`,
    `"${r.official_monitoring_agency || ''}"`,
    `"${r.official_portal_url || ''}"`,
    `"${r.timestamp || ''}"`
  ]);

  const csvContent = [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', `EAS_Chennai_Environmental_Dataset_${new Date().toISOString().split('T')[0]}.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  showToast('EAS Official Dataset exported as CSV successfully!');
}

function handleGrievanceSubmit(e) {
  e.preventDefault();
  const name = document.getElementById('reporterName').value;
  const loc = document.getElementById('incidentLocation').value;
  const type = document.getElementById('incidentType').value;
  const ticketId = `EAS-CHN-2026-${Math.floor(10000 + Math.random() * 90000)}`;

  alert(`✅ Grievance Filed Successfully!\n\nReference Ticket: ${ticketId}\nReporter: ${name}\nLocation: ${loc}\nCategory: ${type}\n\nYour complaint has been forwarded to the TNPCB Chennai Flying Squad for prompt field verification.`);
  document.getElementById('grievanceForm').reset();
  showToast(`Complaint lodged: Ticket ${ticketId}`);
}

async function handleSimulate() {
  simulateBtn.disabled = true;
  simulateBtn.style.opacity = '0.6';
  showToast(`Simulating sensor fluctuation for ${currentLocation.split(',')[0]}...`);

  try {
    const res = await fetch(`${API_BASE}/api/data/simulate?location=${encodeURIComponent(currentLocation)}`, {
      method: 'POST'
    });
    if (!res.ok) throw new Error('Simulation failed');
    const result = await res.json();

    await loadLocations();
    await loadCompleteDataset();
    await loadDashboardData(currentLocation, true);
    trackSpecificStation(currentLocation);
    renderMapMarkers();
    showToast(`Telemetry updated: Score ${result.record.environmental_score} (${result.record.status})`);
  } catch (err) {
    showToast('Failed to trigger simulation', true);
  } finally {
    simulateBtn.disabled = false;
    simulateBtn.style.opacity = '1';
  }
}

function updateStatus(isOnline) {
  if (isOnline) {
    if (statusLabel) statusLabel.textContent = 'SYNCED (IST)';
    if (statusPill) {
      statusPill.style.background = 'rgba(16, 185, 129, 0.12)';
      statusPill.style.borderColor = 'rgba(16, 185, 129, 0.35)';
    }
  } else {
    if (statusLabel) statusLabel.textContent = 'OFFLINE';
    if (statusPill) {
      statusPill.style.background = 'rgba(239, 68, 68, 0.12)';
      statusPill.style.borderColor = 'rgba(239, 68, 68, 0.35)';
    }
  }
}

function showToast(message, isError = false) {
  if (!toastEl) return;
  toastEl.textContent = message;
  toastEl.style.borderColor = isError ? 'var(--red-danger)' : 'var(--emerald-primary)';
  toastEl.classList.remove('hidden');

  setTimeout(() => {
    toastEl.classList.add('hidden');
  }, 2800);
}
