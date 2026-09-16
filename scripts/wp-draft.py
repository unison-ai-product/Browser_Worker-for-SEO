#!/usr/bin/env python3
"""WordPress REST で「下書き」を作る（公開はしない）。認証は .env の WP_USER / WP_APP_PASSWORD（値は表示しない）。

  wp-draft.py --site https://example.jp --check
  wp-draft.py --site https://example.jp --title "T" --content article.html [--slug s] [--category 12] [--excerpt "..."] [--status draft]
  wp-draft.py --site https://example.jp --media figures/a.png [--alt "..."]      画像を 1 枚アップして ID と URL を返す

status は draft か pending のみ受け付ける（publish / future / private は拒否。hooks/publish-guard.sh も止める）。
"""
import argparse, base64, json, os, pathlib, sys, urllib.request, urllib.error, mimetypes
import sys as _sys
if hasattr(_sys.stdout, 'reconfigure'):
    _sys.stdout.reconfigure(encoding='utf-8'); _sys.stderr.reconfigure(encoding='utf-8')


def load_env():
    p = pathlib.Path(".env")
    if p.exists():
        for line in p.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.split("=", 1); os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    u, pw = os.environ.get("WP_USER"), os.environ.get("WP_APP_PASSWORD")
    if not u or not pw:
        print(json.dumps({"ok": False, "error": ".env に WP_USER / WP_APP_PASSWORD がありません（人間が置く）"}, ensure_ascii=False)); sys.exit(2)
    return "Basic " + base64.b64encode(f"{u}:{pw}".encode()).decode()


def req(site, path, auth, method="GET", body=None, headers=None):
    h = {"Authorization": auth, "User-Agent": "seo-content-worker/0.1"}
    if headers: h.update(headers)
    data = None
    if body is not None and not isinstance(body, bytes):
        data = json.dumps(body).encode(); h["Content-Type"] = "application/json"
    elif isinstance(body, bytes):
        data = body
    r = urllib.request.Request(site.rstrip("/") + "/wp-json/wp/v2" + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return resp.status, json.loads(resp.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode()[:500]}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--site", required=True)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--title"); ap.add_argument("--content"); ap.add_argument("--slug"); ap.add_argument("--category", type=int); ap.add_argument("--excerpt")
    ap.add_argument("--status", default="draft")
    ap.add_argument("--media"); ap.add_argument("--alt", default="")
    a = ap.parse_args()

    if not a.site.lower().startswith("https://"):
        print(json.dumps({"ok": False, "error": "site は https:// のみ（アプリケーションパスワードを平文で送らない）"}, ensure_ascii=False)); sys.exit(1)
    if a.status not in ("draft", "pending"):
        print(json.dumps({"ok": False, "error": f"status={a.status} は許可されていません（draft / pending のみ）。公開は人間が WP 管理画面で行います。"}, ensure_ascii=False)); sys.exit(1)

    auth = load_env()
    if a.check:
        st, me = req(a.site, "/users/me?context=edit", auth)
        ok = st == 200
        caps = me.get("capabilities", {}) if ok else {}
        print(json.dumps({"ok": ok, "status": st, "user": me.get("slug") if ok else None, "can_edit_posts": bool(caps.get("edit_posts")), "can_upload": bool(caps.get("upload_files"))}, ensure_ascii=False)); sys.exit(0 if ok else 1)

    if a.media:
        p = pathlib.Path(a.media); mt = mimetypes.guess_type(p.name)[0] or "application/octet-stream"
        st, res = req(a.site, "/media", auth, "POST", p.read_bytes(), {"Content-Type": mt, "Content-Disposition": f'attachment; filename="{p.name}"'})
        if st in (200, 201) and a.alt:
            req(a.site, f"/media/{res['id']}", auth, "POST", {"alt_text": a.alt})
        print(json.dumps({"ok": st in (200, 201), "status": st, "id": res.get("id"), "url": res.get("source_url"), "error": res.get("error")}, ensure_ascii=False)); sys.exit(0 if st in (200, 201) else 1)

    if not (a.title and a.content):
        print(json.dumps({"ok": False, "error": "--title と --content が必要です"}, ensure_ascii=False)); sys.exit(2)
    body = {"title": a.title, "content": pathlib.Path(a.content).read_text(encoding="utf-8"), "status": a.status}
    if a.slug: body["slug"] = a.slug
    if a.category: body["categories"] = [a.category]
    if a.excerpt: body["excerpt"] = a.excerpt
    st, res = req(a.site, "/posts", auth, "POST", body)
    print(json.dumps({"ok": st in (200, 201), "status": st, "post_id": res.get("id"), "post_status": res.get("status"), "link": res.get("link"), "preview": (res.get("link") or "") + ("&preview=true" if "?" in (res.get("link") or "") else "?preview=true"), "error": res.get("error")}, ensure_ascii=False))
    sys.exit(0 if st in (200, 201) else 1)


if __name__ == "__main__":
    main()
