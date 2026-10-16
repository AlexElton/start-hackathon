#!/usr/bin/env python3
"""Builds FeedEngine/Data/regions.geojson from robhop/fylker-og-kommuner (Kartverket, CC BY 4.0).

We use the 2020–2023 division (Viken, Vestfold og Telemark, Troms og Finnmark), which matches how
Polaris' papers are grouped.

Usage (needs shapely: `python3 -m venv .venv && .venv/bin/pip install shapely`):
  curl -L -o /tmp/fylker/Fylker-medium.json https://raw.githubusercontent.com/robhop/fylker-og-kommuner/main/2020/Fylker-medium.json
  .venv/bin/python -I tools/make_regions.py /tmp/fylker/Fylker-medium.json SharedModels/Sources/FeedEngine/Data/regions.geojson

Also writes norway.geojson next to it with two features: the whole country as one outline (the fylker
merged), which the onboarding map cuts out of a cover so everything outside Norway is hidden, and
"fylkesgrenser": only the borders where two selectable fylker meet (no coast, no national border).

Per fylke: repairs self-intersections (narrow fjords), simplifies to ~0.5 km while keeping the outline
valid (SwiftUI's MapPolygon does not fill invalid or very jagged rings), drops islands too small to see
or tap on a phone-sized map of Norway, and adds our properties: id, name, regionalPaperId, color and a
labelPoint inside the mainland part (the geometric centre of a Norwegian fylke often lands in the sea).
"""
import json
import sys

from itertools import combinations

from shapely.geometry import LineString, MultiLineString, MultiPolygon, Polygon, mapping, shape
from shapely.ops import linemerge, polylabel, unary_union
from shapely.validation import make_valid

# Regional paper per fylke, where our data has one. Local papers are linked through papers.json (regionId).
REGIONAL_PAPER = {
    "50": "adressa",  # Trøndelag – Adresseavisen
    "15": "smp",      # Møre og Romsdal – Sunnmørsposten
    "54": "itromso",  # Troms og Finnmark – iTromsø
    "42": "fvn",      # Agder – Fædrelandsvennen
}
# Fylker you can pick in onboarding: the ones where Polaris has a regional paper.
SELECTABLE = set(REGIONAL_PAPER)
# Shades of Adressablå. Neighbouring fylker always get different shades (greedy graph colouring).
SHADES = ["#005379", "#2E7FAD", "#5BA2CB", "#8CC0DE"]
# Hand-picked label points where the computed one would collide with a neighbour's label.
LABEL_OVERRIDES = {
    "50": (64.05, 11.65),  # Trøndelag: north of the computed point, clear of Møre og Romsdal
}
TOLERANCE = 0.003      # degrees, about 250 m: fills and borders line up
MIN_PART_AREA = 0.004  # deg² (lon × lat); smaller islands are dropped unless they are the only part
MAX_PARTS = 12         # per fylke, largest first


def slug(name):
    s = name.lower()
    for a, b in (("ø", "o"), ("å", "a"), ("æ", "ae"), (" ", "-")):
        s = s.replace(a, b)
    return s


def polygons_of(geometry):
    """Only the polygon parts of whatever make_valid returned."""
    if isinstance(geometry, Polygon):
        return [geometry]
    if hasattr(geometry, "geoms"):
        return [p for g in geometry.geoms for p in polygons_of(g)]
    return []


def rounded(polygon):
    """Coordinates rounded to ~10 m, or ~1 m where coarser rounding would make the ring cross itself."""
    for digits in (4, 5, 6):
        def ring(coords):
            return [[round(x, digits), round(y, digits)] for x, y in coords]
        rings = [ring(polygon.exterior.coords)] + [ring(i.coords) for i in polygon.interiors]
        if Polygon(rings[0], rings[1:]).is_valid:
            return rings
    raise ValueError("ring stays invalid after rounding")


