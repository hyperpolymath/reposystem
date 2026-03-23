/* SPDX-License-Identifier: PMPL-1.0-or-later */
/* SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell */

const svg = document.getElementById("graph");
const fileInput = document.getElementById("fileInput");
const statusEl = document.getElementById("status");
const detailsEl = document.getElementById("details");
const searchInput = document.getElementById("searchInput");
const layoutSelect = document.getElementById("layoutSelect");
const groupSelect = document.getElementById("groupSelect");
const aspectSelect = document.getElementById("aspectSelect");
const labelToggle = document.getElementById("labelToggle");
const weightToggle = document.getElementById("weightToggle");
const contrastToggle = document.getElementById("contrastToggle");
const darkToggle = document.getElementById("darkToggle");
const freezeToggle = document.getElementById("freezeToggle");
const snapToggle = document.getElementById("snapToggle");
const erToggle = document.getElementById("erToggle");
const accentColor = document.getElementById("accentColor");
const bgColor = document.getElementById("bgColor");
const panelColor = document.getElementById("panelColor");
const resetViewBtn = document.getElementById("resetView");
const fitViewBtn = document.getElementById("fitView");
const loadSampleBtn = document.getElementById("loadSample");
const loadUrlBtn = document.getElementById("loadUrl");
const urlInput = document.getElementById("urlInput");
const zoomInBtn = document.getElementById("zoomIn");
const zoomOutBtn = document.getElementById("zoomOut");
const zoomResetBtn = document.getElementById("zoomReset");
const nodeListEl = document.getElementById("nodeList");
const toolSelectBtn = document.getElementById("toolSelect");
const toolTextBtn = document.getElementById("toolText");
const toolBoxBtn = document.getElementById("toolBox");
const toolArrowBtn = document.getElementById("toolArrow");
const annotationText = document.getElementById("annotationText");
const bringFrontBtn = document.getElementById("bringFront");
const sendBackBtn = document.getElementById("sendBack");
const pinToggleBtn = document.getElementById("pinToggle");
const deleteBtn = document.getElementById("deleteItem");
const downloadBtn = document.getElementById("downloadJson");
const groupNameInput = document.getElementById("groupName");
const createGroupBtn = document.getElementById("createGroup");
const undoBtn = document.getElementById("undoBtn");
const redoBtn = document.getElementById("redoBtn");

const ariaStatus = document.getElementById("ariaStatus");
const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

let graphData = { nodes: [], edges: [], groups: [], annotations: [] };
let selectedItems = [];
let view = { scale: 1, offsetX: 0, offsetY: 0 };
let toolMode = "select";
let drawStart = null;
let nextZ = 1;
const history = [];
const redoStack = [];

const width = 1200;
const height = 800;
const center = { x: width / 2, y: height / 2 };
const gridSize = 20;

const sampleData = {
  nodes: [
    { kind: "Repo", id: "repo:gh:hyperpolymath/reposystem", name: "reposystem", tags: ["orchestration"] },
    { kind: "Repo", id: "repo:gh:hyperpolymath/git-hud", name: "git-hud", tags: ["hud"] },
    { kind: "Repo", id: "repo:gh:hyperpolymath/git-seo", name: "git-seo", tags: ["discovery"] },
    { kind: "Repo", id: "repo:gh:hyperpolymath/git-dispatcher", name: "git-dispatcher", tags: ["dispatch"] },
    { kind: "Repo", id: "repo:gh:hyperpolymath/gitbot-fleet", name: "gitbot-fleet", tags: ["bots"] },
    { kind: "Group", id: "group:core", name: "Core Set", members: [
      "repo:gh:hyperpolymath/reposystem",
      "repo:gh:hyperpolymath/git-hud",
      "repo:gh:hyperpolymath/git-seo",
      "repo:gh:hyperpolymath/git-dispatcher",
      "repo:gh:hyperpolymath/gitbot-fleet"
    ] }
  ],
  edges: [
    { kind: "Edge", id: "edge:1", from: "repo:gh:hyperpolymath/reposystem", to: "repo:gh:hyperpolymath/git-hud", rel: "uses", channel: "graph", aspects: [{ name: "security", weight: 2 }], cardinality: { from: "1", to: "many" } },
    { kind: "Edge", id: "edge:2", from: "repo:gh:hyperpolymath/reposystem", to: "repo:gh:hyperpolymath/git-seo", rel: "uses", channel: "artifact", aspects: [{ name: "supply-chain", weight: 1 }], cardinality: { from: "1", to: "many" } },
    { kind: "Edge", id: "edge:3", from: "repo:gh:hyperpolymath/git-dispatcher", to: "repo:gh:hyperpolymath/gitbot-fleet", rel: "uses", channel: "automation", aspects: [{ name: "reliability", weight: 3 }], cardinality: { from: "1", to: "many" } }
  ],
  annotations: []
};

function setStatus(text) {
  statusEl.textContent = text;
  if (ariaStatus) ariaStatus.textContent = text;
}

function snapshot() {
  history.push(JSON.stringify(graphData));
  if (history.length > 50) history.shift();
  redoStack.length = 0;
}

function undo() {
  if (!history.length) return;
  redoStack.push(JSON.stringify(graphData));
  const prev = history.pop();
  graphData = buildModel(JSON.parse(prev));
  updateGroupSelect();
  updateNodeList();
  render();
  persistToLocalStorage();
}

function redo() {
  if (!redoStack.length) return;
  history.push(JSON.stringify(graphData));
  const next = redoStack.pop();
  graphData = buildModel(JSON.parse(next));
  updateGroupSelect();
  updateNodeList();
  render();
  persistToLocalStorage();
}

function normalizeGraph(raw) {
  if (!raw) return { nodes: [], edges: [], groups: [], annotations: [] };

  if (raw.nodes && raw.edges) {
    return { nodes: raw.nodes, edges: raw.edges, groups: raw.groups || [], annotations: raw.annotations || [] };
  }

  if (raw.graph && raw.graph.nodes) {
    return { nodes: raw.graph.nodes || [], edges: raw.graph.edges || [], groups: raw.graph.groups || [], annotations: raw.graph.annotations || [] };
  }

  if (raw.repos || raw.components || raw.edges) {
    // Rust GraphStore format: repos + components + groups are separate arrays
    const nodes = [...(raw.repos || []), ...(raw.components || [])];
    return { nodes, edges: raw.edges || [], groups: raw.groups || [], annotations: raw.annotations || [] };
  }

  const nodes = [];
  const edges = [];
  if (Array.isArray(raw)) {
    raw.forEach((item) => {
      if (item.kind === "Edge") edges.push(item);
      else nodes.push(item);
    });
  }
  return { nodes, edges, groups: [], annotations: [] };
}

