#!/usr/bin/env python3
"""初回設定の進み具合を JSON で返す（/SEO設定 のウィザード・/SEO検証・seo-start が共通で使う）。

  python3 setup-status.py [--root <ワークスペース>]

順番は procedures/seo-setup.md の一本道と同じ: folder → db → profile → sheet → wp → rules。
認証メモは **ファイル名の一致だけ** を見る（中身は開かない）。
state: done / todo / optional（任意項目の未設定）。next は次にやる必須項目（無ければ null）。
"""
import argparse
import glob
import json
import os
import pathlib
import re
import sys

CRED_GLOBS = (".env", "*.env", "wp*.txt", "WP*.txt", "wordpress*.txt")
EPHEMERAL = ("/home/claude", "/root", "/tmp", "/var/tmp")


def top_value(text, key, block=None):
    """config.yaml から key の値を取る（block 指定ならその下の 2 スペース字下げ）。コメントと引用符は外す。"""
    if block:
        m = re.search(rf"^{re.escape(block)}:\s*\n((?:[ \t]+.*\n?|\s*\n)*)", text, flags=re.M)
        text, pat = (m.group(1) if m else ""), rf"^[ \t]+{re.escape(key)}:(.*)$"
    else:
        pat = rf"^{re.escape(key)}:(.*)$"
    m = re.search(pat, text, flags=re.M)
    if not m:
        return ""
    v = re.sub(r"\s+#.*$", "", m.group(1)).strip().strip("\"'")
    return "" if v in ("null", "~") else v


def folder_state(root):
    """永続フォルダか。一時領域（/home/claude 等）の直下なら todo。SEO_WORKSPACE_PERSISTENT=1/0 で上書きできる。"""
    ov = os.environ.get("SEO_WORKSPACE_PERSISTENT")
    if ov in ("0", "1"):
        return ov == "1"
    p = root.resolve().as_posix()
    return not any(p == e or p.startswith(e + "/") for e in EPHEMERAL)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    a = ap.parse_args()
    root = pathlib.Path(a.root)
    k = root / "knowledge"

    cfg_path = k / "config" / "config.yaml"
    cfg = cfg_path.read_text(encoding="utf-8-sig") if cfg_path.exists() else ""
    own, sheet = top_value(cfg, "own_domain"), top_value(cfg, "sheet_id")
    site, method = top_value(cfg, "site_url", "wp"), top_value(cfg, "method", "wp")
    cred = any(glob.glob(str(root / g)) for g in CRED_GLOBS)
    needs_cred = method in ("rest", "both")

    steps = [
        ("folder", True, folder_state(root), "保存先フォルダ（未接続だと設定と記憶がセッション終了で消える）"),
        ("db", True, (k / "data" / "seo.db").exists(), "記憶 DB"),
        ("profile", False, bool(own) and (k / "config" / "site-profile.yaml").exists(), "自社ドメインとサイトプロファイル"),
        ("sheet", False, bool(sheet), "成果物スプレッドシート"),
        ("wp", False, bool(site) and bool(method) and (cred or not needs_cred), "WordPress 接続"),
        ("rules", False, (k / "rules" / "gate_rules.yaml").exists() or (k / "memory" / "original.md").exists(), "表記ルール・自社の主張"),
    ]
    out, nxt = [], None
    for name, required, ok, label in steps:
        state = "done" if ok else ("todo" if required else "optional")
        out.append({"step": name, "state": state, "label": label})
        if not ok and nxt is None and name != "rules":
            nxt = name
    detail = {"own_domain": bool(own), "sheet_id": bool(sheet), "wp_site_url": bool(site), "wp_method": method or None,
              "cred_file": cred, "cred_needed": needs_cred}
    done = sum(1 for s in out if s["state"] == "done")
    json.dump({"root": root.resolve().as_posix(), "done": done, "total": len(out), "next": nxt,
               "can_start": all(s["state"] == "done" for s in out[:2]), "steps": out, "detail": detail},
              sys.stdout, ensure_ascii=False, indent=1)
    print()


if __name__ == "__main__":
    main()
