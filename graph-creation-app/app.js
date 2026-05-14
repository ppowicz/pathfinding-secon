const DEFAULT_CENTER = { lat: 52.253, lon: 20.8993 };
const DEFAULT_ZOOM = 18;
const FILE_VERSION = 1;
const IDB_NAME = "secon-graph-mapper-db";
const IDB_STORE = "handles";
const HANDLE_KEY = "workspaceDirHandle";

const SETTINGS_FILE = "settings.json";
const POINTS_FILE = "points.csv";
const EDGES_FILE = "edges.csv";

const state = {
  settings: {
    fileVersion: FILE_VERSION,
    mapCenter: DEFAULT_CENTER,
    mapZoom: DEFAULT_ZOOM,
    lastMode: "points",
    nextPointId: 1,
    nextEdgeId: 1,
  },
  points: [],
  edges: [],
  mode: "points",
  dirHandle: null,
  sourcePointId: null,
  draftLine: null,
  justDraggedPointId: null,
  justDraggedUntil: 0,
  pointSort: {
    key: null,
    direction: null,
  },
};
let persistChain = Promise.resolve();

const el = {
  pickFolderBtn: document.getElementById("pick-folder-btn"),
  reloadBtn: document.getElementById("reload-btn"),
  modePointsBtn: document.getElementById("mode-points-btn"),
  modeEdgesBtn: document.getElementById("mode-edges-btn"),
  pointsCount: document.getElementById("points-count"),
  edgesCount: document.getElementById("edges-count"),
  mapStatus: document.getElementById("map-status"),
  mapStatusIcon: document.getElementById("map-status-icon"),
  mapStatusText: document.getElementById("map-status-text"),
  liveControlsTitle: document.getElementById("live-controls-title"),
  liveControlsList: document.getElementById("live-controls-list"),
  pointsTableBody: document.getElementById("points-table-body"),
  pointSortButtons: Array.from(document.querySelectorAll(".sort-header")),
};

const map = L.map("map", {
  center: [DEFAULT_CENTER.lat, DEFAULT_CENTER.lon],
  zoom: DEFAULT_ZOOM,
  zoomControl: true,
});

const imageryLayer = L.tileLayer(
  "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
  {
    attribution:
      "Tiles &copy; Esri &mdash; Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community",
    maxZoom: 21,
  }
).addTo(map);

const osmOverlayLayer = L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
  attribution: "&copy; OpenStreetMap contributors",
  maxZoom: 21,
  opacity: 0.42,
}).addTo(map);

const markerLayer = L.layerGroup().addTo(map);
const edgeLayer = L.layerGroup().addTo(map);

const markerById = new Map();
const edgeLineById = new Map();
const markerIcon = L.divIcon({
  className: "graph-node-icon",
  html: '<div style="width:12px;height:12px;border-radius:50%;background:#0f6dff;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.35);"></div>',
  iconSize: [12, 12],
  iconAnchor: [6, 6],
});

init().catch((error) => {
  setStatus(`Błąd inicjalizacji: ${error.message}`, true);
  // eslint-disable-next-line no-console
  console.error(error);
});

async function init() {
  wireUi();
  disableBrowserContextMenu();

  setStatus("Sprawdzam zapisany folder danych...", "loading");
  const restoredHandle = await loadDirectoryHandle();

  if (restoredHandle) {
    const hasPermission = await ensureDirectoryPermission(restoredHandle, "readwrite", false);
    if (hasPermission) {
      state.dirHandle = restoredHandle;
      await loadAllFromDisk();
      setStatus("Połączono z plikami danych.", "success");
    } else {
      setStatus("Brak uprawnień do folderu danych. Wybierz folder ponownie.", "error");
    }
  } else {
    setStatus("Brak połączenia z plikami danych. Wybierz folder danych.", "error");
  }

  applySettingsToMap();
  setMode(state.settings.lastMode || "points", false);
  redrawAll();
  renderLiveControls();
}