function ensureNodeShape(node) {
  const kind = (node.kind || "Repo").toLowerCase();
  return {
    ...node,
    _kind: kind,
    id: node.id || node.name || node.repo_id || `node:${Math.random()}`,
    label: node.name || node.id || "unknown",
    x: node.x || Math.random() * width,
    y: node.y || Math.random() * height,
    z: node.z || 0,
    pinned: !!node.pinned,
    color: node.color || null,
    attributes: node.attributes || [],
  };
}

function ensureEdgeShape(edge) {
  return {
    ...edge,
    id: edge.id || `edge:${Math.random()}`,
    from: edge.from || edge.source || edge.src,
    to: edge.to || edge.target || edge.dst,
    label: edge.label || edge.rel || "link",
    color: edge.color || null,
    cardinality: edge.cardinality || { from: "", to: "" },
  };
}

function ensureAnnotationShape(annotation) {
  return {
    ...annotation,
    id: annotation.id || `anno:${Math.random()}`,
    type: annotation.type || "text",
    z: annotation.z || 0,
  };
}

function buildModel(raw) {
  const normalized = normalizeGraph(raw);
  const nodes = normalized.nodes.map(ensureNodeShape);
  const nodeMap = new Map(nodes.map((n) => [n.id, n]));
  const edges = normalized.edges.map(ensureEdgeShape).filter((e) => nodeMap.has(e.from) && nodeMap.has(e.to));
  const autoGroups = nodes.filter((n) => n._kind === "group");
  const importedGroupIds = new Set(autoGroups.map((g) => g.id));
  const extraGroups = (normalized.groups || [])
    .filter((g) => !importedGroupIds.has(g.id))
    .map(ensureNodeShape);
  const groups = [...autoGroups, ...extraGroups];
  const annotations = (normalized.annotations || []).map(ensureAnnotationShape);
  nextZ = 1 + Math.max(0, ...nodes.map((n) => n.z || 0), ...annotations.map((a) => a.z || 0));
  return { nodes, edges, groups, annotations };
}

function clearSvg() {
  while (svg.firstChild) svg.removeChild(svg.firstChild);
}

function screenToWorld(clientX, clientY) {
  const rect = svg.getBoundingClientRect();
  const sx = clientX - rect.left;
  const sy = clientY - rect.top;
  return {
    x: (sx - view.offsetX) / view.scale,
    y: (sy - view.offsetY) / view.scale,
  };
}

function snapValue(value) {
  if (!snapToggle.checked) return value;
  return Math.round(value / gridSize) * gridSize;
}

function snapPoint(point) {
  return { x: snapValue(point.x), y: snapValue(point.y) };
}

function layoutForce(nodes, edges, iterations = 200) {
  if (prefersReducedMotion) iterations = Math.min(iterations, 60);
  const k = Math.sqrt((width * height) / Math.max(nodes.length, 1));
  for (let i = 0; i < iterations; i++) {
    nodes.forEach((n) => {
      n.vx = 0;
      n.vy = 0;
      nodes.forEach((m) => {
        if (n === m) return;
        const dx = n.x - m.x;
        const dy = n.y - m.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const force = (k * k) / dist;
        n.vx += (dx / dist) * force;
        n.vy += (dy / dist) * force;
      });
    });

    edges.forEach((e) => {
      const a = nodes.find((n) => n.id === e.from);
      const b = nodes.find((n) => n.id === e.to);
      if (!a || !b) return;
      const dx = a.x - b.x;
      const dy = a.y - b.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      const force = (dist * dist) / k;
      if (!a.pinned) {
        a.vx -= (dx / dist) * force;
        a.vy -= (dy / dist) * force;
      }
      if (!b.pinned) {
        b.vx += (dx / dist) * force;
        b.vy += (dy / dist) * force;
      }
    });

    nodes.forEach((n) => {
      if (n.pinned) return;
      n.x = Math.min(width - 40, Math.max(40, n.x + n.vx * 0.005));
      n.y = Math.min(height - 40, Math.max(40, n.y + n.vy * 0.005));
    });
  }
}

function tightenConnections(nodes, edges) {
  const nodeMap = new Map(nodes.map((n) => [n.id, n]));
  edges.forEach((e) => {
    const a = nodeMap.get(e.from);
    const b = nodeMap.get(e.to);
    if (!a || !b) return;
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const dist = Math.sqrt(dx * dx + dy * dy) || 1;
    const target = 160;
    if (dist > target) {
      const pull = (dist - target) * 0.02;
      if (!a.pinned) {
        a.x += (dx / dist) * pull;
        a.y += (dy / dist) * pull;
      }
      if (!b.pinned) {
        b.x -= (dx / dist) * pull;
        b.y -= (dy / dist) * pull;
      }
    }
  });
}

function layoutGrid(nodes) {
  const cols = Math.ceil(Math.sqrt(nodes.length));
  const gapX = width / (cols + 1);
  const gapY = height / (cols + 1);
  nodes.forEach((n, i) => {
    if (n.pinned) return;
    const col = i % cols;
    const row = Math.floor(i / cols);
    n.x = gapX * (col + 1);
    n.y = gapY * (row + 1);
  });
}

function layoutRadial(nodes) {
  const radius = Math.min(width, height) / 2.5;
  nodes.forEach((n, i) => {
    if (n.pinned) return;
    const angle = (i / nodes.length) * Math.PI * 2;
    n.x = center.x + Math.cos(angle) * radius;
    n.y = center.y + Math.sin(angle) * radius;
  });
}

function layoutGroups(nodes, groups) {
  if (!groups.length) {
    layoutForce(nodes, graphData.edges, 200);
    return;
  }
  const groupRadius = Math.min(width, height) / 3;
  groups.forEach((g, i) => {
    const angle = (i / groups.length) * Math.PI * 2;
    g.x = center.x + Math.cos(angle) * groupRadius;
    g.y = center.y + Math.sin(angle) * groupRadius;
    const members = nodes.filter((n) => g.members && g.members.includes(n.id));
    members.forEach((n, idx) => {
      if (n.pinned) return;
      const a = (idx / Math.max(members.length, 1)) * Math.PI * 2;
      n.x = g.x + Math.cos(a) * 140;
      n.y = g.y + Math.sin(a) * 140;
    });
  });
}

