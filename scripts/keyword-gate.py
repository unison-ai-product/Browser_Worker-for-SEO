#!/usr/bin/env python3
"""ルール＆レギュレーションゲートの機械判定（skills/gate-script §2 の 14 節）。

  keyword-gate.py (--outline F | --article F) --required required_keywords.txt --rules gate_rules.yaml [--json out.json] [--title "..."] [--meta "..."]
  keyword-gate.py --selftest

終了コード: 0 = PASS（警告のみ可）、1 = FAIL、2 = 入力不備。
required_keywords.txt: 1 行 1 語。行頭 "+" = 必須、"-" = 推奨（無印は必須）。
Markdown 入力: 先頭の "# " を H1/タイトル、"## " を H2、"### " を H3、最初の H2 までをリード文とみなす。
YAML は PyYAML があれば使い、無ければ最小パーサ（この雛形の書式のみ）で読む。
"""
import argparse, json, re, sys, pathlib
import sys as _sys
if hasattr(_sys.stdout, 'reconfigure'):
    _sys.stdout.reconfigure(encoding='utf-8'); _sys.stderr.reconfigure(encoding='utf-8')


def load_yaml(path):
    txt = pathlib.Path(path).read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore
        return yaml.safe_load(txt) or {}
    except ImportError:
        return _mini_yaml(txt)


def _scalar(v):
    v = v.strip()
    if v in ("null", "~", ""): return None
    if v in ("true", "True"): return True
    if v in ("false", "False"): return False
    if v.startswith("[") and v.endswith("]"):
        inner = v[1:-1].strip()
        return [] if not inner else [_scalar(x) for x in re.split(r",\s*(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", inner)]
    if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")): return v[1:-1]
    try:
        return int(v) if re.fullmatch(r"-?\d+", v) else float(v) if re.fullmatch(r"-?\d+\.\d+", v) else v
    except ValueError:
        return v


def _mini_yaml(txt):
    """2 段までのマップ + リスト（"- x"）+ "k: v" の最小パーサ。コメント行は無視。"""
    root, cur, curkey = {}, None, None
    for raw in txt.splitlines():
        line = raw.split(" #")[0].rstrip() if not raw.strip().startswith("#") else ""
        if not line.strip(): continue
        indent = len(line) - len(line.lstrip())
        s = line.strip()
        if indent == 0:
            if s.endswith(":"): curkey = s[:-1]; root[curkey] = {}; cur = root[curkey]
            else:
                k, v = s.split(":", 1); root[k.strip()] = _scalar(v); cur = None; curkey = None
        else:
            if s.startswith("- "):
                if not isinstance(root.get(curkey), list): root[curkey] = []
                root[curkey].append(_scalar(s[2:]))
            else:
                k, v = s.split(":", 1)
                if isinstance(cur, dict): cur[_scalar(k) if k.strip().startswith('"') else k.strip()] = _scalar(v)
    return root


def parse_md(text):
    lines = text.splitlines()
    title, h2, h3, lead, body = None, [], [], [], []
    seen_h2 = False; order = []; in_fence = False
    for ln in lines:
        if ln.lstrip().startswith("```"): in_fence = not in_fence; (body if seen_h2 else lead).append(ln); continue
        if in_fence: (body if seen_h2 else lead).append(ln); continue
        if ln.startswith("# ") and title is None: title = ln[2:].strip(); continue
        if ln.startswith("## "): h2.append(ln[3:].strip()); order.append("h2"); seen_h2 = True; continue
        if ln.startswith("### "): h3.append(ln[4:].strip()); order.append("h3"); continue
        (body if seen_h2 else lead).append(ln)
    return {"title": title or "", "h2": h2, "h3": h3, "lead": "\n".join(lead), "body": "\n".join(body), "order": order, "all": text}


def split_sentences(text):
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"^#+ .*$", "", text, flags=re.M)
    text = re.sub(r"^\s*(\|.*|!\[.*)$", "", text, flags=re.M)  # 表の行・画像行は文として数えない
    return [s.strip() for s in re.split(r"(?<=[。！？!?])\s*", text) if s.strip()]