function wireUi() {
  el.pickFolderBtn.addEventListener("click", onPickFolder);
  el.reloadBtn.addEventListener("click", onReloadFromDisk);
  el.modePointsBtn.addEventListener("click", () => setMode("points", true));
  el.modeEdgesBtn.addEventListener("click", () => setMode("edges", true));
  window.addEventListener("keydown", onGlobalKeyDown);
  for (const button of el.pointSortButtons) {
    button.addEventListener("click", onPointSortClick);
  }

  map.on("click", onMapLeftClick);
  map.on("contextmenu", onMapRightClick);
  map.on("mousemove", onMapMouseMove);
  map.on("moveend", onMapMoveEnd);
}

function onPointSortClick(event) {
  const key = event.currentTarget.dataset.sortKey;
  if (!key) {
    return;
  }

  if (state.pointSort.key !== key) {
    state.pointSort = { key, direction: "asc" };
  } else if (state.pointSort.direction === "asc") {
    state.pointSort = { key, direction: "desc" };
  } else if (state.pointSort.direction === "desc") {
    state.pointSort = { key: null, direction: null };
  } else {
    state.pointSort = { key, direction: "asc" };
  }

  renderPointsTable();
}

function onGlobalKeyDown(event) {
  if (event.key !== "Tab" || event.defaultPrevented || event.ctrlKey || event.metaKey || event.altKey) {
    return;
  }

  event.preventDefault();
  const nextMode = state.mode === "points" ? "edges" : "points";
  setMode(nextMode, true);
  setStatus(nextMode === "points" ? "Przełączono: tryb punktów (Tab)." : "Przełączono: tryb połączeń (Tab).");
}

function disableBrowserContextMenu() {
  const mapElement = document.getElementById("map");
  mapElement.addEventListener("contextmenu", (event) => {
    event.preventDefault();
  });
}

async function onPickFolder() {
  if (!window.showDirectoryPicker) {
    setStatus("Ta przeglądarka nie obsługuje File System Access API (użyj Chrome/Edge).", true);
    return;
  }

  try {
    setStatus("Wybierz folder danych...", "loading");
    const handle = await window.showDirectoryPicker({ mode: "readwrite" });
    const granted = await ensureDirectoryPermission(handle, "readwrite", true);

    if (!granted) {
      setStatus("Nie przyznano uprawnień zapisu do folderu.", true);
      return;
    }

    state.dirHandle = handle;
    await saveDirectoryHandle(handle);

    await ensureFilesExist();
    await loadAllFromDisk();
    redrawAll();
    await persistAll();

    setStatus("Połączono z plikami. Autosave aktywny.", "success");
  } catch (error) {
    if (error.name === "AbortError") {
      setStatus("Brak połączenia z plikami danych. Wybór folderu anulowany.", "error");
      return;
    }
    setStatus(`Nie udało się podłączyć folderu: ${error.message}`, true);
  }
}

async function onReloadFromDisk() {
  if (!state.dirHandle) {
    setStatus("Najpierw wybierz folder danych.", true);
    return;
  }

  try {
    setStatus("Wczytywanie danych z plików...", "loading");
    await loadAllFromDisk();
    applySettingsToMap();
    setMode(state.settings.lastMode || "points", false);
    redrawAll();
    setStatus("Dane zostały odświeżone z plików.", "success");
  } catch (error) {
    setStatus(`Błąd odczytu plików: ${error.message}`, true);
  }
}

function onMapLeftClick(event) {
  if (state.mode === "points") {
    addPoint(event.latlng.lat, event.latlng.lng);
    return;
  }

  if (state.mode === "edges") {
    if (state.sourcePointId !== null) {
      // Left click on map when drawing an edge should not create a point.
      return;
    }
  }
}

function onMapRightClick(event) {
  event.originalEvent.preventDefault();

  if (state.mode === "edges" && state.sourcePointId !== null) {
    cancelDraftEdge();
    setStatus("Tworzenie połączenia anulowane.");
  }
}

