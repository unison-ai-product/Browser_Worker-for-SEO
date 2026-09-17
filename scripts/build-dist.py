#!/usr/bin/env python3
"""配布物のビルド。Git 管理下のファイルから開発専用のものを除いて、配布ツリーと .plugin を作る。

  python scripts/build-dist.py --out dist            # dist/ に配布ツリー、dist/../seo-content-worker-<ver>.plugin
  python scripts/build-dist.py --out dist --no-zip

配布リポジトリ（UNISON-TECHNOLOGY/seo-content-worker）へは Release ワークフローがこのツリーを同期する。
scripts/（verify.sh・test-hooks.sh を含む）は /SEO検証 が使うので配布に含める。
"""
import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEV_ONLY = (".github/", "scripts/build-dist.py")


def dist_files():
    out = subprocess.run(["git", "-c", "core.quotepath=off", "ls-files"], cwd=ROOT,
                         capture_output=True, text=True, encoding="utf-8", check=True).stdout
    return [f for f in out.splitlines() if f and not f.startswith(DEV_ONLY) and f not in DEV_ONLY]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--no-zip", action="store_true")
    a = ap.parse_args()

    out = pathlib.Path(a.out).resolve()
    if out.exists():
        shutil.rmtree(out)
    files = dist_files()
    for f in files:
        dst = out / f
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / f, dst)

    ver = json.load(open(ROOT / ".claude-plugin/plugin.json", encoding="utf-8"))["version"]
    result = {"version": ver, "files": len(files), "dist": str(out)}
    if not a.no_zip:
        z = out.parent / f"seo-content-worker-{ver}.plugin"
        with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
            for f in files:
                zf.write(out / f, f)
        result["plugin"] = str(z)
    json.dump(result, sys.stdout, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main()