function applyLayout(type) {
  if (freezeToggle.checked) return;
  if (type === "grid") layoutGrid(graphData.nodes);
  else if (type === "radial") layoutRadial(graphData.nodes);
  else if (type === "groups") layoutGroups(graphData.nodes, graphData.groups);
  else layoutForce(graphData.nodes, graphData.edges, 200);
  tightenConnections(graphData.nodes, graphData.edges);
}

function filterByAspect(nodes, edges, aspect) {
  if (aspect === "all") return { nodes, edges };
  const keepNode = (n) => {
    const aspects = n.aspects || n.tags || [];
    return aspects.some((a) => (typeof a === "string" ? a === aspect : a.name === aspect));
  };
  const keepEdge = (e) => {
    const aspects = e.aspects || e.tags || [];
    return aspects.some((a) => (typeof a === "string" ? a === aspect : a.name === aspect));
  };
  const filteredNodes = nodes.filter((n) => keepNode(n));
  const ids = new Set(filteredNodes.map((n) => n.id));
  const filteredEdges = edges.filter((e) => ids.has(e.from) && ids.has(e.to) && keepEdge(e));
  return { nodes: filteredNodes, edges: filteredEdges };
}

function filterByGroup(nodes, edges, groupId) {
  if (groupId === "all") return { nodes, edges };
  const group = graphData.groups.find((g) => g.id === groupId);
  if (!group) return { nodes, edges };
  const ids = new Set(group.members || []);
  ids.add(group.id);
  const filteredNodes = nodes.filter((n) => ids.has(n.id));
  const filteredEdges = edges.filter((e) => ids.has(e.from) && ids.has(e.to));
  return { nodes: filteredNodes, edges: filteredEdges };
}

function getAspectWeight(entity) {
  const aspect = aspectSelect.value;
  const aspects = entity.aspects || [];
  if (!Array.isArray(aspects)) return 0;
  if (aspect === "all") {
    return aspects.reduce((acc, a) => acc + (a.weight || 0), 0);
  }
  const hit = aspects.find((a) => a.name === aspect);
  return hit ? hit.weight || 0 : 0;
}

function weightColor(weight) {
  const clamped = Math.max(0, Math.min(weight, 4));
  const alpha = 0.25 + (clamped / 4) * 0.7;
  return `rgba(75, 77, 255, ${alpha.toFixed(2)})`;
}

function markerId(kind) {
  switch (kind) {
    case "many":
      return "marker-many";
    case "0..many":
      return "marker-optional-many";
    case "0..1":
      return "marker-optional-one";
    case "1":
      return "marker-one";
    default:
      return "marker-one";
  }
}

function renderDetails() {
  if (!selectedItems.length) {
    detailsEl.innerHTML = '<p class="muted">Select a node or edge to see details.</p>';
    return;
  }
  const item = selectedItems[0];
  if (item._kind || item.kind === "Repo" || item.kind === "Entity") {
    const attributes = item.attributes || [];
    detailsEl.innerHTML = `
      <div class="details-form">
        <label>Name</label>
        <input id="nodeName" type="text" value="${item.label || item.name || ""}" />
        <label>Color</label>
        <input id="nodeColor" type="color" value="${item.color || "#4b4dff"}" />
        <div class="button-row">
          <button id="convertEntity" class="ghost" type="button">Convert to Entity</button>
        </div>
        <label>Attributes</label>
        <ul class="attribute-list">
          ${attributes
            .map(
              (attr, idx) => `
                <li>
                  <input data-idx="${idx}" data-field="name" value="${attr.name || ""}" placeholder="name" />
                  <input data-idx="${idx}" data-field="type" value="${attr.type || ""}" placeholder="type" />
                  <select data-idx="${idx}" data-field="nullable">
                    <option value="true" ${attr.nullable ? "selected" : ""}>nullable</option>
                    <option value="false" ${attr.nullable ? "" : "selected"}>required</option>
                  </select>
                  <input data-idx="${idx}" data-field="default" value="${attr.default || ""}" placeholder="default" />
                  <select data-idx="${idx}" data-field="key">
                    <option value="">-</option>
                    <option value="PK" ${attr.key === "PK" ? "selected" : ""}>PK</option>
                    <option value="FK" ${attr.key === "FK" ? "selected" : ""}>FK</option>
                  </select>
                  <button data-idx="${idx}" class="ghost remove-attr" type="button">Remove</button>
                </li>
              `
            )
            .join("")}
        </ul>
        <div class="button-row">
          <button id="addAttr" class="ghost" type="button">Add Attribute</button>
        </div>
      </div>
    `;

    const nameInput = document.getElementById("nodeName");
    const colorInput = document.getElementById("nodeColor");
    nameInput.addEventListener("input", () => {
      item.name = nameInput.value;
      item.label = nameInput.value;
      render();
    });
    colorInput.addEventListener("input", () => {
      item.color = colorInput.value;
      render();
    });

    detailsEl.querySelectorAll(".attribute-list input, .attribute-list select").forEach((input) => {
      input.addEventListener("input", () => {
        const idx = Number(input.dataset.idx);
        const field = input.dataset.field;
        if (!item.attributes[idx]) return;
        let value = input.value;
        if (field === "nullable") value = value === "true";
        item.attributes[idx][field] = value;
        render();
      });
    });

    detailsEl.querySelectorAll(".remove-attr").forEach((btn) => {
      btn.addEventListener("click", () => {
        const idx = Number(btn.dataset.idx);
        item.attributes.splice(idx, 1);
        renderDetails();
        render();
      });
    });

    document.getElementById("addAttr").addEventListener("click", () => {
      item.attributes.push({ name: "", type: "", nullable: true, default: "", key: "" });
      renderDetails();
      render();
    });

    document.getElementById("convertEntity").addEventListener("click", () => {
      item._kind = "entity";
      item.kind = "Entity";
      if (!item.attributes.length) item.attributes.push({ name: "", type: "", nullable: true, default: "", key: "" });
      renderDetails();
      render();
    });
  } else if (item.from && item.to) {
    detailsEl.innerHTML = `
      <div class="details-form">
        <label>Edge Color</label>
        <input id="edgeColor" type="color" value="${item.color || "#4b4dff"}" />
        <label>Cardinality From</label>
        <select id="cardFrom">
          <option value="">-</option>
          <option value="1" ${item.cardinality?.from === "1" ? "selected" : ""}>1</option>
          <option value="0..1" ${item.cardinality?.from === "0..1" ? "selected" : ""}>0..1</option>
          <option value="many" ${item.cardinality?.from === "many" ? "selected" : ""}>many</option>
          <option value="0..many" ${item.cardinality?.from === "0..many" ? "selected" : ""}>0..many</option>
        </select>
        <label>Cardinality To</label>
        <select id="cardTo">
          <option value="">-</option>
          <option value="1" ${item.cardinality?.to === "1" ? "selected" : ""}>1</option>
          <option value="0..1" ${item.cardinality?.to === "0..1" ? "selected" : ""}>0..1</option>
          <option value="many" ${item.cardinality?.to === "many" ? "selected" : ""}>many</option>
          <option value="0..many" ${item.cardinality?.to === "0..many" ? "selected" : ""}>0..many</option>
        </select>
      </div>
    `;

    const edgeColorInput = document.getElementById("edgeColor");
    const cardFrom = document.getElementById("cardFrom");
    const cardTo = document.getElementById("cardTo");

    edgeColorInput.addEventListener("input", () => {
      item.color = edgeColorInput.value;
      render();
    });
    cardFrom.addEventListener("change", () => {
      item.cardinality = item.cardinality || {};
      item.cardinality.from = cardFrom.value;
      render();
    });
    cardTo.addEventListener("change", () => {
      item.cardinality = item.cardinality || {};
      item.cardinality.to = cardTo.value;
      render();
    });
  } else {
    detailsEl.innerHTML = `<pre>${JSON.stringify(item, null, 2)}</pre>`;
  }
}

