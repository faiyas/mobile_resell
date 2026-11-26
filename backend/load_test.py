"""
High-Concurrency Load Tester for Dolly Mobile & Web Backend
Simulates 100 concurrent users hitting the app startup endpoints simultaneously.

Usage:
    python load_test.py
    python load_test.py --concurrency 100 --requests 500
    python load_test.py --url http://127.0.0.1:8010/api/v1
"""

import sys
import time
import argparse
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

DEFAULT_BASE_URL = "https://8010-agq5qlr2uletnjyzudtddvxrdq.instabox.tech/api/v1"

ENDPOINTS = [
    "/cms/sections/",
    "/catalog/device-categories/",
    "/catalog/brands/",
    "/catalog/stats/",
]

def make_request(url):
    t0 = time.perf_counter()
    status = 0
    size = 0
    try:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "DollyLoadTester/1.0",
                "Accept": "application/json",
            }
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            status = resp.status
            data = resp.read()
            size = len(data)
            duration = (time.perf_counter() - t0) * 1000  # ms
            return {"ok": status == 200, "status": status, "time_ms": duration, "size": size, "error": None}
    except urllib.error.HTTPError as e:
        duration = (time.perf_counter() - t0) * 1000
        return {"ok": False, "status": e.code, "time_ms": duration, "size": 0, "error": f"HTTP {e.code}"}
    except Exception as e:
        duration = (time.perf_counter() - t0) * 1000
        return {"ok": False, "status": 0, "time_ms": duration, "size": 0, "error": str(e)}

def run_stress_test(base_url, total_users, total_requests):
    base_url = base_url.rstrip("/")
    print("=" * 65)
    print("🚀 DOLLY BACKEND CONCURRENCY & STRESS TEST")
    print(f"Target Base URL    : {base_url}")
    print(f"Simultaneous Users : {total_users} concurrent workers")
    print(f"Total Requests     : {total_requests}")
    print("=" * 65)

    urls_to_test = [f"{base_url}{ep}" for ep in ENDPOINTS]
    tasks = []
    for i in range(total_requests):
        url = urls_to_test[i % len(urls_to_test)]
        tasks.append(url)

    start_wall_time = time.perf_counter()
    results = []

    print(f"[*] Firing {total_requests} requests across {total_users} threads...")
    with ThreadPoolExecutor(max_workers=total_users) as executor:
        futures = [executor.submit(make_request, url) for url in tasks]
        for f in as_completed(futures):
            results.append(f.result())

    total_wall_time = time.perf_counter() - start_wall_time

    # Calculate statistics
    successes = [r for r in results if r["ok"]]
    failures = [r for r in results if not r["ok"]]
    latencies = sorted([r["time_ms"] for r in results])

    avg_latency = sum(latencies) / len(latencies) if latencies else 0
    min_latency = latencies[0] if latencies else 0
    max_latency = latencies[-1] if latencies else 0
    p50_latency = latencies[int(len(latencies) * 0.50)] if latencies else 0
    p95_latency = latencies[int(len(latencies) * 0.95)] if latencies else 0
    p99_latency = latencies[int(len(latencies) * 0.99)] if latencies else 0
    rps = total_requests / total_wall_time if total_wall_time > 0 else 0

    print("\n" + "=" * 65)
    print("📊 BENCHMARK RESULTS")
    print("=" * 65)
    print(f"Total Wall Time      : {total_wall_time:.2f} seconds")
    print(f"Requests Completed   : {len(results)}/{total_requests}")
    print(f"Throughput (RPS)     : {rps:.1f} req/sec")
    print(f"Successful (200 OK)  : {len(successes)} ({len(successes)/len(results)*100:.1f}%)")
    print(f"Failed / Errors      : {len(failures)} ({len(failures)/len(results)*100:.1f}%)")
    print("-" * 65)
    print(f"Latency Min          : {min_latency:.1f} ms")
    print(f"Latency Median (P50) : {p50_latency:.1f} ms")
    print(f"Latency Avg          : {avg_latency:.1f} ms")
    print(f"Latency 95th % (P95) : {p95_latency:.1f} ms")
    print(f"Latency Max          : {max_latency:.1f} ms")
    print("=" * 65)

    # Health Verdict
    if len(failures) == 0 and p95_latency < 1000:
        print("✅ VERDICT: PASS! Server comfortably supports 100 concurrent users.")
    elif len(failures) == 0 and p95_latency < 3000:
        print("⚠️ VERDICT: MODERATE. 100 users supported, but latency is high (>1s).")
    else:
        print(f"❌ VERDICT: BOTTLENECK DETECTED! {len(failures)} errors or high latency.")
        if failures:
            print("Sample errors:")
            for f in failures[:5]:
                print(f"  - {f['error']}")
    print("=" * 65)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Dolly Concurrency Load Tester")
    parser.add_argument("--url", default=DEFAULT_BASE_URL, help="Target API Base URL")
    parser.add_argument("--concurrency", "-c", type=int, default=100, help="Concurrent users (default: 100)")
    parser.add_argument("--requests", "-n", type=int, default=500, help="Total requests to send (default: 500)")
    args = parser.parse_args()

    run_stress_test(args.url, args.concurrency, args.requests)
