const { serve } = require("@hono/node-server");
const { Hono } = require("hono");
const { WebSocketServer } = require("ws");

const app = new Hono();
const { cors } = require('hono/cors');
app.use('*', cors());

// Simple in-memory storage for assets
const assets = {};

// Geofence Polygon (Downtown Delivery)
// Approximately Downtown San Francisco for example
const GEOFENCE_POLYGON = [
  { lat: 37.785, lng: -122.410 },
  { lat: 37.795, lng: -122.410 },
  { lat: 37.795, lng: -122.390 },
  { lat: 37.785, lng: -122.390 }
];

function isPointInPolygon(point, polygon) {
  let x = point.lat, y = point.lng;
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    let xi = polygon[i].lat, yi = polygon[i].lng;
    let xj = polygon[j].lat, yj = polygon[j].lng;
    let intersect = ((yi > y) !== (yj > y)) &&
        (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

app.get("/", (c) => c.text("FleetFlow API Running"));

app.post("/api/telemetry", async (c) => {
  const data = await c.req.json();
  const { id, lat, lng } = data;
  
  const isInside = isPointInPolygon({ lat, lng }, GEOFENCE_POLYGON);
  const status = isInside ? "IN_BOUNDS" : "BREACH";
  
  assets[id] = { id, lat, lng, status, lastUpdate: new Date().toISOString() };
  
  const payload = JSON.stringify({
    type: "TELEMETRY",
    data: assets[id]
  });

  // Broadcast to WebSockets
  wss.clients.forEach((client) => {
    if (client.readyState === 1) {
      client.send(payload);
    }
  });

  return c.json({ success: true, status });
});

app.get("/api/assets", (c) => {
  return c.json(Object.values(assets));
});

const server = serve({
  fetch: app.fetch,
  port: parseInt(process.env.PORT) || 3000
}, (info) => {
  console.log(`Server is running on http://localhost:${info.port}`);
});

const wss = new WebSocketServer({ server });

wss.on("connection", (ws) => {
  console.log("Dashboard connected via WebSocket");
  // Send current state
  ws.send(JSON.stringify({
    type: "INIT",
    data: Object.values(assets)
  }));
});