function render() {
  clearSvg();
  const aspect = aspectSelect.value;
  let { nodes, edges } = filterByAspect(graphData.nodes, graphData.edges, aspect);
  ({ nodes, edges } = filterByGroup(nodes, edges, groupSelect.value));

  const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
  defs.innerHTML = `
    <pattern id="grid-pattern" width="${gridSize}" height="${gridSize}" patternUnits="userSpaceOnUse">
      <path d="M ${gridSize} 0 L 0 0 0 ${gridSize}" stroke="currentColor" stroke-width="0.6" fill="none" />
    </pattern>
    <marker id="marker-one" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M0,5 L10,5" stroke="currentColor" stroke-width="2" />
    </marker>
    <marker id="marker-optional-one" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <circle cx="2" cy="5" r="1.5" fill="currentColor" />
      <path d="M4,5 L10,5" stroke="currentColor" stroke-width="2" />
    </marker>
    <marker id="marker-many" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="8" markerHeight="8" orient="auto">
      <path d="M0,0 L10,5 L0,10" stroke="currentColor" stroke-width="1.5" fill="none" />
    </marker>
    <marker id="marker-optional-many" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="8" markerHeight="8" orient="auto">
      <circle cx="2" cy="5" r="1.5" fill="currentColor" />
      <path d="M3,0 L10,5 L3,10" stroke="currentColor" stroke-width="1.5" fill="none" />
    </marker>
  `;

  const viewport = document.createElementNS("http://www.w3.org/2000/svg", "g");
  viewport.setAttribute("transform", `translate(${view.offsetX}, ${view.offsetY}) scale(${view.scale})`);

  const gridRect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
  gridRect.setAttribute("x", 0);
  gridRect.setAttribute("y", 0);
  gridRect.setAttribute("width", width);
  gridRect.setAttribute("height", height);
  gridRect.setAttribute("fill", "url(#grid-pattern)");
  gridRect.setAttribute("class", "grid");
  gridRect.setAttribute("style", "color: var(--graph-line);");
  gridRect.setAttribute("visibility", snapToggle.checked ? "visible" : "hidden");
  viewport.appendChild(gridRect);

  const edgeGroup = document.createElementNS("http://www.w3.org/2000/svg", "g");
  edges.forEach((e) => {
    const from = nodes.find((n) => n.id === e.from) || graphData.nodes.find((n) => n.id === e.from);
    const to = nodes.find((n) => n.id === e.to) || graphData.nodes.find((n) => n.id === e.to);
    if (!from || !to) return;
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const dist = Math.max(Math.hypot(dx, dy), 1);
    const nx = -dy / dist;
    const ny = dx / dist;
    const curve = 12;
    const mx = (from.x + to.x) / 2 + nx * curve;
    const my = (from.y + to.y) / 2 + ny * curve;
    path.setAttribute("d", `M ${from.x} ${from.y} Q ${mx} ${my} ${to.x} ${to.y}`);
    const weight = weightToggle.checked ? getAspectWeight(e) : 0;
    const strokeColor = e.color || (weightToggle.checked ? weightColor(weight) : "");
    path.setAttribute("style", `stroke-width: ${1.5 + weight * 1.2}; stroke: ${strokeColor}`);
    path.setAttribute("class", `edge ${selectedItems.includes(e) ? "selected" : ""}`);
    if (erToggle.checked) {
      path.setAttribute("marker-start", `url(#${markerId(e.cardinality?.from)})`);
      path.setAttribute("marker-end", `url(#${markerId(e.cardinality?.to)})`);
    }
    path.addEventListener("click", (event) => selectItem({ type: "edge", data: e, event }));
    edgeGroup.appendChild(path);

    if (labelToggle.checked) {
      const label = document.createElementNS("http://www.w3.org/2000/svg", "text");
      label.setAttribute("x", mx + 6);
      label.setAttribute("y", my - 6);
      label.setAttribute("font-size", "11");
      label.textContent = e.label || e.rel || "link";
      edgeGroup.appendChild(label);
    }
  });

  const nodeGroup = document.createElementNS("http://www.w3.org/2000/svg", "g");
  nodes.sort((a, b) => (a.z || 0) - (b.z || 0)).forEach((n) => {
    if (erToggle.checked && n._kind === "entity") {
      const attrs = n.attributes || [];
      const widthBox = 180;
      const heightBox = 40 + attrs.length * 16;
      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      rect.setAttribute("x", n.x);
      rect.setAttribute("y", n.y);
      rect.setAttribute("width", widthBox);
      rect.setAttribute("height", heightBox);
      rect.setAttribute("fill", n.color || "#ffffff");
      rect.setAttribute("stroke", "#333");
      rect.setAttribute("class", `node ${selectedItems.includes(n) ? "selected" : ""}`);
      rect.addEventListener("click", (event) => selectItem({ type: "node", data: n, event }));
      makeDraggable(rect, n, widthBox / 2, heightBox / 2);
      nodeGroup.appendChild(rect);

      const title = document.createElementNS("http://www.w3.org/2000/svg", "text");
      title.setAttribute("x", n.x + 8);
      title.setAttribute("y", n.y + 16);
      title.setAttribute("font-size", "12");
      title.textContent = n.label;
      nodeGroup.appendChild(title);

      attrs.forEach((attr, idx) => {
        const t = document.createElementNS("http://www.w3.org/2000/svg", "text");
        t.setAttribute("x", n.x + 8);
        t.setAttribute("y", n.y + 32 + idx * 14);
        t.setAttribute("font-size", "11");
        const key = attr.key ? `[${attr.key}] ` : "";
        t.textContent = `${key}${attr.name || ""} ${attr.type || ""}`.trim();
        nodeGroup.appendChild(t);
      });
    } else {
      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
      const weight = weightToggle.checked ? getAspectWeight(n) : 0;
      circle.setAttribute("cx", n.x);
      circle.setAttribute("cy", n.y);
      circle.setAttribute("r", 10 + weight * 1.2);
      circle.setAttribute("class", `node ${n._kind} ${selectedItems.includes(n) ? "selected" : ""}`);
      circle.setAttribute("style", `fill: ${n.color || (weightToggle.checked ? weightColor(weight) : "")}`);
      circle.setAttribute("data-node-label", n.label.toLowerCase());
      circle.addEventListener("click", (event) => selectItem({ type: "node", data: n, event }));
      makeDraggable(circle, n);
      nodeGroup.appendChild(circle);

      const label = document.createElementNS("http://www.w3.org/2000/svg", "text");
      label.setAttribute("x", n.x + 14);
      label.setAttribute("y", n.y + 4);
      label.setAttribute("font-size", "12");
      label.setAttribute("data-node-label", n.label.toLowerCase());
      label.textContent = n.label;
      nodeGroup.appendChild(label);
    }
  });

  // Render annotations (text, box, arrow) sorted by z-index
  const annoGroup = document.createElementNS("http://www.w3.org/2000/svg", "g");
  annoGroup.setAttribute("class", "annotations");
  const sortedAnnotations = [...(graphData.annotations || [])].sort((a, b) => (a.z || 0) - (b.z || 0));
  sortedAnnotations.forEach((anno) => {
    const isSelected = selectedItems.includes(anno);
    if (anno.type === "text") {
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
      text.setAttribute("x", anno.x);
      text.setAttribute("y", anno.y);
      text.setAttribute("font-size", "13");
      text.setAttribute("class", `annotation annotation-text ${isSelected ? "selected" : ""}`);
      text.setAttribute("data-anno-id", anno.id);
      text.textContent = anno.text || "Note";
      text.addEventListener("click", (event) => selectItem({ data: anno, event }));
      annoGroup.appendChild(text);
    } else if (anno.type === "box") {
      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      rect.setAttribute("x", anno.x);
      rect.setAttribute("y", anno.y);
      rect.setAttribute("width", anno.w || 80);
      rect.setAttribute("height", anno.h || 40);
      rect.setAttribute("class", `annotation annotation-box ${isSelected ? "selected" : ""}`);
      rect.setAttribute("data-anno-id", anno.id);
      rect.addEventListener("click", (event) => selectItem({ data: anno, event }));
      annoGroup.appendChild(rect);
    } else if (anno.type === "arrow") {
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", anno.x);
      line.setAttribute("y1", anno.y);
      line.setAttribute("x2", anno.x + (anno.w || 50));
      line.setAttribute("y2", anno.y + (anno.h || 0));
      line.setAttribute("class", `annotation annotation-arrow ${isSelected ? "selected" : ""}`);
      line.setAttribute("data-anno-id", anno.id);
      line.setAttribute("marker-end", "url(#marker-one)");
      line.addEventListener("click", (event) => selectItem({ data: anno, event }));
      annoGroup.appendChild(line);
    }
  });

  viewport.appendChild(edgeGroup);
  viewport.appendChild(annoGroup);
  viewport.appendChild(nodeGroup);

  svg.appendChild(defs);
  svg.appendChild(viewport);

  renderDetails();
}