def site_configured(profile_path):
    """config.yaml の own_domain が埋まっているか（無い／空なら未設定モード）。"""
    if not profile_path: return None
    p = pathlib.Path(profile_path)
    if not p.exists(): return False
    cfg = load_yaml(p) or {}
    return bool(str(cfg.get("own_domain") or "").strip())


def run(doc, required, rules, kind, title_override=None, meta=None, keyword=None, h2_median=None, site_ok=None):
    fails, warns, info = [], [], {}
    if site_ok is False:
        info["site_mode"] = "unconfigured"
    if h2_median:
        tol = int((rules.get("structure") or {}).get("h2_tolerance") or 2)
        rules = dict(rules); st0 = dict(rules.get("structure") or {})
        st0["h2_min"] = max(1, int(h2_median) - tol); st0["h2_max"] = int(h2_median) + tol; rules["structure"] = st0
        info["h2_range"] = [st0["h2_min"], st0["h2_max"]]
    if not required:
        warns.append("必須キーワードが未指定です（--required memory/work/<kw>/required_keywords.txt を渡してください）")
    title = title_override or doc["title"]
    heads = " ".join([title] + doc["h2"] + doc["h3"])
    lead = doc["lead"]

    # required_keywords
    rk = rules.get("required_keywords", {}) or {}
    places = rk.get("must_in", ["h1", "h2", "h3", "lead"])
    hay = " ".join([title if "h1" in places else "", " ".join(doc["h2"]) if "h2" in places else "", " ".join(doc["h3"]) if "h3" in places else "", lead if "lead" in places else ""])
    for kw, must in required:
        if kw not in hay:
            (fails if must else warns).append(f"{'必須' if must else '推奨'}キーワード「{kw}」が見出し/リード文にありません")
    # title
    t = rules.get("title", {}) or {}
    if title:
        n = len(title); info["title_len"] = n
        if t.get("fail_over") and n > t["fail_over"]: fails.append(f"タイトル {n} 字 > {t['fail_over']}")
        elif t.get("warn_over") and n > t["warn_over"]: warns.append(f"タイトル {n} 字 > {t['warn_over']}（警告）")
        if t.get("must_include_keyword"):
            if keyword:  # 施策キーワードの全トークンがタイトルにあるか
                missing = [tok for tok in keyword.split() if tok not in title]
                if missing: fails.append(f"タイトルに施策キーワードの語が含まれていません: {missing}")
            elif required and not any(kw in title for kw, m in required if m):
                fails.append("タイトルに必須キーワードが含まれていません")
    else:
        fails.append("タイトル（# 見出し）がありません")
    # meta
    m = rules.get("meta_description", {}) or {}
    if meta and m.get("warn_over") and len(meta) > m["warn_over"]: warns.append(f"メタディスクリプション {len(meta)} 字 > {m['warn_over']}")
    # fullwidth alnum
    if rules.get("fullwidth_alnum") == "fail":
        fw = re.findall(r"[０-９Ａ-Ｚａ-ｚ]+", doc["all"])
        if fw: fails.append(f"全角英数字: {sorted(set(fw))[:10]}")
    # replacements / redundant
    for sec, label in (("replacements", "表記ゆれ・略語"), ("redundant", "二重・冗長表現")):
        for pat, to in (rules.get(sec, {}) or {}).items():
            hits = re.findall(pat, doc["all"])
            if hits: fails.append(f"{label}「{pat}」→「{to}」({len(hits)} 件)")
    # forbidden
    for pat in rules.get("forbidden", []) or []:
        if re.search(pat, doc["all"]): fails.append(f"禁止表現「{pat}」")
    # placeholders
    ph = (rules.get("placeholders", {}) or {}).get("fail_if_present", [])
    for p in ph:
        if p in doc["all"]: fails.append(f"プレースホルダ残り「{p}」")
    # structure
    st = rules.get("structure", {}) or {}
    n2 = len(doc["h2"]); info["h2"] = n2; info["h3"] = len(doc["h3"])
    if st.get("h2_min") and n2 < st["h2_min"]: fails.append(f"H2 {n2} < {st['h2_min']}")
    if st.get("h2_max") and n2 > st["h2_max"]: fails.append(f"H2 {n2} > {st['h2_max']}")
    if st.get("h3_without_h2") == "fail" and doc["order"] and doc["order"][0] == "h3": fails.append("H2 より前に H3 があります")
    if kind == "article":
        sents = split_sentences(doc["body"])
        # sentence_end_repeat
        ser = rules.get("sentence_end_repeat", {}) or {}
        mx = ser.get("max_consecutive", 2); run_ = 1; prev = None
        for s in sents:
            end = re.search(r"(です|ます|でした|ました|ません|だ|である|でしょう)[。！？]?$", s)
            e = end.group(1) if end else None
            run_ = run_ + 1 if e and e == prev else 1
            prev = e
            if e and run_ > mx: fails.append(f"同一語尾「{e}」が {run_} 連続: 「{s[:30]}…」"); run_ = 1
        # sentence_length
        sl = rules.get("sentence_length", {}) or {}
        for s in sents:
            if sl.get("warn_over_chars") and len(s) > sl["warn_over_chars"]: warns.append(f"長い文 {len(s)} 字: 「{s[:30]}…」")
            if sl.get("warn_over_commas") and s.count("、") > sl["warn_over_commas"]: warns.append(f"読点 {s.count('、')} 個: 「{s[:30]}…」")
        # spoken
        sp = rules.get("spoken", {}) or {}
        for pat in sp.get("patterns", []) or []:
            try:
                if re.search(pat, doc["body"]): (warns if sp.get("level", "warn") == "warn" else fails).append(f"話し言葉の疑い「{pat}」")
            except re.error: pass
        # quote_source
        qs = rules.get("quote_source", {}) or {}
        if qs.get("blockquote_requires_source"):
            for mobj in re.finditer(r"(^> .+\n)+", doc["body"], flags=re.M):
                after = doc["body"][mobj.end(): mobj.end() + 200]
                if not re.search(r"(出典|引用元|http)", mobj.group(0) + after): fails.append("出典の無い引用（blockquote）")
        # links / alt
        lk = rules.get("links", {}) or {}
        nlinks = len(re.findall(r"\[\[link:|\]\(https?://", doc["body"])); info["links"] = nlinks
        if lk.get("internal_links_min") and nlinks < lk["internal_links_min"]:
            if site_ok is False: warns.append(f"内部リンク {nlinks} < {lk['internal_links_min']}（own_domain 未設定のため警告扱い。/SEO設定 profile で設定すると FAIL 判定になる）")
            else: fails.append(f"リンク {nlinks} < {lk['internal_links_min']}")
        if lk.get("alt_required"):
            for mobj in re.finditer(r"!\[(.*?)\]\(", doc["body"]):
                if not mobj.group(1).strip(): fails.append("alt の無い画像")
    return {"result": "FAIL" if fails else "PASS", "fails": fails, "warns": warns, "info": info}