function onMapMouseMove(event) {
  if (state.mode !== "edges" || state.sourcePointId === null || !state.draftLine) {
    return;
  }

  const sourcePoint = getPointById(state.sourcePointId);
  if (!sourcePoint) {
    cancelDraftEdge();
    return;
  }

  state.draftLine.setLatLngs([
    [sourcePoint.lat, sourcePoint.lon],
    [event.latlng.lat, event.latlng.lng],
  ]);
}

function onMapMoveEnd() {
  const center = map.getCenter();
  state.settings.mapCenter = {
    lat: roundCoordinate(center.lat),
    lon: roundCoordinate(center.lng),
  };
  state.settings.mapZoom = map.getZoom();
  void persistAll();
}

function setMode(mode, persist) {
  state.mode = mode;
  state.settings.lastMode = mode;

  el.modePointsBtn.classList.toggle("active", mode === "points");
  el.modeEdgesBtn.classList.toggle("active", mode === "edges");

  if (mode !== "edges") {
    cancelDraftEdge();
  }

  renderLiveControls();

  if (persist) {
    void persistAll();
  }
}

function applySettingsToMap() {
  const { mapCenter, mapZoom } = state.settings;
  if (!mapCenter || typeof mapZoom !== "number") {
    return;
  }

  map.setView([mapCenter.lat, mapCenter.lon], mapZoom, { animate: false });
}

function addPoint(lat, lon) {
  const point = {
    id: state.settings.nextPointId,
    lat: roundCoordinate(lat),
    lon: roundCoordinate(lon),
    name: "",
  };

  state.settings.nextPointId += 1;
  state.points.push(point);

  renderPoint(point);
  refreshCounters();
  void persistAll();
}

function removePoint(pointId) {
  const beforePoints = state.points.length;
  const beforeEdges = state.edges.length;

  state.points = state.points.filter((point) => point.id !== pointId);
  state.edges = state.edges.filter((edge) => edge.from_id !== pointId && edge.to_id !== pointId);

  if (state.sourcePointId === pointId) {
    cancelDraftEdge();
  }

  if (state.points.length === beforePoints) {
    return;
  }

  redrawAll();
  setStatus(
    `Usunięto punkt ${pointId} i ${beforeEdges - state.edges.length} powiązanych połączeń.`
  );
  void persistAll();
}

function renderPoint(point) {
  const marker = L.marker([point.lat, point.lon], {
    icon: markerIcon,
    riseOnHover: true,
    draggable: true,
  });

  marker.on("click", (event) => {
    onPointLeftClick(event, point.id);
  });

  marker.on("contextmenu", (event) => {
    onPointRightClick(event, point.id);
  });

  marker.on("dblclick", (event) => {
    onPointDoubleClick(event, point.id);
  });

  marker.on("dragstart", (event) => {
    onPointDragStart(event, point.id);
  });

  marker.on("drag", (event) => {
    onPointDrag(event, point.id);
  });

  marker.on("dragend", (event) => {
    onPointDragEnd(event, point.id);
  });

  marker.bindTooltip(formatPointTooltip(point), {
    direction: "top",
    offset: [0, -8],
    opacity: 0.9,
  });

  marker.addTo(markerLayer);
  markerById.set(point.id, marker);
}

function onPointLeftClick(event, pointId) {
  L.DomEvent.stop(event);

  if (state.justDraggedPointId === pointId && Date.now() < state.justDraggedUntil) {
    return;
  }

  if (state.mode === "points") {
    return;
  }

  if (state.mode === "edges") {
    if (state.sourcePointId === null) {
      startDraftEdge(pointId);
      return;
    }

    if (state.sourcePointId === pointId) {
      setStatus("Wybierz inny punkt docelowy.");
      return;
    }

    const created = createUndirectedEdge(state.sourcePointId, pointId);
    if (created) {
      setStatus(`Dodano połączenie: ${state.sourcePointId} ↔ ${pointId}.`);
      void persistAll();
    }
    cancelDraftEdge();
  }
}

function onPointRightClick(event, pointId) {
  L.DomEvent.stop(event);

  if (state.mode === "edges" && state.sourcePointId !== null) {
    cancelDraftEdge();
    setStatus("Tworzenie połączenia anulowane.");
    return;
  }

  removePoint(pointId);
}

