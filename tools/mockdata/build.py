"""Run: python3 tools/mockdata/build.py

Writes the added mock content into SharedModels/Sources/FeedEngine/Data. Safe to re-run:
original Polaris articles, events and deals are kept; our additions are replaced."""
import json, os, re, sys, unicodedata

sys.path.insert(0, os.path.dirname(__file__))
import trondelag, other_regions, events_ads, digests, images

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../SharedModels/Sources/FeedEngine/Data")
ORIGINAL_ARTICLES = {"16grxK", "316lpP", "31EkrM", "aJy014", "BM0E00", "eG5bky", "eGz299", "JO8X9P", "OgnOdV", "zlxvg5"}
ORIGINAL_EVENTS = {"evt_quiz_lyche", "evt_smashburger_hammerhead", "evt_lis_visning", "evt_lopeklubben"}
ORIGINAL_ADS = {"ad_den_gode_nabo", "ad_te_og_kaffehuset", "ad_ox_tap_room", "ad_burger_no"}

DOMAINS = {
    "adressa": "adressa.no", "fosna-folket": "fosna-folket.no", "hitra-froya": "hitra-froya.no",
    "innherred": "innherred.no", "opdalingen": "opdalingen.no", "sor-trondelag": "avisa-st.no",
    "tronderbladet": "tronderbladet.no", "smp": "smp.no", "romsdals-budstikke": "rbnett.no", "driva": "driva.no",
    "more-nytt": "mn24.no", "vikebladet-vestposten": "vikebladet.no", "andalsnes-avis": "andalsnes-avis.no",
    "itromso": "itromso.no", "harstad-tidende": "ht.no", "folkebladet": "folkebladet.no", "fvn": "fvn.no",
    "agderposten": "agderposten.no", "lindesnes": "l-a.no", "lister": "lister24.no", "vennesla-tidende": "venneslatidende.no",
}

def load(name):
    return json.load(open(os.path.join(DATA, name)))

def save(name, value):
    with open(os.path.join(DATA, name), "w") as f:
        json.dump(value, f, ensure_ascii=False, indent=2)
        f.write("\n")

def slug(text):
    text = unicodedata.normalize("NFKD", text.lower().replace("æ", "ae").replace("ø", "o").replace("å", "a"))
    return re.sub(r"[^a-z0-9]+", "-", text.encode("ascii", "ignore").decode()).strip("-")[:60]

ARTICLES = trondelag.ARTICLES + other_regions.ARTICLES
cache = images.resolve([x["img"][2:] for x in ARTICLES + events_ads.EVENTS + events_ads.ADS if x["img"].startswith("q:")])

def image_id(img):
    """For articles: a Polaris id, or a full URL (the loader takes both)."""
    if img.startswith("polaris:"):
        return img.split(":", 1)[1]
    hit = cache[img[2:]]
    assert hit, f"no image for {img}"
    return hit["url"]

def image_url(img):
    value = image_id(img)
    return value if value.startswith("http") else f"https://vcdn.polarismedia.no/{value}?w=1000&fit=clip&q=80"

def location(lat, lon, name):
    return {"lat": lat, "lon": lon, "name": name}

paper_ids = {p["id"] for p in load("papers.json")}
category_ids = {c["id"] for c in load("categories.json")}

# Papers: add the real logo (the paper's own icon, via Google's favicon service).
papers = load("papers.json")
for paper in papers:
    paper["logoUrl"] = f"https://www.google.com/s2/favicons?domain={DOMAINS[paper['id']]}&sz=128"
save("papers.json", papers)

# Articles: a minimal Polaris export per article, plus our meta (place, category, summary, age).
metas = [m for m in load("article-meta.json") if m["id"] in ORIGINAL_ARTICLES]
for name in os.listdir(os.path.join(DATA, "articles")):
    if name[:-5] not in ORIGINAL_ARTICLES:
        os.remove(os.path.join(DATA, "articles", name))