function makeDraggable(nodeEl, nodeData, offsetX = 0, offsetY = 0) {
  let dragging = false;
  let offset = { x: 0, y: 0 };

  nodeEl.addEventListener("mousedown", (event) => {
    event.stopPropagation();
    dragging = true;
    const world = screenToWorld(event.clientX, event.clientY);
    offset = { x: nodeData.x - world.x + offsetX, y: nodeData.y - world.y + offsetY };
    snapshot();
  });

  svg.addEventListener("mousemove", (event) => {
    if (!dragging) return;
    const world = screenToWorld(event.clientX, event.clientY);
    const snapped = snapPoint({ x: world.x + offset.x, y: world.y + offset.y });
    nodeData.x = snapped.x - offsetX;
    nodeData.y = snapped.y - offsetY;
    nodeData.pinned = true;
    render();
  });

  svg.addEventListener("mouseup", () => {
    if (dragging) persistToLocalStorage();
    dragging = false;
  });
}

function loadGraph(raw) {
  graphData = buildModel(raw);
  updateGroupSelect();
  updateNodeList();
  applyLayout(layoutSelect.value);
  setStatus(`Loaded ${graphData.nodes.length} nodes / ${graphData.edges.length} edges`);
  render();
  history.length = 0;
  redoStack.length = 0;
}

function updateGroupSelect() {
  groupSelect.innerHTML = '<option value="all">All</option>';
  graphData.groups.forEach((g) => {
    const option = document.createElement("option");
    option.value = g.id;
    option.textContent = g.name || g.id;
    groupSelect.appendChild(option);
  });
}

function updateNodeList() {
  nodeListEl.innerHTML = "";
  graphData.nodes
    .filter((n) => n._kind !== "group")
    .slice(0, 200)
    .forEach((node) => {
      const item = document.createElement("li");
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.dataset.nodeId = node.id;
      const label = document.createElement("span");
      label.textContent = node.label;
      item.appendChild(checkbox);
      item.appendChild(label);
      item.setAttribute("tabindex", "0");
      item.addEventListener("click", (event) => {
        if (event.target === checkbox) return;
        selectItem({ data: node, event });
      });
      nodeListEl.appendChild(item);
    });
}

function selectItem({ data, event }) {
  if (event && event.shiftKey) {
    if (selectedItems.includes(data)) {
      selectedItems = selectedItems.filter((item) => item !== data);
    } else {
      selectedItems = [...selectedItems, data];
    }
  } else {
    selectedItems = data ? [data] : [];
  }
  renderDetails();
  render();
}

function setTool(mode) {
  toolMode = mode;
  [toolSelectBtn, toolTextBtn, toolBoxBtn, toolArrowBtn].forEach((btn) => btn.classList.remove("active-tool"));
  if (mode === "select") toolSelectBtn.classList.add("active-tool");
  if (mode === "text") toolTextBtn.classList.add("active-tool");
  if (mode === "box") toolBoxBtn.classList.add("active-tool");
  if (mode === "arrow") toolArrowBtn.classList.add("active-tool");
}