function onPointDoubleClick(event, pointId) {
  L.DomEvent.stop(event);

  if (state.mode !== "points") {
    setStatus("Edycja nazwy jest dostępna tylko w trybie punktów.");
    return;
  }

  const point = getPointById(pointId);
  if (!point) {
    return;
  }

  const nextName = window.prompt("Nazwa punktu (opcjonalna):", point.name || "");
  if (nextName === null) {
    return;
  }

  point.name = nextName.trim();
  const marker = markerById.get(pointId);
  if (marker) {
    marker.setTooltipContent(formatPointTooltip(point));
  }
  void persistAll();
}

function onPointDragStart(event) {
  L.DomEvent.stop(event);
}

function onPointDrag(event, pointId) {
  const marker = markerById.get(pointId);
  if (!marker) {
    return;
  }

  const latLng = marker.getLatLng();
  const point = getPointById(pointId);
  if (!point) {
    return;
  }

  point.lat = roundCoordinate(latLng.lat);
  point.lon = roundCoordinate(latLng.lng);

  updateConnectedEdgesForPoint(pointId);
  updateDraftLineForSource(pointId);
}

function onPointDragEnd(event, pointId) {
  L.DomEvent.stop(event);
  state.justDraggedPointId = pointId;
  state.justDraggedUntil = Date.now() + 250;
  setStatus(`Przesunięto punkt ${pointId}.`);
  void persistAll();
}

function formatPointTooltip(point) {
  const title = point.name ? `${point.name}` : "(bez nazwy)";
  return `#${point.id} ${title}`;
}

function startDraftEdge(pointId) {
  const point = getPointById(pointId);
  if (!point) {
    return;
  }

  state.sourcePointId = pointId;
  state.draftLine = L.polyline(
    [
      [point.lat, point.lon],
      [point.lat, point.lon],
    ],
    {
      color: "#ffd000",
      weight: 2,
      dashArray: "8,8",
    }
  ).addTo(map);

  setStatus(`Źródło połączenia: punkt ${pointId}. Wybierz punkt docelowy.`);
  renderLiveControls();
}

function cancelDraftEdge() {
  state.sourcePointId = null;
  if (state.draftLine) {
    map.removeLayer(state.draftLine);
    state.draftLine = null;
  }
  renderLiveControls();
}

function renderLiveControls() {
  const title = state.mode === "points" ? "Dostępne akcje: tryb punktów" : "Dostępne akcje: tryb połączeń";
  const items = [];

  if (state.mode === "points") {
    items.push("<code>LMB</code> na mapie: dodaj punkt");
    items.push("<code>LMB + drag</code> punktu: przesuń punkt");
    items.push("<code>RMB</code> na punkcie: usuń punkt");
    items.push("<code>RMB</code> na połączeniu: usuń połączenie");
    items.push("<code>Dwuklik</code> na punkcie: edytuj nazwę");
    items.push("<code>Tab</code>: przełącz na tryb połączeń");
  } else if (state.sourcePointId === null) {
    items.push("<code>LMB</code> na punkcie: wybierz punkt źródłowy");
    items.push("<code>LMB + drag</code> punktu: przesuń punkt");
    items.push("<code>RMB</code> na punkcie: usuń punkt");
    items.push("<code>RMB</code> na połączeniu: usuń połączenie");
    items.push("<code>Tab</code>: przełącz na tryb punktów");
  } else {
    items.push(`<code>LMB</code> na innym punkcie: utwórz połączenie z #${state.sourcePointId}`);
    items.push("<code>RMB</code> na mapie lub punkcie: anuluj tworzenie połączenia");
    items.push("<code>LMB + drag</code> punktu: przesuń punkt");
    items.push("<code>RMB</code> na połączeniu: usuń połączenie");
    items.push("<code>Tab</code>: przełącz na tryb punktów");
  }

  el.liveControlsTitle.textContent = title;
  el.liveControlsList.innerHTML = items.map((item) => `<li>${item}</li>`).join("");
}