def selftest():
    rules = load_yaml(pathlib.Path(__file__).resolve().parent.parent / "templates" / "gate_rules.yaml")
    bad = "# ２０２４年のWEBライター入門\n\nリード。\n\n## とは\n本文です。本文です。本文です。必ず必要です。\n> 引用\n\n### 小見出し\n{{figure: x}}\n"
    r = run(parse_md(bad), [("Webライター", True)], rules, "article")
    exp = ["全角英数字", "表記ゆれ", "二重", "同一語尾", "出典の無い引用", "プレースホルダ", "リンク"]
    missing = [e for e in exp if not any(e in f for f in r["fails"])]
    good = "# Webライターの始め方\n\nリード文です。Webライターの概要を書きます。\n\n## Webライターとは\nWebライターは文章を書く仕事です。理由は次のとおりです。例えば記事を書きます。[参考](https://example.jp/a)\n"
    r2 = run(parse_md(good), [("Webライター", True)], rules, "article", keyword="Webライター 始め方")
    r3 = run(parse_md(good), [("Webライター", True)], rules, "article", keyword="Webライター 副業")
    if not any("副業" in f for f in r3["fails"]): missing.append("施策キーワードのトークン欠落（--keyword）")
    fenced = "# Webライターの始め方" + chr(10)*2 + "リード文です。" + chr(10)*2 + "## Webライターとは" + chr(10) + "本文です。[参考](https://example.jp/a)" + chr(10)*2 + "```" + chr(10) + "## コード内の見出し" + chr(10) + "```" + chr(10)
    if len(parse_md(fenced)["h2"]) != 1: missing.append("コードブロック内の ## を除外")
    nolink = good.replace("[参考](https://example.jp/a)", "")
    r5 = run(parse_md(nolink), [("Webライター", True)], rules, "article", site_ok=False)
    r6 = run(parse_md(nolink), [("Webライター", True)], rules, "article", site_ok=True)
    if r5["result"] != "PASS" or not any("内部リンク" in w for w in r5["warns"]) or r6["result"] != "FAIL": missing.append("未設定モードの内部リンク警告化")
    r4 = run(parse_md(good), [("Webライター", True)], rules, "article", h2_median=6)
    if not any("H2 1 <" in f for f in r4["fails"]): missing.append("--h2-median による H2 数の範囲判定")
    ok = not missing and r2["result"] == "PASS"
    print(json.dumps({"selftest": "PASS" if ok else "FAIL", "missing_detections": missing, "good_doc": r2}, ensure_ascii=False, indent=2))
    sys.exit(0 if ok else 1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--outline"); ap.add_argument("--article"); ap.add_argument("--required"); ap.add_argument("--rules")
    ap.add_argument("--json"); ap.add_argument("--title"); ap.add_argument("--meta"); ap.add_argument("--keyword", help="施策キーワード（タイトル判定）"); ap.add_argument("--h2-median", type=int, help="上位記事の H2 数の中央値（±structure.h2_tolerance で判定）"); ap.add_argument("--profile", help="knowledge/config/config.yaml（own_domain が空なら内部リンクは警告扱い）"); ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest: selftest()
    src = a.article or a.outline
    if not (src and a.rules):
        print(json.dumps({"result": "ERROR", "error": "--outline/--article と --rules が必要です"}, ensure_ascii=False)); sys.exit(2)
    required = []
    if a.required and not pathlib.Path(a.required).exists():
        print(json.dumps({"result": "ERROR", "error": f"必須キーワードのファイルが見つかりません: {a.required}（② 記事分析の手順8 で書き出します）"}, ensure_ascii=False)); sys.exit(2)
    if a.required:
        for ln in pathlib.Path(a.required).read_text(encoding="utf-8").splitlines():
            ln = ln.strip()
            if not ln or ln.startswith("#"): continue
            if ln.startswith("-"): required.append((ln[1:].strip(), False))
            else: required.append((ln.lstrip("+").strip(), True))
    rules_path = pathlib.Path(a.rules)
    note = None
    if not rules_path.exists():
        fallback = pathlib.Path(__file__).resolve().parent.parent / "templates" / "gate_rules.yaml"
        if fallback.exists():
            note = f"rules {a.rules} が無いため templates/gate_rules.yaml を使用（/SEO設定 で knowledge/rules に配置してください）"
            rules_path = fallback
        else:
            print(json.dumps({"result": "ERROR", "error": f"rules が見つかりません: {a.rules}"}, ensure_ascii=False)); sys.exit(2)
    if not pathlib.Path(src).exists():
        print(json.dumps({"result": "ERROR", "error": f"入力が見つかりません: {src}"}, ensure_ascii=False)); sys.exit(2)
    doc = parse_md(pathlib.Path(src).read_text(encoding="utf-8"))
    res = run(doc, required, load_yaml(rules_path), "article" if a.article else "outline", a.title, a.meta, a.keyword, a.h2_median, site_configured(a.profile))
    if note: res.setdefault("warns", []).append(note)
    res["source"] = src
    txt = json.dumps(res, ensure_ascii=False, indent=2)
    if a.json: pathlib.Path(a.json).write_text(txt, encoding="utf-8")
    print(txt)
    sys.exit(0 if res["result"] == "PASS" else 1)


if __name__ == "__main__":
    main()
