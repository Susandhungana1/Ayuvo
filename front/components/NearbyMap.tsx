"use client";

import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

interface Place {
  id: number;
  name: string;
  kind: "hospital" | "pharmacy" | "clinic";
  lat: number;
  lon: number;
  distanceKm: number;
}

const KATHMANDU: [number, number] = [27.7172, 85.324];

function haversineKm(a: [number, number], b: [number, number]): number {
  const R = 6371;
  const dLat = ((b[0] - a[0]) * Math.PI) / 180;
  const dLon = ((b[1] - a[1]) * Math.PI) / 180;
  const lat1 = (a[0] * Math.PI) / 180;
  const lat2 = (b[0] * Math.PI) / 180;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLon / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return R * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

// Brand palette (WEB_DESIGN.md §2): alert red for hospitals, primary cyan for
// clinics, ok green for pharmacies.
const ICON_STYLE: Record<Place["kind"], { color: string; symbol: string }> = {
  hospital: { color: "#b91c1c", symbol: "H" },
  clinic: { color: "#0e7490", symbol: "C" },
  pharmacy: { color: "#046a4e", symbol: "℞" },
};

function markerIcon(kind: Place["kind"]) {
  const { color, symbol } = ICON_STYLE[kind];
  return L.divIcon({
    className: "",
    html: `<div style="background:${color};width:26px;height:26px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);display:flex;align-items:center;justify-content:center;box-shadow:0 1px 4px rgba(0,0,0,.4);border:2px solid #fff"><span style="transform:rotate(45deg);color:#fff;font-weight:700;font-size:12px">${symbol}</span></div>`,
    iconSize: [26, 26],
    iconAnchor: [13, 26],
  });
}

export default function NearbyMap() {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapObj = useRef<L.Map | null>(null);
  const layerRef = useRef<L.LayerGroup | null>(null);
  const [places, setPlaces] = useState<Place[]>([]);
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState(() =>
    typeof navigator !== "undefined" && navigator.geolocation
      ? "Locating you…"
      : "Location unavailable — showing Kathmandu."
  );
  const [center, setCenter] = useState<[number, number] | null>(() =>
    typeof navigator !== "undefined" && navigator.geolocation ? null : KATHMANDU
  );

  // Get location — the geolocation callbacks are the subscription here, and
  // setState only ever happens inside them.
  useEffect(() => {
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setCenter([pos.coords.latitude, pos.coords.longitude]);
        setStatus("Showing care near you.");
      },
      () => {
        setStatus("Location denied — showing Kathmandu. Enable location for nearby results.");
        setCenter(KATHMANDU);
      },
      { timeout: 8000 }
    );
  }, []);

  // Init map + fetch places once we have a center
  useEffect(() => {
    if (!center || !mapRef.current) return;

    if (!mapObj.current) {
      mapObj.current = L.map(mapRef.current).setView(center, 14);
      // Drop Leaflet's own "Leaflet" prefix (not legally required); keep the
      // OpenStreetMap attribution below — that one is required by the ODbL license.
      mapObj.current.attributionControl.setPrefix(false);
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "© OpenStreetMap contributors",
        maxZoom: 19,
      }).addTo(mapObj.current);
      layerRef.current = L.layerGroup().addTo(mapObj.current);
    } else {
      mapObj.current.setView(center, 14);
    }

    // user marker
    L.circleMarker(center, { radius: 7, color: "#0e7490", fillColor: "#0e7490", fillOpacity: 1 })
      .addTo(layerRef.current!)
      .bindPopup("You are here");

    const fetchPlaces = async () => {
      setLoading(true);
      const [lat, lon] = center;
      const radius = 4000; // meters
      const query = `[out:json][timeout:25];(node["amenity"="hospital"](around:${radius},${lat},${lon});node["amenity"="clinic"](around:${radius},${lat},${lon});node["amenity"="pharmacy"](around:${radius},${lat},${lon}););out body 60;`;
      const endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
      ];
      try {
        let data: { elements?: Array<{ id: number; lat?: number; lon?: number; tags?: Record<string, string> }> } | null = null;
        for (const url of endpoints) {
          try {
            const res = await fetch(url, { method: "POST", body: "data=" + encodeURIComponent(query) });
            if (res.ok) { data = await res.json(); break; }
          } catch { /* try next mirror */ }
        }
        if (!data) throw new Error("all overpass mirrors failed");
        const found: Place[] = (data.elements || [])
          .filter((e): e is { id: number; lat: number; lon: number; tags?: Record<string, string> } =>
            typeof e.lat === "number" && typeof e.lon === "number")
          .map((e) => {
            const kind = (e.tags?.amenity as Place["kind"]) || "clinic";
            return {
              id: e.id,
              name: e.tags?.name || (kind.charAt(0).toUpperCase() + kind.slice(1)),
              kind,
              lat: e.lat,
              lon: e.lon,
              distanceKm: haversineKm(center, [e.lat, e.lon]),
            };
          })
          .sort((a, b) => a.distanceKm - b.distanceKm)
          .slice(0, 40);

        found.forEach((p) => {
          L.marker([p.lat, p.lon], { icon: markerIcon(p.kind) })
            .addTo(layerRef.current!)
            .bindPopup(`<b>${p.name}</b><br/>${p.kind} · ${p.distanceKm.toFixed(1)} km`);
        });
        setPlaces(found);
        if (found.length === 0) setStatus("No facilities found within 4 km.");
      } catch {
        setStatus("Could not load nearby facilities (network error).");
      } finally {
        setLoading(false);
      }
    };
    fetchPlaces();
  }, [center]);

  return (
    <div className="flex flex-col gap-lg">
      <div>
        <div ref={mapRef} className="w-full rounded-md border border-outline relative z-0" style={{ height: 480 }} />
        <p className="text-xs text-on-surface-variant mt-sm">{status}</p>
      </div>
      <div className="relative z-10">
        <div className="flex items-center gap-md mb-md text-xs">
          <span className="flex items-center gap-xs"><span className="w-3 h-3 rounded-full inline-block" style={{ background: ICON_STYLE.hospital.color }} />Hospital</span>
          <span className="flex items-center gap-xs"><span className="w-3 h-3 rounded-full inline-block" style={{ background: ICON_STYLE.clinic.color }} />Clinic</span>
          <span className="flex items-center gap-xs"><span className="w-3 h-3 rounded-full inline-block" style={{ background: ICON_STYLE.pharmacy.color }} />Pharmacy</span>
        </div>
        <div className="space-y-sm">
          {loading ? (
            <p className="text-on-surface-variant text-sm">Loading nearby care…</p>
          ) : (
            places.map((p) => (
              <div key={p.id} className="border border-outline/60 rounded-md p-md flex justify-between items-center gap-sm">
                <div className="min-w-0">
                  <p className="font-medium text-on-surface text-sm truncate">{p.name}</p>
                  <p className="text-xs text-on-surface-variant capitalize">{p.kind} · {p.distanceKm.toFixed(1)} km away</p>
                </div>
                <a
                  href={`https://www.openstreetmap.org/directions?to=${p.lat},${p.lon}`}
                  target="_blank" rel="noopener noreferrer"
                  className="shrink-0 text-xs font-semibold text-primary hover:underline"
                >
                  Directions
                </a>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}