function updateDraftLineForSource(pointId) {
  if (state.mode !== "edges" || state.sourcePointId !== pointId || !state.draftLine) {
    return;
  }

  const sourcePoint = getPointById(pointId);
  if (!sourcePoint) {
    return;
  }

  const currentLatLngs = state.draftLine.getLatLngs();
  const cursorTarget = currentLatLngs[1] || [sourcePoint.lat, sourcePoint.lon];
  state.draftLine.setLatLngs([
    [sourcePoint.lat, sourcePoint.lon],
    [cursorTarget.lat ?? cursorTarget[0], cursorTarget.lng ?? cursorTarget[1]],
  ]);
}

function createUndirectedEdge(aId, bId) {
  const from_id = Math.min(aId, bId);
  const to_id = Math.max(aId, bId);

  const hasEdge = state.edges.some((edge) => edge.from_id === from_id && edge.to_id === to_id);
  if (hasEdge) {
    setStatus("To połączenie już istnieje.");
    return false;
  }

  const pointA = getPointById(from_id);
  const pointB = getPointById(to_id);

  if (!pointA || !pointB) {
    setStatus("Nie udało się utworzyć połączenia: brak punktów.", true);
    return false;
  }

  const distance_m = roundDistance(
    L.latLng(pointA.lat, pointA.lon).distanceTo(L.latLng(pointB.lat, pointB.lon))
  );

  const edge = {
    id: state.settings.nextEdgeId,
    from_id,
    to_id,
    distance_m,
  };

  state.settings.nextEdgeId += 1;
  state.edges.push(edge);
  redrawEdges();
  refreshCounters();
  return true;
}

function redrawAll() {
  redrawPoints();
  redrawEdges();
  refreshCounters();
}

function redrawPoints() {
  markerLayer.clearLayers();
  markerById.clear();

  for (const point of state.points) {
    renderPoint(point);
  }
}

function redrawEdges() {
  edgeLayer.clearLayers();
  edgeLineById.clear();

  for (const edge of state.edges) {
    const fromPoint = getPointById(edge.from_id);
    const toPoint = getPointById(edge.to_id);

    if (!fromPoint || !toPoint) {
      continue;
    }

    const line = L.polyline(
      [
        [fromPoint.lat, fromPoint.lon],
        [toPoint.lat, toPoint.lon],
      ],
      {
        color: "#35a165",
        weight: 3,
        opacity: 0.9,
      }
    ).bindTooltip(formatEdgeTooltip(edge));

    line.on("contextmenu", (event) => {
      onEdgeRightClick(event, edge.id);
    });

    line.addTo(edgeLayer);
    edgeLineById.set(edge.id, line);
  }
}

function updateConnectedEdgesForPoint(pointId) {
  let needsFullRedraw = false;

  for (const edge of state.edges) {
    if (edge.from_id !== pointId && edge.to_id !== pointId) {
      continue;
    }

    const fromPoint = getPointById(edge.from_id);
    const toPoint = getPointById(edge.to_id);
    if (!fromPoint || !toPoint) {
      continue;
    }

    edge.distance_m = roundDistance(
      L.latLng(fromPoint.lat, fromPoint.lon).distanceTo(L.latLng(toPoint.lat, toPoint.lon))
    );

    const line = edgeLineById.get(edge.id);
    if (!line) {
      needsFullRedraw = true;
      continue;
    }

    line.setLatLngs([
      [fromPoint.lat, fromPoint.lon],
      [toPoint.lat, toPoint.lon],
    ]);
    line.setTooltipContent(formatEdgeTooltip(edge));
  }

  if (needsFullRedraw) {
    redrawEdges();
  }
}

function onEdgeRightClick(event, edgeId) {
  L.DomEvent.stop(event);
  removeEdge(edgeId);
}

function removeEdge(edgeId) {
  const before = state.edges.length;
  state.edges = state.edges.filter((edge) => edge.id !== edgeId);
  if (state.edges.length === before) {
    return;
  }

  redrawEdges();
  refreshCounters();
  setStatus(`Usunięto połączenie ${edgeId}.`);
  void persistAll();
}

