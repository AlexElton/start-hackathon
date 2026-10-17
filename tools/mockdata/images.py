"""Resolves "q:<search>" to a Wikimedia Commons photo (960 px thumbnail), cached in images_cache.json."""
import json, os, re, time, urllib.error, urllib.parse, urllib.request

CACHE = os.path.join(os.path.dirname(__file__), "images_cache.json")
UA = "PolarisHackathonDemo/1.0 (mock data for a student demo)"
BAD = re.compile(r"map|kart|logo|\.svg|\.png|\.tif|diagram|flag|coat of arms|våpen|plan|drawing|scan|1[89]\d\d|book|page|postcard|illustration|digifoto|no-nb|burger king", re.I)

def _get(url):
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            time.sleep(20 * (attempt + 1))
    raise RuntimeError("rate limited")

def search(query, used):
    params = {
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": "6",
        "gsrsearch": query, "gsrlimit": "25", "prop": "imageinfo", "iiprop": "url|size|mime", "iiurlwidth": "960",
    }
    data = _get("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params))
    pages = sorted(data.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
    for p in pages:
        ii = (p.get("imageinfo") or [{}])[0]
        w, h = ii.get("width", 0), ii.get("height", 0)
        if ii.get("mime") != "image/jpeg" or w < 1000 or h == 0 or not (1.2 <= w / h <= 2.0):
            continue
        if BAD.search(p["title"]):
            continue
        thumb = ii.get("thumburl", "").split("?")[0].replace("thumb.wikimedia.org", "upload.wikimedia.org")
        if not thumb or thumb in used:
            continue
        return {"title": p["title"], "url": thumb}
    return None

def resolve(queries):
    cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
    used = {v["url"] for v in cache.values() if v}
    for q in queries:
        if q in cache and cache[q]:
            continue
        hit = search(q, used)
        if hit:
            used.add(hit["url"])
        cache[q] = hit
        json.dump(cache, open(CACHE, "w"), ensure_ascii=False, indent=1)
        time.sleep(2)
    return cache