def main(src, dst):
    features = []
    originals = {}  # full-detail outlines of the selectable fylker, for exact shared borders
    for f in json.load(open(src))["features"]:
        props = f["properties"]
        # 2020 files use "navn" and numeric fylkesnummer; 2024 files use "name" and strings.
        props = {"name": props.get("name") or props["navn"], "fylkesnummer": str(props["fylkesnummer"]).zfill(2)}
        geometry = make_valid(shape(f["geometry"]))
        if props["fylkesnummer"] in SELECTABLE:
            originals[props["fylkesnummer"]] = geometry
        geometry = make_valid(geometry.simplify(TOLERANCE, preserve_topology=True))
        parts = sorted(polygons_of(geometry), key=lambda p: p.area, reverse=True)
        kept = [p for i, p in enumerate(parts) if i == 0 or p.area >= MIN_PART_AREA][:MAX_PARTS]
        assert all(p.is_valid for p in kept), props["name"]
        number = props["fylkesnummer"]
        label = polylabel(kept[0], tolerance=0.001)
        if number in LABEL_OVERRIDES:
            lat, lon = LABEL_OVERRIDES[number]
            label = type(label)(lon, lat)
            assert kept[0].contains(label), "label override must be inside the fylke"
        paper = REGIONAL_PAPER.get(number)
        features.append({
            "type": "Feature",
            "properties": {
                "id": slug(props["name"]),
                "name": props["name"],
                "fylkesnummer": number,
                "regionalPaperId": paper,
                "selectable": number in SELECTABLE,
                "color": None,
                "labelPoint": {"lat": round(label.y, 4), "lon": round(label.x, 4)},
            },
            "geometry": {"type": "MultiPolygon", "coordinates": [rounded(p) for p in kept]},
        })
        points = sum(len(p.exterior.coords) for p in kept)
        print(f"{props['name']:16} parts {len(parts):3} -> {len(kept):2}  points {points:5}  label {label.y:.3f},{label.x:.3f}  paper {paper}")
    features.sort(key=lambda f: f["properties"]["fylkesnummer"])

    # Shade the selectable fylker so no two neighbours share a shade.
    selectable = [f for f in features if f["properties"]["selectable"]]
    shapes = {f["properties"]["id"]: shape(f["geometry"]).buffer(0.01) for f in selectable}
    for f in sorted(selectable, key=lambda f: -sum(shapes[f["properties"]["id"]].intersects(o) for o in shapes.values())):
        fid = f["properties"]["id"]
        taken = {g["properties"]["color"] for g in selectable if g["properties"]["color"] and shapes[fid].intersects(shapes[g["properties"]["id"]])}
        f["properties"]["color"] = next(c for c in SHADES if c not in taken)
    for f in features:
        print(f'  {f["properties"]["name"]:22} {f["properties"]["color"]}')

    with open(dst, "w") as out:
        json.dump({"type": "FeatureCollection", "features": features}, out, ensure_ascii=False, separators=(",", ":"))

    # Norway as one outline: merge every fylke (slightly grown so shared borders fuse without slivers).
    merged = unary_union([shape(f["geometry"]).buffer(0.002) for f in features]).buffer(-0.001)
    merged = make_valid(merged.simplify(TOLERANCE, preserve_topology=True))
    parts = sorted(polygons_of(merged), key=lambda p: p.area, reverse=True)
    parts = [Polygon(p.exterior) for i, p in enumerate(parts) if i == 0 or p.area >= MIN_PART_AREA]  # no lakes
    outline = {"type": "Feature", "properties": {"id": "norge", "name": "Norge"},
               "geometry": {"type": "MultiPolygon", "coordinates": [rounded(p) for p in parts]}}

    # Borders between selectable fylker only: where two outlines share an edge.
    lines = []
    for a, b in combinations(sorted(originals), 2):
        shared = originals[a].boundary.intersection(originals[b].boundary)
        pieces = [g for g in getattr(shared, "geoms", [shared]) if isinstance(g, (LineString, MultiLineString)) and not g.is_empty]
        joined = unary_union(pieces) if pieces else None
        if joined is not None and not joined.is_empty and joined.geom_type in ("LineString", "MultiLineString"):
            merged_line = linemerge(joined) if joined.geom_type == "MultiLineString" else joined
            for line in getattr(merged_line, "geoms", [merged_line]):
                line = line.simplify(TOLERANCE)
                if line.length > TOLERANCE:
                    lines.append([[round(x, 4), round(y, 4)] for x, y in line.coords])
    borders = {"type": "Feature", "properties": {"id": "fylkesgrenser", "name": "Fylkesgrenser"},
               "geometry": {"type": "MultiLineString", "coordinates": lines}}
    print(f"Fylkesgrenser: {len(lines)} lines, {sum(len(l) for l in lines)} points")

    outline_path = dst.rsplit("/", 1)[0] + "/norway.geojson"
    with open(outline_path, "w") as out:
        json.dump({"type": "FeatureCollection", "features": [outline, borders]}, out, separators=(",", ":"))
    print(f"Norge outline: {len(parts)} parts, {sum(len(p.exterior.coords) for p in parts)} points -> {outline_path}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