function formatEdgeTooltip(edge) {
  return `#${edge.id} ${edge.from_id}↔${edge.to_id} (${edge.distance_m}m)`;
}

function refreshCounters() {
  el.pointsCount.textContent = String(state.points.length);
  el.edgesCount.textContent = String(state.edges.length);
  renderPointsTable();
}

function renderPointsTable() {
  const rows = getSortedPointsForTable();
  if (rows.length === 0) {
    el.pointsTableBody.innerHTML = '<tr class="empty-row"><td colspan="4">Brak punktów.</td></tr>';
  } else {
    el.pointsTableBody.innerHTML = rows
      .map(
        (point) =>
          `<tr>
            <td class="numeric">${point.id}</td>
            <td class="numeric">${point.lat.toFixed(7)}</td>
            <td class="numeric">${point.lon.toFixed(7)}</td>
            <td>${escapeHtml(point.name || "")}</td>
          </tr>`
      )
      .join("");
  }

  updatePointSortHeaderLabels();
}

function getSortedPointsForTable() {
  const rows = [...state.points];
  const { key, direction } = state.pointSort;
  if (!key || !direction) {
    return rows;
  }

  const directionFactor = direction === "asc" ? 1 : -1;
  rows.sort((a, b) => comparePointsByKey(a, b, key) * directionFactor);
  return rows;
}

function comparePointsByKey(a, b, key) {
  if (key === "id" || key === "lat" || key === "lon") {
    return a[key] - b[key];
  }

  if (key === "name") {
    const nameA = (a.name || "").toLocaleLowerCase("pl");
    const nameB = (b.name || "").toLocaleLowerCase("pl");
    return nameA.localeCompare(nameB, "pl");
  }

  return 0;
}

