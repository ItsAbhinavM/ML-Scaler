import http from "k6/http";
import { check, sleep } from "k6";
import encoding from "k6/encoding";

const targetUrl = __ENV.TARGET_URL || "http://localhost:8000/predict";
const scenario = __ENV.SCENARIO || "baseline";

// 1x1 PNG to keep the load-test self-contained (no external files).
const embeddedPngB64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMBApL0Kc8AAAAASUVORK5CYII=";

const imageData = encoding.b64decode(embeddedPngB64, "std");

const scenarios = {
  baseline: { vus: 5, duration: "30s" },
  stress_500: { vus: 500, duration: "60s" },
  stress_1000: { vus: 1000, duration: "60s" },
  stress_5000: { vus: 5000, duration: "60s" },
  autoscale: { vus: 200, duration: "120s" },
};

export const options = scenarios[scenario] || scenarios.baseline;

export default function () {
  const payload = {
    file: http.file(imageData, "tiny.png", "image/png"),
  };
  const res = http.post(targetUrl, payload);
  check(res, { "status is 200": (r) => r.status === 200 });
  sleep(1);
}
