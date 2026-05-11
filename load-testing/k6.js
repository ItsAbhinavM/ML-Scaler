import http from "k6/http";
import { check, sleep } from "k6";

const targetUrl = __ENV.TARGET_URL || "http://localhost:8000/predict";
const scenario = __ENV.SCENARIO || "baseline";

const imageData = open("/tmp/bus.jpg", "b");

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
    file: http.file(imageData, "bus.jpg", "image/jpeg"),
  };
  const res = http.post(targetUrl, payload);
  check(res, { "status is 200": (r) => r.status === 200 });
  sleep(1);
}