fileInput.addEventListener("change", (event) => {
  const file = event.target.files[0];
  if (!file) return;
  if (file.name.endsWith(".ncl")) {
    setStatus("Nickel detected. Export to JSON (nickel export) and load the .json here.");
    return;
  }
  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const raw = JSON.parse(e.target.result);
      loadGraph(raw);
    } catch (err) {
      setStatus("Invalid JSON export.");
    }
  };
  reader.readAsText(file);
});

loadSampleBtn.addEventListener("click", () => loadGraph(sampleData));
loadUrlBtn.addEventListener("click", async () => {
  const url = urlInput.value.trim();
  if (!url) return;
  const resp = await fetch(url);
  const raw = await resp.json();
  loadGraph(raw);
});

accentColor.addEventListener("input", () => {
  document.documentElement.style.setProperty("--accent", accentColor.value);
});

bgColor.addEventListener("input", () => {
  document.documentElement.style.setProperty("--bg", bgColor.value);
});

panelColor.addEventListener("input", () => {
  document.documentElement.style.setProperty("--panel", panelColor.value);
});

darkToggle.addEventListener("change", () => {
  document.body.classList.toggle("dark", darkToggle.checked);
});

// Tool buttons
toolSelectBtn.addEventListener("click", () => setTool("select"));
toolTextBtn.addEventListener("click", () => setTool("text"));
toolBoxBtn.addEventListener("click", () => setTool("box"));
toolArrowBtn.addEventListener("click", () => setTool("arrow"));

erToggle.addEventListener("change", render);
snapToggle.addEventListener("change", render);

setTool("select");
setStatus("Waiting for JSON export.");

// Auto dark mode on load if system prefers dark.
try {
  if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
    darkToggle.checked = true;
    document.body.classList.add("dark");
  }
} catch {
  // ignore
}

function applySearchHighlight() {
  const query = searchInput.value.trim().toLowerCase();
  const nodes = svg.querySelectorAll(".node");
  if (!query) {
    nodes.forEach((n) => n.classList.remove("highlight"));
    return;
  }
  nodes.forEach((nodeEl) => {
    const label = nodeEl.getAttribute("data-node-label") || "";
    if (label.includes(query)) nodeEl.classList.add("highlight");
    else nodeEl.classList.remove("highlight");
  });
}

function zoomBy(factor) {
  const rect = svg.getBoundingClientRect();
  const cursor = { x: rect.width / 2, y: rect.height / 2 };
  const world = {
    x: (cursor.x - view.offsetX) / view.scale,
    y: (cursor.y - view.offsetY) / view.scale,
  };
  const nextScale = Math.min(3, Math.max(0.4, view.scale * factor));
  view.offsetX = cursor.x - world.x * nextScale;
  view.offsetY = cursor.y - world.y * nextScale;
  view.scale = nextScale;
  render();
}

function resetZoom() {
  view = { scale: 1, offsetX: 0, offsetY: 0 };
  render();
}

function bringToFront() {
  snapshot();
  selectedItems.forEach((item) => {
    item.z = nextZ++;
  });
  render();
}

function sendToBack() {
  snapshot();
  selectedItems.forEach((item) => {
    item.z = -nextZ++;
  });
  render();
}

function togglePin() {
  snapshot();
  selectedItems.forEach((item) => {
    if (item._kind) item.pinned = !item.pinned;
  });
  render();
}

function deleteSelection() {
  if (!selectedItems.length) return;
  snapshot();
  const ids = new Set(selectedItems.map((item) => item.id));
  graphData.nodes = graphData.nodes.filter((n) => !ids.has(n.id));
  graphData.annotations = graphData.annotations.filter((a) => !ids.has(a.id));
  graphData.edges = graphData.edges.filter((e) => !ids.has(e.id) && !ids.has(e.from) && !ids.has(e.to));
  graphData.groups = graphData.nodes.filter((n) => n._kind === "group");
  selectedItems = [];
  updateGroupSelect();
  updateNodeList();
  render();
  persistToLocalStorage();
}

function createGroupFromSelection() {
  const name = groupNameInput.value.trim();
  if (!name) return;
  const checked = Array.from(nodeListEl.querySelectorAll("input[type=checkbox]:checked")).map((c) => c.dataset.nodeId);
  if (!checked.length) return;
  snapshot();
  const group = {
    kind: "Group",
    id: `group:${name.toLowerCase().replace(/\s+/g, "-")}`,
    name,
    members: checked,
  };
  graphData.nodes.push(group);
  graphData.groups.push(group);
  updateGroupSelect();
  updateNodeList();
  render();
  persistToLocalStorage();
}

function addAnnotationText(world) {
  snapshot();
  const point = snapPoint(world);
  const text = annotationText.value.trim() || "Note";
  graphData.annotations.push({
    id: `anno:${Math.random()}`,
    type: "text",
    text,
    x: point.x,
    y: point.y,
    z: nextZ++,
  });
  render();
  persistToLocalStorage();
}

function addAnnotationBox(start, end) {
  snapshot();
  const s = snapPoint(start);
  const e = snapPoint(end);
  const x = Math.min(s.x, e.x);
  const y = Math.min(s.y, e.y);
  const w = Math.abs(s.x - e.x);
  const h = Math.abs(s.y - e.y);
  graphData.annotations.push({
    id: `anno:${Math.random()}`,
    type: "box",
    x,
    y,
    w,
    h,
    z: nextZ++,
  });
  render();
  persistToLocalStorage();
}

function addAnnotationArrow(start, end) {
  snapshot();
  const s = snapPoint(start);
  const e = snapPoint(end);
  graphData.annotations.push({
    id: `anno:${Math.random()}`,
    type: "arrow",
    x: s.x,
    y: s.y,
    w: e.x - s.x,
    h: e.y - s.y,
    z: nextZ++,
  });
  render();
  persistToLocalStorage();
}

function downloadJSON() {
  const data = {
    nodes: graphData.nodes,
    edges: graphData.edges,
    groups: graphData.groups,
    annotations: graphData.annotations,
  };
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "reposystem-export.json";
  a.click();
  URL.revokeObjectURL(url);
}

// ============================================================================
// Node and Edge creation
// ============================================================================

function showAddNodeForm() {
  const name = prompt("Node name:");
  if (!name || !name.trim()) return;
  snapshot();
  const node = ensureNodeShape({
    kind: "Repo",
    id: `repo:local:${name.trim().toLowerCase().replace(/\s+/g, "-")}`,
    name: name.trim(),
    tags: [],
    x: center.x + (Math.random() - 0.5) * 200,
    y: center.y + (Math.random() - 0.5) * 200,
  });
  graphData.nodes.push(node);
  updateNodeList();
  render();
  persistToLocalStorage();
  setStatus(`Added node: ${name.trim()}`);
}