for a in ARTICLES:
    assert a["paper"] in paper_ids and a["cat"] in category_ids, a["id"]
    components = []
    for line in a["body"]:
        if line.startswith("## "):
            components.append({"type": "subheading", "text": {"value": line[3:]}})
        else:
            components.append({"type": "text", "paragraphs": [{"text": {"value": line}}]})
    words = sum(len(line.split()) for line in [a["lead"]] + a["body"])
    raw = {
        "id": a["id"],
        "schemaType": "article",
        "title": {"value": a["title"]},
        "urls": {"canonical": f"https://www.{DOMAINS[a['paper']]}/{slug(a['section'])}/i/{a['id']}/{slug(a['title'])}"},
        "changes": {"published": "2026-10-17T08:00:00Z", "updated": None},
        "section": {"title": a["section"]},
        "newsroom": a["paper"],
        "authors": [{"fullname": a["author"]}],
        "tags": [{"title": t, "type": "tag"} for t in a["tags"]],
        "intro": {"lead": a["lead"]},
        "customProperties": {"frontPageImage": {"id": image_id(a["img"])}, "wordCount": words},
        "components": components,
    }
    with open(os.path.join(DATA, "articles", f"{a['id']}.json"), "w") as f:
        json.dump(raw, f, ensure_ascii=False, indent=1)
    metas.append({
        "id": a["id"], "categoryId": a["cat"], "paperId": a["paper"], "hoursAgo": a["hours"],
        "summary": a["summary"], "locations": [location(*l) for l in a["locs"]],
    })
save("article-meta.json", metas)

events = [e for e in load("events.json") if e["id"] in ORIGINAL_EVENTS]
for e in events_ads.EVENTS:
    assert e["paper"] in paper_ids and e["cat"] in category_ids, e["id"]
    events.append({
        "id": e["id"], "title": e["title"], "categoryId": e["cat"], "paperId": e["paper"],
        "location": location(*e["loc"]), "imageUrl": image_url(e["img"]), "dayOffset": e["day"],
        "startTime": e["start"], "endTime": e["end"], "venue": e["venue"], "price": e["price"],
        "description": e["desc"], "tags": e["tags"],
    })
save("events.json", events)

ads = [a for a in load("ads.json") if a["id"] in ORIGINAL_ADS]
for a in events_ads.ADS:
    assert a["paper"] in paper_ids and a["cat"] in category_ids, a["id"]
    ads.append({
        "id": a["id"], "title": a["title"], "categoryId": a["cat"], "paperId": a["paper"],
        "location": location(*a["loc"]), "imageUrl": image_url(a["img"]), "merchant": a["merchant"],
        "offer": a["offer"], "daysValid": a["days"], "description": a["desc"], "tags": a["tags"],
    })
save("ads.json", ads)

# Digests: ours, plus the original "Blålys" one.
article_images = {a["id"]: image_url(a["img"]) for a in ARTICLES}
original_digests = {d["id"]: d for d in load("digests.json")}
original_images = {
    "316lpP": "https://vcdn.polarismedia.no/1043df73-9a29-3c5a-9161-796561b10fc5?w=1200&fit=clip&q=80",
    "16grxK": original_digests["mat"]["imageUrl"],
    "JO8X9P": original_digests["helse"]["imageUrl"],
}
item_ids = {e["id"] for e in events} | {a["id"] for a in ads}
article_ids = {m["id"] for m in metas}
out = []
for d in digests.DIGESTS:
    for _, _, article in d["points"]:
        assert article is None or article in article_ids, (d["id"], article)
    for item in d["items"]:
        assert item in item_ids, (d["id"], item)
    digest = {
        "id": d["id"], "scope": d["scope"], "title": d["title"],
        **({"kicker": d["kicker"]} if "kicker" in d else {}),
        "headline": d["headline"], "intro": d["intro"],
        "points": [{"title": t, "text": x, **({"articleId": a} if a else {})} for t, x, a in d["points"]],
        "itemIds": d["items"],
        "imageUrl": original_images.get(d["image"]) or article_images[d["image"]],
        "symbol": d["symbol"], "color": d["color"],
        **({"categoryId": d["category"]} if "category" in d else {}),
        **({"regionId": d["region"]} if "region" in d else {}),
        "readMinutes": d["minutes"],
    }
    out.append(digest)
blalys = original_digests["blalys"]
out.insert(len([d for d in out if d["scope"] != "category"]) + 2, blalys)
save("digests.json", out)

print(f"{len(ARTICLES)} new articles ({sum(1 for a in ARTICLES if not a['locs'])} without place), "
      f"{len(events_ads.EVENTS)} new events, {len(events_ads.ADS)} new deals, {len(out)} digests, {len(papers)} papers with logos")
