#!/usr/bin/env python3
"""図解 HTML → PNG（④ 手順3）。figures/ の *.html を 127.0.0.1 で配信し、#figure 要素をスクリーンショットして同名 .png を書く。

  python3 figures-png.py memory/work/<kw>/figures [--scale 2]

クラウドのセッションでは、ユーザーのブラウザ（Claude in Chrome）からコンテナの localhost に届かないので、コンテナ内の Playwright で撮る。
Playwright（Python）が無い環境では exit 3 を返す → 手順書のブラウザ経路（http.server + スクリーンショット）に切り替える。外部へは接続しない。
"""
import argparse, functools, http.server, json, pathlib, socketserver, sys, threading


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--scale", type=float, default=2)
    a = ap.parse_args()
    d = pathlib.Path(a.dir)
    pages = sorted(d.glob("*.html"))
    if not pages:
        print(json.dumps({"error": f"{d} に .html がありません"}, ensure_ascii=False)); sys.exit(2)
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(json.dumps({"error": "playwright（Python）がありません。ブラウザ経路に切り替えてください", "fallback": "browser"}, ensure_ascii=False)); sys.exit(3)

    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *args):  # アクセスログを出さない（出力は最後の JSON 1 行だけにする）
            pass
    handler = functools.partial(Quiet, directory=str(d))
    srv = socketserver.TCPServer(("127.0.0.1", 0), handler)
    port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    out = []
    try:
        with sync_playwright() as p:
            b = p.chromium.launch()
            pg = b.new_page(device_scale_factor=a.scale, viewport={"width": 1200, "height": 900})
            for f in pages:
                pg.goto(f"http://127.0.0.1:{port}/{f.name}", wait_until="networkidle")
                el = pg.query_selector("#figure") or pg.query_selector("body")
                png = f.with_suffix(".png")
                el.screenshot(path=str(png))
                out.append({"html": f.name, "png": png.name, "bytes": png.stat().st_size})
            b.close()
    finally:
        srv.shutdown()
    print(json.dumps({"ok": True, "figures": out}, ensure_ascii=False))


if __name__ == "__main__":
    main()
