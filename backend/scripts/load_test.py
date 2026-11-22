"""
1103 RECELL - Production Load Testing & Benchmark Suite
Tests concurrent user requests against live API endpoints,
measuring latency (p50, p95, p99), throughput (RPS), and error rates.
"""

import time
import json
import statistics
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE_URL = "https://8010-agq5qlr2uletnjyzudtddvxrdq.instabox.tech/api/v1"

ENDPOINTS = [
    ("GET", f"{BASE_URL}/catalog/categories/", None),
    ("GET", f"{BASE_URL}/valuation/conditions/", None),
    ("GET", f"{BASE_URL}/catalog/brands/", None),
    ("POST", f"{BASE_URL}/valuation/calculate-estimate/", {"variant_id": 1, "selected_option_codes": []}),
]

def make_request(method, url, payload=None):
    start = time.perf_counter()
    headers = {"User-Agent": "1103-Recell-LoadTest/1.0", "Accept": "application/json"}
    data = None
    if payload:
        data = json.dumps(payload).encode('utf-8')
        headers["Content-Type"] = "application/json"
    
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status = response.getcode()
            elapsed_ms = (time.perf_counter() - start) * 1000
            return status, elapsed_ms, None
    except urllib.error.HTTPError as e:
        elapsed_ms = (time.perf_counter() - start) * 1000
        return e.code, elapsed_ms, str(e)
    except Exception as e:
        elapsed_ms = (time.perf_counter() - start) * 1000
        return 0, elapsed_ms, str(e)

def get_active_variant_id():
    try:
        req = urllib.request.Request(f"{BASE_URL}/catalog/models/", headers={"User-Agent": "1103-Recell-LoadTest/1.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            models = json.loads(resp.read().decode())
            for m in models:
                variants = m.get('variants', [])
                if variants:
                    return variants[0]['id']
    except Exception as e:
        print("Note: Could not dynamically fetch variant ID:", e)
    return 44

def run_benchmark(total_requests=80, concurrency=10):
    variant_id = get_active_variant_id()
    endpoints = [
        ("GET", f"{BASE_URL}/catalog/categories/", None),
        ("GET", f"{BASE_URL}/valuation/conditions/", None),
        ("GET", f"{BASE_URL}/catalog/brands/", None),
        ("POST", f"{BASE_URL}/valuation/calculate-estimate/", {"variant_id": variant_id, "selected_option_codes": []}),
    ]

    print("=" * 65)
    print(f"🚀 1103 RECELL PRODUCTION LOAD TEST")
    print(f"Target Base URL: {BASE_URL}")
    print(f"Active Variant ID for Valuation: {variant_id}")
    print(f"Total Requests: {total_requests} | Concurrency: {concurrency} threads")
    print("=" * 65)

    all_latencies = []
    status_counts = {}
    errors = []

    overall_start = time.perf_counter()

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = []
        for i in range(total_requests):
            method, url, payload = endpoints[i % len(endpoints)]
            futures.append(executor.submit(make_request, method, url, payload))

        for f in as_completed(futures):
            status, elapsed_ms, err = f.result()
            all_latencies.append(elapsed_ms)
            status_counts[status] = status_counts.get(status, 0) + 1
            if err:
                errors.append(err)

    total_time = time.perf_counter() - overall_start
    rps = total_requests / total_time if total_time > 0 else 0

    all_latencies.sort()
    avg_latency = statistics.mean(all_latencies) if all_latencies else 0
    p50 = statistics.median(all_latencies) if all_latencies else 0
    p95 = all_latencies[int(len(all_latencies) * 0.95)] if all_latencies else 0
    p99 = all_latencies[int(len(all_latencies) * 0.99)] if all_latencies else 0
    min_lat = min(all_latencies) if all_latencies else 0
    max_lat = max(all_latencies) if all_latencies else 0

    success_count = sum(count for code, count in status_counts.items() if 200 <= code < 400)
    success_rate = (success_count / total_requests) * 100

    print("\n📊 BENCHMARK RESULTS:")
    print(f"• Total Time:         {total_time:.2f} seconds")
    print(f"• Throughput:         {rps:.2f} requests/sec (RPS)")
    print(f"• Success Rate:       {success_rate:.1f}% ({success_count}/{total_requests})")
    print(f"• HTTP Status Codes:  {status_counts}")
    print("-" * 65)
    print("⏱️ LATENCY DISTRIBUTION:")
    print(f"• Fastest:            {min_lat:.1f} ms")
    print(f"• Average:            {avg_latency:.1f} ms")
    print(f"• 50th Percentile:    {p50:.1f} ms (p50)")
    print(f"• 95th Percentile:    {p95:.1f} ms (p95)")
    print(f"• 99th Percentile:    {p99:.1f} ms (p99)")
    print(f"• Slowest:            {max_lat:.1f} ms")
    print("=" * 65)

    if errors:
        print(f"⚠️ Encountered {len(errors)} error(s):")
        for err in list(set(errors))[:5]:
            print(f"  - {err}")
    else:
        print("✓ 0 Network or Unhandled Errors. API is healthy and responsive!")
    print("=" * 65)

if __name__ == "__main__":
    run_benchmark(total_requests=60, concurrency=8)