function showAddEdgeForm() {
  if (selectedItems.length < 2) {
    setStatus("Select two nodes first (shift-click), then press E to create an edge.");
    return;
  }
  const from = selectedItems[0];
  const to = selectedItems[1];
  if (!from.id || !to.id || from.from || to.from) {
    setStatus("Select two nodes (not edges) to create an edge.");
    return;
  }
  const rel = prompt("Relationship type (uses, provides, extends, mirrors, replaces):", "uses");
  if (!rel || !rel.trim()) return;
  snapshot();
  const edge = ensureEdgeShape({
    kind: "Edge",
    id: `edge:${Date.now()}`,
    from: from.id,
    to: to.id,
    rel: rel.trim(),
    label: rel.trim(),
  });
  graphData.edges.push(edge);
  selectedItems = [];
  render();
  persistToLocalStorage();
  setStatus(`Added edge: ${from.label || from.name} -> ${to.label || to.name}`);
}

// ============================================================================
// localStorage persistence
// ============================================================================

const STORAGE_KEY = "reposystem-graph-data";

function persistToLocalStorage() {
  try {
    const data = {
      nodes: graphData.nodes,
      edges: graphData.edges,
      groups: graphData.groups,
      annotations: graphData.annotations,
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  } catch {
    // Storage full or unavailable — fail silently
  }
}

function loadFromLocalStorage() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) return false;
    const raw = JSON.parse(stored);
    if (raw && raw.nodes && raw.nodes.length > 0) {
      loadGraph(raw);
      setStatus(`Restored ${graphData.nodes.length} nodes from local storage`);
      return true;
    }
  } catch {
    // Corrupted data — ignore
  }
  return false;
}

// Auto-persist after each graph load
const _origLoadGraph2 = loadGraph;
loadGraph = function (raw) {
  _origLoadGraph2(raw);
  persistToLocalStorage();
};

// Restore from localStorage on startup (if no file loaded)
loadFromLocalStorage();

// UI event wiring
layoutSelect.addEventListener("change", () => {
  applyLayout(layoutSelect.value);
  render();
});
groupSelect.addEventListener("change", render);
aspectSelect.addEventListener("change", render);
labelToggle.addEventListener("change", render);
weightToggle.addEventListener("change", render);
contrastToggle.addEventListener("change", () => document.body.classList.toggle("contrast-high", contrastToggle.checked));
searchInput.addEventListener("input", applySearchHighlight);

resetViewBtn.addEventListener("click", () => {
  selectedItems = [];
  searchInput.value = "";
  applyLayout(layoutSelect.value);
  render();
});

fitViewBtn.addEventListener("click", () => {
  applyLayout(layoutSelect.value);
  render();
});

zoomInBtn.addEventListener("click", () => zoomBy(1.2));
zoomOutBtn.addEventListener("click", () => zoomBy(0.85));
zoomResetBtn.addEventListener("click", resetZoom);

bringFrontBtn.addEventListener("click", bringToFront);
sendBackBtn.addEventListener("click", sendToBack);
pinToggleBtn.addEventListener("click", togglePin);
deleteBtn.addEventListener("click", deleteSelection);
downloadBtn.addEventListener("click", downloadJSON);
createGroupBtn.addEventListener("click", createGroupFromSelection);
undoBtn.addEventListener("click", undo);
redoBtn.addEventListener("click", redo);

// Zoom + pan
svg.addEventListener("wheel", (event) => {
  event.preventDefault();
  const rect = svg.getBoundingClientRect();
  const cursor = { x: event.clientX - rect.left, y: event.clientY - rect.top };
  const world = {
    x: (cursor.x - view.offsetX) / view.scale,
    y: (cursor.y - view.offsetY) / view.scale,
  };
  const delta = event.deltaY < 0 ? 1.1 : 0.9;
  const nextScale = Math.min(3, Math.max(0.4, view.scale * delta));
  view.offsetX = cursor.x - world.x * nextScale;
  view.offsetY = cursor.y - world.y * nextScale;
  view.scale = nextScale;
  render();
});

let panning = false;
let panStart = { x: 0, y: 0 };

svg.addEventListener("mousedown", (event) => {
  if (event.target.closest(".node")) return;
  if (toolMode !== "select") {
    drawStart = screenToWorld(event.clientX, event.clientY);
    return;
  }
  panning = true;
  panStart = { x: event.clientX - view.offsetX, y: event.clientY - view.offsetY };
});

svg.addEventListener("mousemove", (event) => {
  if (drawStart) return;
  if (!panning) return;
  view.offsetX = event.clientX - panStart.x;
  view.offsetY = event.clientY - panStart.y;
  render();
});

svg.addEventListener("mouseup", (event) => {
  if (drawStart) {
    const end = screenToWorld(event.clientX, event.clientY);
    if (toolMode === "text") addAnnotationText(end);
    if (toolMode === "box") addAnnotationBox(drawStart, end);
    if (toolMode === "arrow") addAnnotationArrow(drawStart, end);
    drawStart = null;
    return;
  }
  panning = false;
});

svg.addEventListener("mouseleave", () => {
  panning = false;
});

// ============================================================================
// PanLL Integration — Three-panel bridge
// ============================================================================
//
// Panel-L: Ecosystem constraints (slot policies, edge rules, governance)
// Panel-N: Ecosystem health reasoning (dependency analysis, orphan detection)
// Panel-W: Graph visualization, scan results, health dashboard
//
// Communication via window.postMessage when embedded in PanLL, or
// fetch() to PanLL's HTTP API when running standalone.

