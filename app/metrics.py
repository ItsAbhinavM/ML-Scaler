from prometheus_client import Counter, Gauge, Histogram

REQUESTS_TOTAL = Counter(
    "yolo_requests_total",
    "Total number of HTTP requests",
    ["method", "path", "status"],
)

REQUEST_LATENCY = Histogram(
    "yolo_request_latency_seconds",
    "HTTP request latency in seconds",
    ["method", "path"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)

INFERENCE_DURATION = Histogram(
    "yolo_inference_duration_seconds",
    "YOLO inference duration in seconds",
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)

ERRORS_TOTAL = Counter(
    "yolo_errors_total",
    "Total number of errors",
    ["type"],
)

ACTIVE_REQUESTS = Gauge(
    "yolo_active_requests",
    "Number of active HTTP requests",
)