function updatePointSortHeaderLabels() {
  for (const button of el.pointSortButtons) {
    const key = button.dataset.sortKey;
    const baseLabel = button.dataset.baseLabel || "";
    let suffix = "";

    if (state.pointSort.key === key) {
      suffix = state.pointSort.direction === "asc" ? " ↑" : state.pointSort.direction === "desc" ? " ↓" : "";
    }

    button.textContent = `${baseLabel}${suffix}`;
    button.classList.toggle("active", state.pointSort.key === key);
    button.setAttribute("aria-sort", state.pointSort.key === key ? state.pointSort.direction : "none");
  }
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function persistAll() {
  persistChain = persistChain
    .then(() => persistAllNow())
    .catch((error) => {
      setStatus(`Błąd kolejki zapisu: ${error.message}`, true);
    });
  return persistChain;
}

async function persistAllNow() {
  if (!state.dirHandle) {
    return;
  }

  try {
    const hasPermission = await ensureDirectoryPermission(state.dirHandle, "readwrite", false);
    if (!hasPermission) {
      setStatus("Brak uprawnień do zapisu. Podłącz folder ponownie.", true);
      return;
    }

    await writeTextFile(SETTINGS_FILE, JSON.stringify(state.settings, null, 2));
    await writeTextFile(POINTS_FILE, pointsToCsv(state.points));
    await writeTextFile(EDGES_FILE, edgesToCsv(state.edges));
    setStatus("Zapisano zmiany.");
  } catch (error) {
    setStatus(`Błąd zapisu: ${error.message}`, true);
  }
}

async function loadAllFromDisk() {
  await ensureFilesExist();

  const settingsRaw = await readTextFile(SETTINGS_FILE);
  const pointsRaw = await readTextFile(POINTS_FILE);
  const edgesRaw = await readTextFile(EDGES_FILE);

  state.settings = mergeSettings(parseSettings(settingsRaw));
  state.points = parsePointsCsv(pointsRaw);
  state.edges = parseEdgesCsv(edgesRaw).filter((edge) => edge.from_id !== edge.to_id);

  normalizeStateAfterLoad();
  cancelDraftEdge();
}

function normalizeStateAfterLoad() {
  const usedPointIds = new Set(state.points.map((point) => point.id));
  state.edges = state.edges.filter(
    (edge) => usedPointIds.has(edge.from_id) && usedPointIds.has(edge.to_id)
  );

  const maxPointId = state.points.reduce((max, point) => Math.max(max, point.id), 0);
  const maxEdgeId = state.edges.reduce((max, edge) => Math.max(max, edge.id), 0);

  state.settings.nextPointId = Math.max(state.settings.nextPointId || 1, maxPointId + 1);
  state.settings.nextEdgeId = Math.max(state.settings.nextEdgeId || 1, maxEdgeId + 1);

  state.settings.lastMode = state.settings.lastMode === "edges" ? "edges" : "points";
}

function parseSettings(raw) {
  if (!raw.trim()) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch {
    setStatus("settings.json ma niepoprawny format, używam wartości domyślnych.", true);
    return {};
  }
}

function mergeSettings(rawSettings) {
  const merged = {
    fileVersion: FILE_VERSION,
    mapCenter: DEFAULT_CENTER,
    mapZoom: DEFAULT_ZOOM,
    lastMode: "points",
    nextPointId: 1,
    nextEdgeId: 1,
    ...rawSettings,
  };

  if (
    !merged.mapCenter ||
    typeof merged.mapCenter.lat !== "number" ||
    typeof merged.mapCenter.lon !== "number"
  ) {
    merged.mapCenter = DEFAULT_CENTER;
  }

  if (typeof merged.mapZoom !== "number") {
    merged.mapZoom = DEFAULT_ZOOM;
  }

  return merged;
}

function pointsToCsv(points) {
  const lines = ["id,lat,lon,name"];
  for (const point of points) {
    lines.push(
      [point.id, point.lat, point.lon, escapeCsv(point.name || "")]
        .map((value, index) => (index === 3 ? value : String(value)))
        .join(",")
    );
  }
  return `${lines.join("\n")}\n`;
}

function edgesToCsv(edges) {
  const lines = ["id,from_id,to_id,distance_m"];
  for (const edge of edges) {
    lines.push(`${edge.id},${edge.from_id},${edge.to_id},${edge.distance_m}`);
  }
  return `${lines.join("\n")}\n`;
}

function parsePointsCsv(raw) {
  const rows = parseCsvRows(raw);
  if (rows.length === 0) {
    return [];
  }

  const dataRows = rows[0][0] === "id" ? rows.slice(1) : rows;
  const points = [];

  for (const row of dataRows) {
    if (row.length < 3) {
      continue;
    }

    const id = Number.parseInt(row[0], 10);
    const lat = Number.parseFloat(row[1]);
    const lon = Number.parseFloat(row[2]);
    const name = (row[3] || "").trim();

    if (Number.isNaN(id) || Number.isNaN(lat) || Number.isNaN(lon)) {
      continue;
    }

    points.push({ id, lat, lon, name });
  }

  return points;
}

function parseEdgesCsv(raw) {
  const rows = parseCsvRows(raw);
  if (rows.length === 0) {
    return [];
  }

  const dataRows = rows[0][0] === "id" ? rows.slice(1) : rows;
  const edges = [];

  for (const row of dataRows) {
    if (row.length < 4) {
      continue;
    }

    const id = Number.parseInt(row[0], 10);
    const a = Number.parseInt(row[1], 10);
    const b = Number.parseInt(row[2], 10);
    const dist = Number.parseFloat(row[3]);

    if ([id, a, b].some(Number.isNaN) || Number.isNaN(dist)) {
      continue;
    }

    const from_id = Math.min(a, b);
    const to_id = Math.max(a, b);
    edges.push({ id, from_id, to_id, distance_m: roundDistance(dist) });
  }

  return deduplicateEdges(edges);
}

function deduplicateEdges(edges) {
  const byPair = new Map();
  for (const edge of edges) {
    const key = `${edge.from_id}-${edge.to_id}`;
    if (!byPair.has(key)) {
      byPair.set(key, edge);
    }
  }
  return [...byPair.values()];
}

function parseCsvRows(input) {
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < input.length; i += 1) {
    const char = input[i];

    if (inQuotes) {
      if (char === '"') {
        if (input[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"') {
      inQuotes = true;
      continue;
    }

    if (char === ",") {
      row.push(field);
      field = "";
      continue;
    }

    if (char === "\n") {
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
      continue;
    }

    if (char === "\r") {
      continue;
    }

    field += char;
  }

  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  return rows.filter((item) => item.length > 1 || item[0] !== "");
}

function escapeCsv(value) {
  const stringValue = String(value ?? "");
  if (!/[",\n]/.test(stringValue)) {
    return stringValue;
  }
  return `"${stringValue.replace(/"/g, '""')}"`;
}

async function ensureFilesExist() {
  await ensureFileWithDefault(SETTINGS_FILE, JSON.stringify(state.settings, null, 2));
  await ensureFileWithDefault(POINTS_FILE, "id,lat,lon,name\n");
  await ensureFileWithDefault(EDGES_FILE, "id,from_id,to_id,distance_m\n");
}

async function ensureFileWithDefault(filename, defaultContent) {
  const fileHandle = await state.dirHandle.getFileHandle(filename, { create: true });
  const file = await fileHandle.getFile();
  if (file.size === 0) {
    const writer = await fileHandle.createWritable();
    await writer.write(defaultContent);
    await writer.close();
  }
}

async function readTextFile(filename) {
  const fileHandle = await state.dirHandle.getFileHandle(filename, { create: true });
  const file = await fileHandle.getFile();
  return file.text();
}

async function writeTextFile(filename, content) {
  const fileHandle = await state.dirHandle.getFileHandle(filename, { create: true });
  const writer = await fileHandle.createWritable();
  await writer.write(content);
  await writer.close();
}

function getPointById(pointId) {
  return state.points.find((point) => point.id === pointId) || null;
}

function roundCoordinate(value) {
  return Number(value.toFixed(7));
}

function roundDistance(value) {
  return Number(value.toFixed(2));
}

function setStatus(message, stateOrError = "success") {
  let statusState = "success";
  if (typeof stateOrError === "boolean") {
    statusState = stateOrError ? "error" : "success";
  } else if (stateOrError === "loading" || stateOrError === "error" || stateOrError === "success") {
    statusState = stateOrError;
  }

  el.mapStatusText.textContent = message;
  el.mapStatus.classList.remove("is-loading", "is-success", "is-error");
  el.mapStatus.classList.add(`is-${statusState}`);
}

async function openHandleDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(IDB_NAME, 1);

    request.onerror = () => reject(request.error);

    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(IDB_STORE)) {
        db.createObjectStore(IDB_STORE);
      }
    };

    request.onsuccess = () => resolve(request.result);
  });
}

async function saveDirectoryHandle(handle) {
  const db = await openHandleDb();

  await new Promise((resolve, reject) => {
    const tx = db.transaction(IDB_STORE, "readwrite");
    tx.onerror = () => reject(tx.error);
    tx.oncomplete = () => resolve();
    tx.objectStore(IDB_STORE).put(handle, HANDLE_KEY);
  });

  db.close();
}

async function loadDirectoryHandle() {
  if (!window.indexedDB) {
    return null;
  }

  const db = await openHandleDb();

  const handle = await new Promise((resolve, reject) => {
    const tx = db.transaction(IDB_STORE, "readonly");
    tx.onerror = () => reject(tx.error);
    const request = tx.objectStore(IDB_STORE).get(HANDLE_KEY);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result || null);
  });

  db.close();
  return handle;
}

async function ensureDirectoryPermission(handle, mode = "readwrite", requestIfNeeded = true) {
  if (!handle || !handle.queryPermission) {
    return false;
  }

  const options = { mode };
  const query = await handle.queryPermission(options);
  if (query === "granted") {
    return true;
  }

  if (!requestIfNeeded || !handle.requestPermission) {
    return false;
  }

  const request = await handle.requestPermission(options);
  return request === "granted";
}