const panllBridge = {
  status: "disconnected", // disconnected | connecting | connected | error
  instanceId: null,
  autoSync: false,
  endpoint: "http://localhost:1430",

  /** Detect if running inside a PanLL host (iframe or same-origin embed). */
  isPanllHost() {
    return typeof window.__PANLL_INTERNALS__ !== "undefined" && window.__PANLL_INTERNALS__ !== null;
  },

  /** Attempt to connect to PanLL. */
  async connect() {
    panllBridge.status = "connecting";
    updatePanllStatusUI();

    if (panllBridge.isPanllHost()) {
      panllBridge.status = "connected";
      panllBridge.instanceId = "embedded";
      updatePanllStatusUI();
      return;
    }

    try {
      const resp = await fetch(panllBridge.endpoint + "/api/v1/health");
      if (resp.ok) {
        panllBridge.status = "connected";
        panllBridge.instanceId = "standalone";
      } else {
        panllBridge.status = "error";
      }
    } catch {
      panllBridge.status = "error";
    }
    updatePanllStatusUI();
  },

  /** Disconnect from PanLL. */
  disconnect() {
    panllBridge.status = "disconnected";
    panllBridge.instanceId = null;
    panllBridge.autoSync = false;
    updatePanllStatusUI();
  },

  /** Push graph snapshot to PanLL Panel-W. */
  syncGraph() {
    if (panllBridge.status !== "connected") return;

    const payload = {
      type: "reposystem:graph-snapshot",
      source: "reposystem-web",
      timestamp: new Date().toISOString(),
      data: {
        nodes: graphData.nodes,
        edges: graphData.edges,
        groups: graphData.groups,
        annotations: graphData.annotations,
      },
    };

    if (panllBridge.isPanllHost()) {
      // Embedded — postMessage to parent PanLL window
      window.parent.postMessage(payload, "*");
    }
    if (panllBridge.instanceId === "standalone") {
      // Standalone — POST graph snapshot to PanLL Panel-W API
      try {
        await fetch(panllBridge.endpoint + "/api/v1/panel-w/graph", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      } catch (err) {
        panllBridge.status = "error";
        updatePanllStatusUI();
        setStatus("PanLL sync failed: " + (err.message || "network error"));
        return;
      }
    }

    setStatus(`Synced ${graphData.nodes.length} nodes to PanLL Panel-W`);
  },

  /** Push constraint summary to PanLL Panel-L. */
  syncConstraints(constraints) {
    if (panllBridge.status !== "connected") return;

    const payload = {
      type: "reposystem:constraint-update",
      source: "reposystem-web",
      timestamp: new Date().toISOString(),
      data: constraints,
    };

    if (panllBridge.isPanllHost()) {
      window.parent.postMessage(payload, "*");
    } else {
      fetch(panllBridge.endpoint + "/api/v1/panel-l/constraints", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }).catch(() => {});
    }
  },

  /** Push health event to PanLL Panel-N. */
  emitHealthEvent(event) {
    if (panllBridge.status !== "connected") return;

    const payload = {
      type: "reposystem:health-event",
      source: "reposystem-web",
      timestamp: new Date().toISOString(),
      data: event,
    };

    if (panllBridge.isPanllHost()) {
      window.parent.postMessage(payload, "*");
    } else {
      fetch(panllBridge.endpoint + "/api/v1/panel-n/health", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }).catch(() => {});
    }
  },
};

/** Listen for inbound PanLL messages. */
window.addEventListener("message", (event) => {
  if (!event.data || typeof event.data.type !== "string") return;
  if (!event.data.type.startsWith("panll:")) return;

  switch (event.data.type) {
    case "panll:constraint-request":
      // Panel-L is requesting current ecosystem constraints
      panllBridge.syncConstraints({
        groups: graphData.groups.length,
        edges: graphData.edges.length,
        nodes: graphData.nodes.length,
      });
      break;

    case "panll:scan-request":
      // Panel-N is requesting a fresh scan — reload data
      if (loadSampleBtn) loadSampleBtn.click();
      break;

    case "panll:export-request":
      // Panel-W wants a JSON export
      panllBridge.syncGraph();
      break;

    case "panll:filter-request":
      // Panel-W wants to apply a filter
      if (event.data.aspect && aspectSelect) {
        aspectSelect.value = event.data.aspect;
        render();
      }
      break;
  }
});

/** Update PanLL status indicator in the UI. */
function updatePanllStatusUI() {
  const el = document.getElementById("panllStatus");
  if (!el) return;

  const labels = {
    disconnected: "PanLL: Off",
    connecting: "PanLL: ...",
    connected: "PanLL: On",
    error: "PanLL: Err",
  };

  el.textContent = labels[panllBridge.status] || "PanLL: ?";
  el.className = "panll-status panll-" + panllBridge.status;
}

// Auto-sync graph on data changes when PanLL autoSync is enabled
const originalLoadGraph = loadGraph;
loadGraph = function (raw) {
  originalLoadGraph(raw);
  if (panllBridge.autoSync && panllBridge.status === "connected") {
    panllBridge.syncGraph();
  }
};

// Auto-detect PanLL host on startup
if (panllBridge.isPanllHost()) {
  panllBridge.connect();
}

document.addEventListener("keydown", (event) => {
  if (event.target.tagName === "INPUT" || event.target.tagName === "SELECT") return;
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "z") {
    event.preventDefault();
    if (event.shiftKey) redo();
    else undo();
    return;
  }
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "y") {
    event.preventDefault();
    redo();
    return;
  }
  const key = event.key.toLowerCase();
  if (key === "?") {
    const shortcuts = document.querySelector(".shortcuts");
    if (shortcuts) shortcuts.open = !shortcuts.open;
  } else if (key === "+") {
    zoomBy(1.2);
  } else if (key === "-") {
    zoomBy(0.85);
  } else if (key === "0") {
    resetZoom();
  } else if (key === "f" && event.shiftKey) {
    bringToFront();
  } else if (key === "f") {
    applyLayout(layoutSelect.value);
    render();
  } else if (key === "l") {
    labelToggle.checked = !labelToggle.checked;
    render();
  } else if (key === "w") {
    weightToggle.checked = !weightToggle.checked;
    render();
  } else if (key === "g") {
    const options = Array.from(groupSelect.options);
    const idx = options.findIndex((o) => o.value === groupSelect.value);
    const next = options[(idx + 1) % options.length];
    if (next) {
      groupSelect.value = next.value;
      render();
    }
  } else if (key === "a") {
    const options = Array.from(aspectSelect.options);
    const idx = options.findIndex((o) => o.value === aspectSelect.value);
    const next = options[(idx + 1) % options.length];
    if (next) {
      aspectSelect.value = next.value;
      render();
    }
  } else if (key === "delete" || key === "backspace") {
    deleteSelection();
  } else if (key === "p") {
    togglePin();
  } else if (key === "b" && !event.shiftKey) {
    sendToBack();
  } else if (key === "escape") {
    setTool("select");
  } else if (key === "t") {
    setTool("text");
  } else if (key === "r") {
    setTool("box");
  } else if (key === "v") {
    setTool("arrow");
  } else if (key === "n") {
    showAddNodeForm();
  } else if (key === "e") {
    showAddEdgeForm();
  } else if (key === "/") {
    event.preventDefault();
    searchInput.focus();
  }
});
