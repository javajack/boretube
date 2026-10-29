#!/usr/bin/env python3
"""Curated Science tables for Classes 6 and 7 (NCERT Curiosity, CU6 / CU7).

Writes boretube-learn/app/src/main/assets/content/data/science.json, read by
learn-core ScienceGen.kt. Every row carries "src" (book and chapter). Run:

    python3 boretube-learn/tools/content/data/science_data.py

The output is stable (sorted keys, fixed row order). The script checks the
text rules (spec P2b §6) before writing, so a bad row fails here first.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "app", "src", "main", "assets", "content", "data", "science.json")
PICS = os.path.join(os.path.dirname(OUT), "pictures.json")

ERR = []


def words(s):
    return len([w for w in s.split() if any(ch.isalnum() for ch in w)])


def check_why(s, where):
    if not s:
        return
    if words(s) > 12:
        ERR.append(f"{where}: explanation over 12 words: {s}")
    if not s.endswith(".") or re.search(r"[.!?]\s", s):
        ERR.append(f"{where}: explanation must be one sentence ending in '.': {s}")


def cap(s):
    return s[:1].upper() + s[1:]


def article(x):
    return ("an " if x[:1].lower() in "aeio" else "a ") + x


# ---------------------------------------------------------------- tables

def C(id, label, sing, both="", which="", why=""):
    return {"id": id, "label": label, "sing": sing, "both": both, "which": which, "why": why}


def R(x, c, why="", np=None, also=(), skip=(), pic=""):
    return {"x": x, "c": c, "why": why, "np": np, "also": list(also), "skip": list(skip), "pic": pic}


TABLES = {}


def table(name, src, ask, classes, rows, art="a", card="{X}"):
    """art: 'a' = countable (a/an), '' = mass nouns (no article)."""
    ids = {c["id"] for c in classes}
    for c in classes:
        check_why(c["why"], f"{name}.{c['id']}")
        if len(c["label"]) > 24:
            ERR.append(f"{name}: label too long {c['label']}")
    seen = set()
    out = []
    for r in rows:
        if r["c"] not in ids:
            ERR.append(f"{name}: {r['x']} has unknown class {r['c']}")
        for a in r["also"] + r["skip"]:
            if a not in ids:
                ERR.append(f"{name}: {r['x']} also/skip unknown {a}")
        if len(r["x"]) > 24:
            ERR.append(f"{name}: option too long: {r['x']}")
        if r["x"].lower() in seen:
            ERR.append(f"{name}: repeat {r['x']}")
        seen.add(r["x"].lower())
        if r["np"] is None:
            r["np"] = article(r["x"]) if art == "a" else r["x"]
        check_why(r["why"], f"{name}.{r['x']}")
        r["src"] = src
        out.append({k: v for k, v in r.items() if v not in ("", [], None) or k in ("x", "c", "np")})
    TABLES[name] = {"ask": ask, "card": card, "classes": classes, "items": out, "src": src}


FACTS = {}
TFS = {}
ORDERS = {}
CHAINS = {}


def F(skill, t, q, a, w, why, src, pic=""):
    opts = [a] + list(w)
    if len({o.lower() for o in opts}) != len(opts):
        ERR.append(f"{skill}: options repeat: {q} {opts}")
    if len(w) < 2:
        ERR.append(f"{skill}: fact needs 2+ wrong options: {q}")
    for o in opts:
        if len(o) > 24:
            ERR.append(f"{skill}: option over 24: {o}")
    if len(q) > 140:
        ERR.append(f"{skill}: prompt over 140: {q}")
    check_why(why, f"{skill}: {q}")
    row = {"q": q, "a": a, "w": list(w), "why": why, "t": t, "src": src}
    if pic:
        row["pic"] = pic
    FACTS.setdefault(skill, []).append(row)


def T(skill, t, s, v, why, src, pic=""):
    if len(s) > 140:
        ERR.append(f"{skill}: statement over 140: {s}")
    check_why(why, f"{skill}: {s}")
    row = {"s": s, "v": v, "why": why, "t": t, "src": src}
    if pic:
        row["pic"] = pic
    TFS.setdefault(skill, []).append(row)


def O(skill, t, ask, items, why, src, mn=3, mx=5):
    if len(ask) > 90:
        ERR.append(f"{skill}: order prompt over 90: {ask}")
    for i in items:
        if len(i) > 28:
            ERR.append(f"{skill}: order item over 28: {i}")
    check_why(why, f"{skill}: {ask}")
    ORDERS.setdefault(skill, []).append({"ask": ask, "items": items, "why": why, "t": t, "min": mn, "max": mx, "src": src})


def CH(skill, **kw):
    for k in ("why", "cmpWhy"):
        if kw.get(k) and "{" not in kw[k]:
            check_why(kw[k], f"{skill} chain {k}")
    CHAINS.setdefault(skill, []).append(kw)


# ================================================================ CLASS 6

# ---- sc6.plantTypes (CU6 ch2 Diversity in the Living World)
S = "CU6 ch2"
table("habitUp", S, "{X}: is it a herb, a shrub or a tree?", [
    C("herb", "herb", "is a herb", "are both herbs", "Which is a herb", "A herb has a soft, green and short stem."),
    C("shrub", "shrub", "is a shrub", "are both shrubs", "Which is a shrub", "A shrub has hard, woody stems branching near the ground."),
    C("tree", "tree", "is a tree", "are both trees", "Which is a tree", "A tree is tall with one thick, woody trunk."),
], [R(x, "herb") for x in ["wheat", "paddy", "maize", "grass", "mint", "coriander", "spinach", "mustard", "radish", "methi", "onion", "garlic", "gram", "marigold"]]
 + [R(x, "shrub", pic=p) for x, p in [("rose", "rose"), ("hibiscus", ""), ("henna", ""), ("cotton", ""), ("tea", ""), ("oleander", ""), ("lantana", ""), ("ixora", "")]]
 + [R(x, "tree", pic=p) for x, p in [("mango", "mango"), ("neem", "neem"), ("banyan", "banyan"), ("peepal", ""), ("coconut", "palm"), ("teak", ""), ("jamun", ""), ("tamarind", ""), ("guava", ""), ("jackfruit", ""), ("gulmohar", ""), ("eucalyptus", ""), ("sal", ""), ("date palm", "palm"), ("deodar", ""), ("pine", "pine")]],
 art="")
table("habitWeak", S, "{X} has a weak stem: is it a climber or a creeper?", [
    C("climber", "climber", "is a climber", "are both climbers", "Which is a climber", "A climber's weak stem climbs up a support."),
    C("creeper", "creeper", "is a creeper", "are both creepers", "Which is a creeper", "A creeper's weak stem spreads along the ground."),
], [R("money plant", "climber", pic="moneyplant"), R("pea plant", "climber", pic="peas"), R("grapevine", "climber", pic="grapes"),
    R("bitter gourd", "climber"), R("betel vine", "climber"),
    R("pumpkin", "creeper", pic="pumpkin"), R("watermelon", "creeper", pic="watermelon"), R("sweet potato", "creeper"),
    R("strawberry", "creeper", pic="strawberry"), R("muskmelon", "creeper")], art="")
table("veins", S, "{X} leaves: parallel or reticulate veins?", [
    C("par", "parallel", "has parallel leaf veins", "both have parallel leaf veins", "Which has parallel leaf veins", "Parallel veins run side by side along the leaf."),
    C("ret", "reticulate", "has reticulate leaf veins", "both have reticulate leaf veins", "Which has net-like leaf veins", "Reticulate veins make a net on both sides of the midrib."),
], [R(x, "par") for x in ["wheat", "paddy", "maize", "grass", "onion", "garlic", "banana", "coconut", "sugarcane", "bamboo", "lily", "date palm"]]
 + [R(x, "ret") for x in ["mango", "neem", "guava", "hibiscus", "rose", "mustard", "spinach", "coriander", "radish", "tulsi", "pea plant", "sunflower", "gram", "peepal", "banyan", "jamun", "tomato", "potato"]],
 art="", card="{X} leaf")
table("roots", S, "{X}: taproot or fibrous roots?", [
    C("tap", "taproot", "has a taproot", "both have taproots", "Which has a taproot", "A taproot is one main root with smaller side roots."),
    C("fib", "fibrous roots", "has fibrous roots", "both have fibrous roots", "Which has fibrous roots", "Fibrous roots are many thin roots of similar size."),
], [R(x, "tap") for x in ["mango", "neem", "guava", "hibiscus", "rose", "mustard", "radish", "carrot", "coriander", "spinach", "pea plant", "gram", "sunflower", "tulsi", "tomato"]]
 + [R(x, "fib") for x in ["wheat", "paddy", "maize", "grass", "onion", "garlic", "banana", "coconut", "sugarcane", "bamboo"]],
 art="", card="{X} roots")
for q, a, w, why in [
    ("Which part joins a leaf to the stem?", "petiole", ["lamina", "midrib", "vein"], "The petiole is the stalk that joins the leaf to the stem."),
    ("The flat, green part of a leaf is the ___.", "lamina", ["petiole", "midrib", "root"], "The lamina is the broad, flat part of a leaf."),
    ("The thick vein down the middle of a leaf is the ___.", "midrib", ["petiole", "lamina", "stem"], "The midrib runs down the centre and branches into veins."),
    ("A seed with one cotyledon belongs to a ___.", "monocot", ["dicot", "fern", "fungus"], "Mono means one, so a monocot seed has one cotyledon."),
    ("A seed with two cotyledons belongs to a ___.", "dicot", ["monocot", "fern", "moss"], "Di means two, so a dicot seed has two cotyledons."),
    ("Which plants have weak stems that spread on the ground?", "creepers", ["climbers", "trees", "shrubs"], "Creepers cannot stand up, so they spread on the ground."),
    ("Which plants climb using tendrils or a support?", "climbers", ["creepers", "herbs", "trees"], "Climbers have weak stems that hold on to supports."),
]:
    F("sc6.plantTypes", 1, q, a, w, why, S)
F("sc6.plantTypes", 2, "Wheat seeds have one cotyledon. What leaf veins does wheat have?", "parallel", ["reticulate", "no veins"], "Monocots like wheat usually have parallel leaf veins.", S)
F("sc6.plantTypes", 2, "Gram seeds have two cotyledons. What roots does gram have?", "taproot", ["fibrous roots", "no roots"], "Dicots like gram usually have a taproot.", S)
F("sc6.plantTypes", 3, "A plant has fibrous roots. Its seed most likely has how many cotyledons?", "one", ["two", "none"], "Fibrous roots usually go with monocots, which have one cotyledon.", S)
F("sc6.plantTypes", 3, "A plant has a taproot. Its seed most likely has how many cotyledons?", "two", ["one", "none"], "A taproot usually goes with dicots, which have two cotyledons.", S)

# ---- sc6.nutrients (CU6 ch3 Mindful Eating)
S = "CU6 ch3"
table("nutrients", S, "{X} is rich in which nutrient?", [
    C("carb", "carbohydrates", "is rich in carbohydrates", "are both rich in carbohydrates", "Which is rich in carbohydrates", "Carbohydrates give us energy; grains and potatoes are rich in them."),
    C("prot", "proteins", "is rich in proteins", "are both rich in proteins", "Which is rich in proteins", "Proteins help the body grow and repair itself."),
    C("fat", "fats", "is rich in fats", "are both rich in fats", "Which is rich in fats", "Fats give us a lot of energy."),
    C("vitc", "vitamin C", "is rich in vitamin C", "are both rich in vitamin C", "Which is rich in vitamin C", "Vitamin C keeps gums healthy and helps fight illness."),
], [
    R("rice", "carb", pic="rice"), R("wheat", "carb", skip=["prot"]), R("maize", "carb", pic="corn"), R("potato", "carb", skip=["vitc"], pic="potato"),
    R("sugar", "carb", "Sugar is almost pure carbohydrate."), R("bread", "carb", skip=["prot"], pic="bread"), R("jaggery", "carb", pic="jaggery"),
    R("sweet potato", "carb", skip=["vitc"]), R("poha", "carb", pic="poha"), R("sabudana", "carb", "Sabudana is almost pure starch, a carbohydrate."),
    R("dal", "prot", "Pulses like dal are a rich source of proteins.", skip=["carb"], pic="dal"), R("soybean", "prot", skip=["carb", "fat"]),
    R("gram", "prot", skip=["carb"]), R("egg", "prot", skip=["fat"], pic="egg"), R("fish", "prot", skip=["fat"], pic="fish"),
    R("chicken", "prot", skip=["fat"]), R("rajma", "prot", skip=["carb"]), R("paneer", "prot", skip=["fat"], pic="paneer"),
    R("moong sprouts", "prot", skip=["carb"], np="sprouted moong"),
    R("ghee", "fat", "Ghee is almost all fat.", pic="ghee"), R("butter", "fat"), R("mustard oil", "fat", "Cooking oils are almost pure fat."),
    R("coconut oil", "fat", "Cooking oils are almost pure fat."), R("cream", "fat"), R("groundnut", "fat", skip=["prot"]),
    R("amla", "vitc", "Amla is one of the richest sources of vitamin C."), R("orange", "vitc", pic="orange"), R("lemon", "vitc", pic="lemon"),
    R("guava", "vitc", pic="guava"), R("sweet lime", "vitc"),
], art="")
table("starchTest", S, "A drop of iodine on {np}: what do you see?", [
    C("yes", "blue-black", "turns blue-black with iodine", "both turn blue-black with iodine", "Which turns blue-black with iodine", "Iodine turns blue-black when starch is present."),
    C("no", "no blue-black", "does not turn blue-black with iodine", "", "", "Without starch, iodine does not turn blue-black."),
], [R(x, "yes", pic=p) for x, p in [("potato", "potato"), ("cooked rice", "rice"), ("bread", "bread"), ("wheat flour", ""), ("sabudana", ""), ("cornflour", ""), ("poha", "poha")]]
 + [R(x, "no", pic=p) for x, p in [("ghee", "ghee"), ("sugar", ""), ("coconut oil", ""), ("egg white", "egg"), ("lemon juice", "lemon"), ("butter", ""), ("milk", "milk"), ("jaggery", "jaggery"), ("paneer", "paneer")]],
 art="")
table("fatTest", S, "{X} is rubbed on paper: what do you see?", [
    C("yes", "oily patch", "leaves an oily patch on paper", "both leave an oily patch on paper", "Which leaves an oily patch on paper", "Fats leave a see-through oily patch on paper."),
    C("no", "no oily patch", "leaves no oily patch on paper", "", "", "Foods without fat leave no oily patch once dry."),
], [R(x, "yes") for x in ["ghee", "butter", "crushed groundnut", "coconut oil", "cream", "mustard oil"]]
 + [R(x, "no") for x in ["sugar", "raw potato", "lemon juice", "jaggery", "egg white", "sabudana"]], art="")
table("proteinTest", S, "{X} with copper sulphate and caustic soda: what colour?", [
    C("yes", "violet", "turns violet in the protein test", "both turn violet in the protein test", "Which turns violet in the protein test", "Protein turns violet with copper sulphate and caustic soda."),
    C("no", "no violet", "does not turn violet in the protein test", "", "", "Without protein there is no violet colour in this test."),
], [R(x, "yes") for x in ["egg white", "dal paste", "paneer", "milk", "soybean paste", "besan"]]
 + [R(x, "no") for x in ["sugar", "ghee", "coconut oil", "lemon juice", "sabudana", "jaggery"]], art="")
DEF = [
    ("scurvy", "vitamin C", "bleeding gums", ["amla", "orange", "lemon", "guava"], ["rice", "sugar", "ghee", "bread"], "Vitamin C keeps gums healthy and prevents scurvy."),
    ("rickets", "vitamin D", "soft, bent bones", ["sunlight", "fish", "eggs"], ["sugar", "rice", "lemon", "amla"], "Vitamin D, made with sunlight, keeps bones strong."),
    ("night blindness", "vitamin A", "poor sight in dim light", ["carrot", "papaya", "ripe mango"], ["sugar", "rice", "lemon", "bread"], "Vitamin A keeps eyes healthy, especially in dim light."),
    ("beriberi", "vitamin B1", "weak muscles, low energy", [], [], "Lack of vitamin B1 makes muscles weak and tired."),
    ("goitre", "iodine", "a swollen neck", ["iodised salt"], ["sugar", "ghee", "rice"], "Iodine keeps the thyroid gland in the neck healthy."),
    ("anaemia", "iron", "weakness and pale skin", ["spinach", "jaggery"], ["sugar", "ghee", "butter"], "Iron is needed to make healthy blood."),
]
SK = "sc6.nutrients"
nutr = [d[1] for d in DEF]
dis = [d[0] for d in DEF]
for d, n, sym, good, bad, why in DEF:
    F(SK, 1, f"{cap(d)} is caused by a lack of ___.", n, [x for x in nutr if x != n][:3], why, S)
    F(SK, 1, f"Lack of {n} causes ___.", d, [x for x in dis if x != d][:3], why, S)
    F(SK, 2, f"{cap(sym)} can be a sign of ___.", d, [x for x in dis if x != d][-3:], why, S)
    F(SK, 2, f"A child has {sym}. Which nutrient may be lacking?", n, [x for x in nutr if x != n][-3:], why, S)
    for g in good:
        F(SK, 3, f"To prevent {d}, which should a child get more of?", g, bad[:3], why, S)
        F(SK, 3, f"A child has {sym}. Which would help most?", g, bad[-3:], why, S)
        T(SK, 3, ("Getting sunlight" if g == "sunlight" else f"Eating {g}") + f" helps prevent {d}.", True, why, S)
    for b in bad:
        T(SK, 3, f"Eating {b} helps prevent {d}.", False, why, S)
    for n2 in nutr:
        T(SK, 2, f"Lack of {n2} causes {d}.", n2 == n, why, S)
for q, a, w, why in [
    ("Iodine solution turns starch ___.", "blue-black", ["green", "violet", "yellow"], "Iodine turns blue-black when starch is present."),
    ("Which test shows fat in a food?", "oily patch on paper", ["iodine turns blue-black", "turns violet"], "Fats leave a see-through oily patch on paper."),
    ("Which test shows starch in a food?", "iodine turns blue-black", ["oily patch on paper", "turns violet"], "Iodine turns blue-black when starch is present."),
    ("Which test shows protein in a food?", "turns violet", ["iodine turns blue-black", "oily patch on paper"], "Copper sulphate and caustic soda turn protein violet."),
    ("Roughage (dietary fibre) mainly helps us ___.", "pass out waste", ["see in dim light", "build muscles fast", "stop bleeding"], "Fibre helps food and waste move smoothly through the gut."),
    ("A diet with all nutrients in the right amounts is a ___.", "balanced diet", ["junk diet", "fast", "snack"], "A balanced diet has every nutrient in the right amounts."),
    ("Which nutrient gives us energy the fastest?", "carbohydrates", ["vitamins", "minerals", "roughage"], "Carbohydrates are the body's quick source of energy."),
    ("Which nutrient helps build and repair the body?", "proteins", ["fats", "roughage", "water"], "Proteins help the body grow and repair itself."),
]:
    F(SK, 1, q, a, w, why, S)

# ---- sc6.magnets (CU6 ch4 Exploring Magnets)
S = "CU6 ch4"
SK = "sc6.magnets"
IRON = "It is made of iron, so a magnet attracts it."
STEEL = "It is made of steel, which a magnet attracts."
table("magnetic", S, "Is {np} magnetic or non-magnetic?", [
    C("mag", "magnetic", "is attracted by a magnet", "are both attracted by a magnet", "Which does a magnet attract", "Magnets attract things made of iron, nickel or cobalt."),
    C("non", "non-magnetic", "is not attracted by a magnet", "", "", "Magnets do not attract plastic, wood, glass, paper or most metals."),
], [
    R("iron nail", "mag", IRON), R("iron filings", "mag", "Iron filings are tiny bits of iron.", np="a pinch of iron filings"), R("iron screw", "mag", IRON),
    R("safety pin", "mag", STEEL), R("paper clip", "mag", STEEL), R("sewing needle", "mag", STEEL, pic="needle"),
    R("iron bolt", "mag", IRON), R("iron tawa", "mag", IRON, pic="tawa"), R("nickel", "mag", "Nickel is one of the few magnetic metals.", np="a piece of nickel"),
    R("cobalt", "mag", "Cobalt is one of the few magnetic metals.", np="a piece of cobalt"), R("iron ball", "mag", IRON), R("iron rod", "mag", IRON),
    R("razor blade", "mag", STEEL), R("iron chain", "mag", IRON), R("steel wool", "mag", STEEL, np="steel wool"),
    R("plastic comb", "non", pic="comb"), R("rubber eraser", "non", np="an eraser made of rubber", pic="eraser"), R("wooden ruler", "non", pic="ruler"),
    R("glass marble", "non"), R("sheet of paper", "non"), R("cotton cloth", "non", np="cotton cloth"),
    R("aluminium foil", "non", "Aluminium is a metal, but magnets do not attract it.", np="aluminium foil"),
    R("copper wire", "non", "Copper is a metal, but magnets do not attract it.", pic="wire"),
    R("brass diya", "non", "Brass is a metal mix that magnets do not attract.", pic="diya"),
    R("gold ring", "non", "Gold is a metal, but magnets do not attract it."),
    R("silver spoon", "non", "Silver is a metal, but magnets do not attract it."),
    R("piece of chalk", "non"), R("candle", "non", pic="candle"), R("plastic bottle", "non", pic="bottle"), R("rubber band", "non"),
    R("feather", "non"), R("clay pot", "non"), R("cork", "non"), R("sponge", "non"),
    R("aluminium can", "non", "Aluminium is a metal, but magnets do not attract it."), R("coconut shell", "non"),
], art="a", card="{X}")
for q, a, w, why in [
    ("Like poles of two magnets ___ each other.", "repel", ["attract", "do nothing to"], "Like poles repel and unlike poles attract."),
    ("Unlike poles of two magnets ___ each other.", "attract", ["repel", "do nothing to"], "Like poles repel and unlike poles attract."),
    ("A freely hanging bar magnet comes to rest pointing ___.", "north–south", ["east–west", "up–down"], "A free magnet always settles along the north–south line."),
    ("Where is a bar magnet's pull strongest?", "at its two ends", ["in its middle", "the same all over"], "A magnet's pull is strongest at its poles, near the ends."),
    ("The end of a magnet that points north is its ___.", "north pole", ["south pole", "middle"], "The north-seeking end is called the north pole."),
    ("A compass needle is a small ___.", "magnet", ["mirror", "thermometer", "lens"], "A compass needle is a tiny magnet that points north–south."),
    ("A natural rock that attracts iron is ___.", "magnetite", ["marble", "chalk", "granite"], "Magnetite, or lodestone, is a natural magnet."),
    ("A bar magnet is broken in two. Each piece has ___.", "two poles", ["one pole", "no poles"], "Every magnet, however small, has a north and a south pole."),
    ("Which surely shows that an object is a magnet?", "it repels a magnet", ["it attracts iron", "it is shiny"], "Only another magnet can repel a magnet's pole."),
    ("Magnets lose their magnetism if they are ___.", "heated or hammered", ["kept in pairs", "wrapped in cloth"], "Heating, hammering or dropping a magnet weakens it."),
    ("Bar magnets are best stored ___.", "in unlike-pole pairs", ["with like poles together", "near a hot stove"], "Unlike poles together, with keepers, keep magnets strong."),
    ("Which instrument helps sailors find direction?", "compass", ["thermometer", "beaker", "prism"], "A compass needle always points north–south."),
]:
    F(SK, 1, q, a, w, why, S, pic="magnet" if "magnet" in q else "")
F(SK, 1, "Which instrument is this, used to find north?", "compass", ["thermometer", "prism", "magnifier"], "A compass has a magnetic needle that points north.", S, pic="compass")
for p1 in ("north", "south"):
    for p2 in ("north", "south"):
        a = "repel" if p1 == p2 else "attract"
        F(SK, 2, f"The {p1} pole of one magnet faces the {p2} pole of another. They will ___.", a,
          ["attract" if a == "repel" else "repel", "do nothing"], "Like poles repel and unlike poles attract.", S)
        T(SK, 2, f"A {p1} pole and a {p2} pole attract each other.", p1 != p2, "Like poles repel and unlike poles attract.", S)
for act in ("pulls", "pushes away"):
    for cp in ("north", "south"):
        other = "south" if cp == "north" else "north"
        ans = other if act == "pulls" else cp
        F(SK, 3, f"End P of a bar magnet {act} the {cp} pole of a compass needle. End P is a ___ pole.", ans,
          [other if ans == cp else cp, "middle"], "Unlike poles attract and like poles repel.", S)
F(SK, 3, "An iron bar attracts both ends of a compass needle. Is the bar a magnet?", "no, just magnetic", ["yes, a magnet", "it has no iron"],
  "A magnet would push one end of the needle away.", S)
F(SK, 3, "A bar pushes away one end of a compass needle. The bar is ___.", "a magnet", ["plain iron", "plastic"],
  "Only a magnet can repel a magnet's pole.", S)

# ---- sc6.length (CU6 ch5 Measurement of Length and Motion)
S = "CU6 ch5"
SK = "sc6.length"
for q, a, w, why in [
    ("The SI unit of length is the ___.", "metre", ["kilogram", "second", "litre"], "Length is measured in metres in the SI system."),
    ("1 kilometre is ___ metres.", "1000", ["100", "10", "10,000"], "Kilo means a thousand, so 1 km = 1000 m."),
    ("1 metre is ___ centimetres.", "100", ["10", "1000", "60"], "Centi means a hundredth, so 1 m = 100 cm."),
    ("1 centimetre is ___ millimetres.", "10", ["100", "1000", "5"], "There are 10 mm in 1 cm."),
    ("Why are handspans not a good unit?", "they differ by person", ["they are too long", "they are too short"], "Different people have different handspans, so results differ."),
    ("To measure a curved line, use a ___.", "thread", ["ruler only", "thermometer", "magnet"], "A thread follows the curve, then you measure it straight."),
    ("While reading a ruler, your eye should be ___.", "right above the mark", ["to the left side", "to the right side"], "Looking straight down at the mark avoids a wrong reading."),
    ("A ruler's zero mark is broken. What can you do?", "start from another mark", ["measure with a coin", "guess the length"], "Start at a full mark and subtract it from the end reading."),
]:
    F(SK, 1, q, a, w, why, S, pic="ruler" if "ruler" in q else "")
for thing, unit in [("the length of a room", "m"), ("the distance between two cities", "km"), ("the length of a pencil", "cm"),
                    ("the thickness of a coin", "mm"), ("the height of a tree", "m"), ("the length of a river", "km"),
                    ("the width of a notebook", "cm"), ("the length of an ant", "mm"), ("the length of a saree", "m"),
                    ("the length of an eraser", "cm"), ("the length of a cricket pitch", "m"), ("a train journey from Delhi to Agra", "km"),
                    ("the thickness of a book's cover", "mm"), ("the length of your finger", "cm"), ("the height of a door", "m")]:
    others = {"mm": ["km", "m", "cm"], "cm": ["km", "m"], "m": ["km", "mm"], "km": ["mm", "cm"]}[unit]
    F(SK, 1, f"Which unit suits {thing} best?", unit, others, {
        "mm": "Very small lengths are easiest in millimetres.", "cm": "Small things like pencils are measured in centimetres.",
        "m": "Rooms, trees and sarees are measured in metres.", "km": "Long distances between places are measured in kilometres."}[unit], S)

# ---- sc6.motion (CU6 ch5)
SK = "sc6.motion"
table("motion", S, "{Np}: what type of motion is this?", [
    C("lin", "linear", "shows linear motion", "both show linear motion", "Which shows linear motion", "Linear motion is movement along a straight line."),
    C("cir", "circular", "shows circular motion", "both show circular motion", "Which shows circular motion", "Circular motion is movement along a circle."),
    C("osc", "oscillatory", "shows oscillatory motion", "both show oscillatory motion", "Which shows oscillatory motion", "Oscillatory motion is moving to and fro about one point."),
], [
    R("train on straight track", "lin", np="a train on a straight track", pic="train"), R("car on a straight road", "lin", pic="car"),
    R("falling apple", "lin", pic="apple"), R("stone dropped from roof", "lin", np="a stone dropped from a roof", pic="stone"),
    R("sprinter in 100 m race", "lin", np="a sprinter in a 100 m race"), R("lift going up", "lin"),
    R("drawer being pulled out", "lin", np="a drawer being pulled out"), R("child on straight slide", "lin", np="a child on a straight slide"),
    R("raindrop falling down", "lin", np="a raindrop falling straight down", pic="drop"), R("box pushed on the floor", "lin", np="a box pushed along the floor", pic="box"),
    R("coconut falling down", "lin", np="a coconut falling from a tree", pic="coconut"),
    R("ceiling fan blades", "cir", np="a blade of a spinning ceiling fan"), R("child on merry-go-round", "cir", np="a child on a merry-go-round"),
    R("tip of a clock hand", "cir", np="the tip of a clock's minute hand", pic="clock"), R("stone whirled on string", "cir", np="a stone whirled on a string"),
    R("giant wheel seat", "cir", np="a seat on a moving giant wheel"), R("spinning potter's wheel", "cir", np="a spinning potter's wheel"),
    R("windmill blades", "cir", np="a blade of a turning windmill"), R("toy train on round track", "cir", np="a toy train on a round track"),
    R("cyclist on round track", "cir", np="a cyclist on a circular track", pic="bicycle"),
    R("child on a swing", "osc"), R("clock pendulum", "osc", np="the pendulum of a clock"),
    R("sewing machine needle", "osc", np="the needle of a sewing machine", pic="needle"), R("plucked guitar string", "osc", np="a plucked guitar string", pic="guitar"),
    R("moving see-saw", "osc", np="a moving see-saw"), R("cradle being rocked", "osc", np="a cradle being rocked"),
    R("rocking chair", "osc", np="a rocking chair in use"), R("struck tuning fork", "osc", np="a prong of a struck tuning fork"),
    R("plucked sitar string", "osc", np="a plucked sitar string"), R("weight on a spring", "osc", np="a weight bobbing on a spring"),
])
for q, a, w, why in [
    ("An object is in motion if its position changes with ___.", "time", ["colour", "weight", "smell"], "Motion means a change of position over time."),
    ("Movement along a straight line is ___ motion.", "linear", ["circular", "oscillatory"], "Linear motion is movement along a straight line."),
    ("Movement along a circle is ___ motion.", "circular", ["linear", "oscillatory"], "Circular motion is movement along a circle."),
    ("Moving to and fro about a fixed point is ___ motion.", "oscillatory", ["linear", "circular"], "Oscillatory motion is moving to and fro about one point."),
]:
    F(SK, 1, q, a, w, why, S)

# ---- sc6.materials (CU6 ch6 Materials Around Us)
S = "CU6 ch6"
SK = "sc6.materials"
table("lustre", S, "Is {np} lustrous or non-lustrous?", [
    C("lus", "lustrous", "is lustrous (shiny)", "are both lustrous", "Which is lustrous (shiny)", "Metals like gold and copper have a shine called lustre."),
    C("dull", "non-lustrous", "is non-lustrous (dull)", "", "", "Wood, paper and chalk have no natural shine."),
], [R(x, "lus") for x in ["gold", "silver", "copper", "aluminium", "brass", "steel"]]
 + [R(x, "dull") for x in ["wood", "paper", "chalk", "cardboard", "clay", "cotton", "rubber", "jute", "brick", "wool"]], art="")
table("dissolve", S, "{X} stirred in water: soluble or insoluble?", [
    C("sol", "soluble", "dissolves in water", "both dissolve in water", "Which dissolves in water", "A soluble solid mixes fully into water and disappears from view."),
    C("ins", "insoluble", "does not dissolve in water", "", "", "Insoluble solids stay as bits or settle in water."),
], [R(x, "sol") for x in ["salt", "sugar", "alum", "baking soda", "copper sulphate", "glucose", "jaggery", "washing soda"]]
 + [R(x, "ins") for x in ["sand", "chalk powder", "sawdust", "candle wax", "coal powder"]]
 + [R(x, "ins", np=n) for x, n in [("iron filings", "a pinch of iron filings"), ("pebbles", "a pebble"), ("mustard seeds", "a mustard seed"), ("plastic beads", "a plastic bead")]], art="")
table("mixes", S, "{X} poured into water: does it mix?", [
    C("mix", "mixes with water", "mixes fully with water", "both mix fully with water", "Which mixes fully with water", "Some liquids mix evenly with water and form no layer."),
    C("no", "does not mix", "does not mix with water", "", "", "Oils do not mix with water; they form a separate layer."),
], [R(x, "mix") for x in ["vinegar", "lemon juice", "milk", "honey", "rose water", "orange juice", "sugar syrup"]]
 + [R(x, "no") for x in ["coconut oil", "mustard oil", "kerosene", "melted ghee", "castor oil", "groundnut oil"]], art="")
table("floats", S, "{Np} is put in water. Does it float or sink?", [
    C("fl", "floats", "floats on water", "both float on water", "Which floats on water", "Things lighter than the same amount of water float."),
    C("sk", "sinks", "sinks in water", "both sink in water", "Which sinks in water", "Things heavier than the same amount of water sink."),
], [R("dry leaf", "fl", pic="leaf"), R("cork", "fl"), R("feather", "fl"), R("ice cube", "fl", "Ice is lighter than the same amount of water."),
    R("thermocol piece", "fl"), R("wooden block", "fl"), R("sealed empty bottle", "fl", pic="bottle"), R("paper boat", "fl", pic="boat"),
    R("dry coconut", "fl", pic="coconut"), R("drop of oil", "fl", "Oil is lighter than water, so it floats on top."), R("table tennis ball", "fl"),
    R("stone", "sk", pic="stone"), R("iron nail", "sk"), R("coin", "sk"), R("glass marble", "sk"), R("key", "sk", pic="key"),
    R("steel spoon", "sk", pic="spoon"), R("brick", "sk"), R("clay ball", "sk"), R("fresh egg", "sk", pic="egg"), R("potato", "sk", pic="potato")])
table("seeThrough", S, "Is {np} transparent, translucent or opaque?", [
    C("tr", "transparent", "is transparent", "are both transparent", "Which is transparent", "Transparent things let almost all light through, so we see clearly."),
    C("tl", "translucent", "is translucent", "are both translucent", "Which is translucent", "Translucent things let some light through; things look blurred."),
    C("op", "opaque", "is opaque", "are both opaque", "Which is opaque", "Opaque things let no light pass through them."),
], [R("clear glass sheet", "tr", pic="window"), R("clean water", "tr", np="clean water"), R("air", "tr", np="air"), R("clear plastic sheet", "tr"),
    R("spectacle lens", "tr", pic="glasses"),
    R("butter paper", "tl", np="butter paper"), R("oiled paper", "tl", np="oiled paper"), R("frosted glass", "tl", np="frosted glass"),
    R("tracing paper", "tl", np="tracing paper"), R("tissue paper", "tl", np="tissue paper"), R("wax paper", "tl", np="wax paper"),
    R("wooden board", "op"), R("cardboard", "op", np="cardboard"), R("book", "op", pic="book"), R("stone", "op", pic="stone"),
    R("steel plate", "op", pic="plate"), R("brick", "op"), R("aluminium foil", "op", np="aluminium foil"), R("thick blanket", "op"), R("clay pot", "op", pic="pot")])
for q, a, w, why in [
    ("Things that let us see clearly through them are ___.", "transparent", ["translucent", "opaque"], "Transparent things let almost all light through."),
    ("A shiny look that metals have is called ___.", "lustre", ["shadow", "rust", "texture"], "Metals like gold and copper have a shine called lustre."),
    ("Salt disappears when stirred in water. Salt is ___.", "soluble", ["insoluble", "magnetic"], "Salt dissolves fully, so it is soluble in water."),
    ("Oil and water poured together form ___.", "two layers", ["one even mix", "a solid"], "Oil does not mix with water and floats as a layer."),
    ("Why are cooking pots often made of metal?", "metals pass heat well", ["metals are soft", "metals float"], "Metals let heat through quickly to cook food."),
    ("Why is a window pane made of glass?", "glass is transparent", ["glass is opaque", "glass is soft"], "Transparent glass lets light in and lets us see out."),
]:
    F(SK, 1, q, a, w, why, S)

# ---- sc6.temperature (CU6 ch7 Temperature and its Measurement)
S = "CU6 ch7"
SK = "sc6.temperature"
for q, a, w, why in [
    ("Normal human body temperature is about ___.", "37 °C", ["27 °C", "47 °C", "100 °C"], "A healthy body stays at about 37 °C."),
    ("A clinical thermometer usually reads from ___.", "35 °C to 42 °C", ["−10 °C to 110 °C", "0 °C to 100 °C"], "Body temperature stays within about 35 °C to 42 °C."),
    ("A laboratory thermometer usually reads from ___.", "−10 °C to 110 °C", ["35 °C to 42 °C", "0 °C to 50 °C"], "Lab thermometers cover a wide range, about −10 °C to 110 °C."),
    ("Which is used to check a person for fever?", "clinical thermometer", ["laboratory thermometer", "ruler", "compass"], "A clinical thermometer is made for body temperature."),
    ("Why does a clinical thermometer have a kink?", "keeps the reading fixed", ["makes mercury boil", "lets it bend"], "The kink stops the liquid falling back before you read it."),
    ("Why are mercury thermometers being replaced?", "mercury is poisonous", ["mercury is too cheap", "mercury is too light"], "Mercury is toxic, so digital thermometers are safer."),
    ("Pure water freezes at ___.", "0 °C", ["10 °C", "37 °C", "100 °C"], "Pure water turns to ice at 0 °C."),
    ("Pure water boils at ___ at sea level.", "100 °C", ["37 °C", "50 °C", "0 °C"], "At sea level, pure water boils at 100 °C."),
    ("In °C, the C stands for ___.", "Celsius", ["Calorie", "Centimetre", "Cold"], "°C means degree Celsius, the unit we use for temperature."),
    ("Why can't a clinical thermometer test boiling water?", "its scale ends at 42 °C", ["it is too long", "it has no bulb"], "Its scale stops at 42 °C, so hot water can break it."),
    ("Where should a lab thermometer's bulb be while reading?", "inside the liquid", ["above the liquid", "touching the beaker"], "The bulb must stay in the liquid, not touching the sides."),
    ("Temperature tells us ___.", "how hot or cold", ["how heavy", "how long", "how loud"], "Temperature measures hotness or coldness."),
    ("A clinical thermometer is read after about ___.", "one minute", ["one second", "one hour"], "The liquid needs about a minute to settle at body temperature."),
]:
    F(SK, 1, q, a, w, why, S, pic="thermometer")
for s, v, why in [
    ("You should hold a thermometer by its bulb while reading.", False, "Holding the bulb adds your hand's warmth to the reading."),
    ("A digital thermometer shows the temperature as numbers.", True, "Digital thermometers show the reading on a small screen."),
    ("A clinical thermometer can be used to measure hot tea.", False, "Hot tea is above 42 °C, the end of its scale."),
    ("A lab thermometer can measure melting ice.", True, "Melting ice is 0 °C, inside the lab thermometer's range."),
]:
    T(SK, 1, s, v, why, S, pic="thermometer")

# ---- sc6.waterStates (CU6 ch8 A Journey through States of Water)
S = "CU6 ch8"
SK = "sc6.waterStates"
table("waterChange", S, "{Np}: which change is this?", [
    C("ev", "evaporation", "is caused by evaporation", "are both caused by evaporation", "Which is caused by evaporation", "In evaporation, liquid water turns into water vapour."),
    C("co", "condensation", "is caused by condensation", "are both caused by condensation", "Which is caused by condensation", "In condensation, water vapour cools and turns into liquid drops."),
    C("me", "melting", "is caused by melting", "are both caused by melting", "Which is caused by melting", "In melting, solid ice takes in heat and becomes liquid."),
    C("fr", "freezing", "is caused by freezing", "are both caused by freezing", "Which is caused by freezing", "In freezing, liquid water loses heat and becomes ice."),
], [
    R("wet clothes drying", "ev", np="wet clothes drying", pic="shirt"), R("puddle drying up", "ev", np="a puddle drying up", pic="pond"),
    R("sweat drying on skin", "ev", np="sweat drying on your skin", pic="skin"), R("wet floor drying", "ev", np="a mopped floor drying"),
    R("wet hair drying", "ev", np="wet hair drying"), R("salt from salt pans", "ev", np="salt forming in seaside salt pans"),
    R("water drying from plate", "ev", np="water drying up from a plate", pic="plate"),
    R("matka cooling water", "ev", "Water seeping out of a matka evaporates and cools it.", np="a clay matka cooling its water", pic="pot"),
    R("wet road drying in sun", "ev", np="a wet road drying in the sun"),
    R("drops on a cold glass", "co", np="water collecting outside a glass of ice water", pic="glass"), R("dew forming on grass", "co", np="dew forming on grass at dawn", pic="grass"),
    R("mist on bathroom mirror", "co", np="mist on a mirror after a hot bath", pic="mirror"), R("drops under a pot lid", "co", np="water collecting under a cooking pot's lid", pic="pot"),
    R("spectacles fogging up", "co", np="cold spectacles fogging up in a warm room", pic="glasses"), R("clouds forming", "co", np="clouds forming high in the sky", pic="cloud"),
    R("breath misting a window", "co", np="your breath misting a cold window", pic="window"), R("drops on a fridge bottle", "co", np="water collecting on a cold bottle from the fridge", pic="bottle"),
    R("ice cube melting", "me", np="an ice cube melting in a drink"), R("ice cream melting", "me", np="ice cream melting on a hot day", pic="icecream"),
    R("snow melting in summer", "me", np="snow on mountains melting in summer", pic="snow"), R("hailstone melting", "me", np="a hailstone turning into water", pic="hail"),
    R("frost melting in sun", "me", np="frost melting in the morning sun"), R("glacier ice melting", "me", np="glacier ice melting", pic="mountain"),
    R("ice forming in a tray", "fr", np="water turning to ice in a freezer tray", pic="fridge"), R("lake freezing in winter", "fr", np="a lake freezing in winter"),
    R("kulfi setting in freezer", "fr", np="kulfi mix setting in a freezer"), R("pipes freezing in Ladakh", "fr", np="water pipes freezing in a Ladakh winter"),
    R("puddle icing over", "fr", np="a puddle icing over on a cold night"), R("making ice lollies", "fr", np="making ice lollies in a freezer"),
])
table("waterState", S, "{X}: is it water as a solid, liquid or gas?", [
    C("s", "solid", "is water in solid form", "are both water in solid form", "Which is water in solid form", "Ice, snow, hail and frost are solid water."),
    C("l", "liquid", "is water in liquid form", "are both water in liquid form", "Which is water in liquid form", "Rain, dew and fog drops are liquid water."),
    C("g", "gas", "is water in gas form", "", "Which is water in gas form", "Water vapour is an invisible gas in the air."),
], [R("ice", "s", pic="snow"), R("snow", "s", pic="snow"), R("hailstone", "s", np="a hailstone", pic="hail"), R("frost", "s"), R("iceberg", "s", np="an iceberg"),
    R("rain", "l", pic="rain"), R("dew", "l", pic="drop"), R("fog", "l", "Fog is made of tiny drops of liquid water.", pic="fog"), R("river water", "l", pic="river"),
    R("water vapour", "g", "Water vapour is an invisible gas in the air.")], art="")
for q, a, w, why in [
    ("Solid ice turning into liquid water is called ___.", "melting", ["freezing", "condensation", "evaporation"], "In melting, ice takes in heat and becomes liquid."),
    ("Liquid water turning into ice is called ___.", "freezing", ["melting", "evaporation", "condensation"], "In freezing, water loses heat and becomes ice."),
    ("Liquid water turning into vapour is called ___.", "evaporation", ["condensation", "melting", "freezing"], "In evaporation, liquid water turns into water vapour."),
    ("Water vapour turning into drops is called ___.", "condensation", ["evaporation", "melting", "freezing"], "In condensation, vapour cools and becomes liquid drops."),
    ("Clouds are made of ___.", "tiny water drops", ["smoke", "dust", "cotton"], "Clouds form when vapour cools into tiny drops."),
    ("Why does water in a clay matka stay cool?", "water evaporates from it", ["clay is cold", "the sun cools it"], "Evaporation takes heat from the matka and its water."),
    ("Which needs heat to happen?", "melting", ["freezing", "condensation"], "Ice must take in heat to melt."),
    ("Which happens when water vapour cools?", "condensation", ["evaporation", "melting"], "Cooling turns water vapour back into liquid drops."),
    ("Rain, snow and hail falling from clouds is called ___.", "precipitation", ["evaporation", "condensation", "melting"], "Water falling from clouds as rain, snow or hail is precipitation."),
]:
    F(SK, 1, q, a, w, why, S)
DRY = [("in the sun", "in the shade", "Heat from the sun speeds up evaporation."),
       ("spread out", "folded up", "More open surface means faster evaporation."),
       ("on a windy day", "on a still day", "Wind carries the water vapour away quickly."),
       ("on a dry day", "on a humid day", "Dry air takes in water vapour faster than humid air."),
       ("on a hot day", "on a cold day", "Warmth makes water evaporate faster.")]
for obj in ["a wet towel", "a washed shirt", "a wet saree", "a wet bedsheet"]:
    for fast, slow, why in DRY:
        F(SK, 2, f"When does {obj} dry faster?", fast, [slow, "it makes no difference"], why, S)
        T(SK, 2, f"{cap(obj)} dries faster {slow} than {fast}.", False, why, S)
        T(SK, 2, f"{cap(obj)} dries faster {fast} than {slow}.", True, why, S)
O(SK, 2, "Put the water cycle in order.", ["Sun heats water in seas", "Water evaporates", "Vapour cools into clouds", "Rain falls back to Earth"],
  "Heat makes vapour, vapour forms clouds, clouds give rain.", S)
O(SK, 2, "Ice is heated. Put the states in order.", ["ice", "liquid water", "water vapour"], "Heat melts ice into water, then turns water into vapour.", S)
O(SK, 3, "Water vapour is cooled a lot. Put the states in order.", ["water vapour", "liquid water", "ice"], "Cooling condenses vapour into water, then freezes it to ice.", S)

# ---- sc6.separation (CU6 ch9 Methods of Separation in Everyday Life)
S = "CU6 ch9"
SK = "sc6.separation"
M = [
    C("hand", "handpicking", "is done by handpicking", "are both done by handpicking", "Which uses handpicking", "Handpicking removes a few big, easy-to-see unwanted bits."),
    C("thr", "threshing", "is done by threshing", "are both done by threshing", "Which uses threshing", "Threshing beats the stalks to loosen the grains."),
    C("win", "winnowing", "is done by winnowing", "are both done by winnowing", "Which uses winnowing", "Winnowing lets wind blow away light husk from heavy grain."),
    C("sie", "sieving", "is done by sieving", "are both done by sieving", "Which uses sieving", "A sieve lets small bits through and holds back big ones."),
    C("sed", "sedimentation", "is done by sedimentation", "are both done by sedimentation", "Which uses sedimentation", "In sedimentation, heavy bits settle at the bottom of water."),
    C("dec", "decantation", "is done by decantation", "are both done by decantation", "Which uses decantation", "Decantation pours off the liquid and leaves the settled layer."),
    C("fil", "filtration", "is done by filtration", "are both done by filtration", "Which uses filtration", "A filter holds back solid bits and lets liquid pass."),
    C("eva", "evaporation", "is done by evaporation", "are both done by evaporation", "Which uses evaporation", "Evaporation removes the water and leaves the dissolved solid behind."),
    C("mag", "using a magnet", "is done using a magnet", "are both done using a magnet", "Which needs a magnet", "A magnet pulls the iron pieces out of the mix."),
    C("chu", "churning", "is done by churning", "are both done by churning", "Which uses churning", "Churning curd makes the lighter butter collect on top."),
]
MIX = [  # x, primary, also (also right), skip (arguable)
    ("stones from rice", "hand", [], ["sie", "win"]),
    ("stones from dal", "hand", [], ["sie", "win"]),
    ("husk from wheat grains", "win", [], ["sie", "hand"]),
    ("husk from paddy", "win", [], ["sie", "hand"]),
    ("grains from wheat stalks", "thr", [], ["hand"]),
    ("mustard seeds from pods", "thr", [], ["hand"]),
    ("bran from wheat flour", "sie", [], []),
    ("pebbles from sand", "sie", [], ["hand"]),
    ("gravel from sand", "sie", [], ["hand"]),
    ("sand from water", "sed", ["dec", "fil"], ["eva"]),
    ("mud from muddy water", "sed", ["dec", "fil"], ["eva"]),
    ("chalk powder from water", "fil", [], ["sed", "dec", "eva"]),
    ("salt from salt water", "eva", [], []),
    ("salt from sea water", "eva", [], []),
    ("iron filings from sand", "mag", [], ["sie"]),
    ("iron pins from sawdust", "mag", [], ["hand", "sie"]),
    ("iron nails from sand", "mag", [], ["hand", "sie"]),
    ("butter from curd", "chu", [], []),
    ("tea leaves from tea", "fil", [], ["sie", "dec"]),
    ("water from soaked dal", "dec", [], ["fil", "sie", "sed"]),
    ("paneer from whey", "fil", [], ["sie", "dec"]),
    ("oil floating on water", "dec", [], ["sed", "eva"]),
]
table("separate", S, "How can we separate {x}?", M, [
    R(x, c, also=a, skip=s, np=f"separating {x}") for x, c, a, s in MIX], art="")
for ins in ["sand", "chalk powder", "sawdust"]:
    F(SK, 3, f"Salt is mixed with {ins}. What is the first step to get the salt?", "add water and stir", ["evaporate it", "filter it", "use a magnet"],
      "Salt dissolves in water, but the " + ins + " does not.", S)
    F(SK, 3, f"Salt and {ins} are stirred in water. What is the next step?", "filter the mixture", ["evaporate it first", "add more salt", "churn it"],
      "Filtering holds back the " + ins + " and lets salt water through.", S)
    F(SK, 3, f"Salt water has been filtered from {ins}. How do we get the salt?", "evaporate the water", ["filter it again", "sieve it", "churn it"],
      "Evaporating the water leaves the salt behind.", S)
    O(SK, 3, f"Get salt back from salt mixed with {ins}. Put the steps in order.", ["Add water and stir", f"Filter out the {ins}", "Evaporate the water"],
      "Dissolve the salt, filter the solid, then evaporate the water.", S)
O(SK, 2, "Clean muddy water. Put the steps in order.", ["Let the mud settle", "Pour off the clear water", "Filter the water"],
  "Sedimentation, then decantation, then filtration gives clean water.", S)
O(SK, 2, "From crop to clean grain: put the steps in order.", ["Cut the crop", "Thresh the stalks", "Winnow the grain"],
  "Harvest first, thresh to loosen grain, then winnow off the husk.", S)
O(SK, 2, "Make butter at home: put the steps in order.", ["Boil the milk", "Set it into curd", "Churn the curd", "Collect the butter"],
  "Milk is set into curd, and churning brings butter up.", S)
for q, a, w, why in [
    ("Which method uses the wind?", "winnowing", ["sieving", "filtration", "churning"], "Winnowing lets wind blow away the light husk."),
    ("Which method works because parts differ in size?", "sieving", ["evaporation", "winnowing", "churning"], "A sieve sorts bits by their size."),
    ("Which method works because husk is lighter than grain?", "winnowing", ["sieving", "using a magnet", "evaporation"], "Wind carries the light husk away from the heavy grain."),
    ("Which method works because one part has iron in it?", "using a magnet", ["sieving", "winnowing", "filtration"], "A magnet pulls out only things with iron."),
    ("Which method needs heat to remove water?", "evaporation", ["filtration", "decantation", "sieving"], "Heating makes the water evaporate and leaves the solid."),
    ("Why can't filtration get salt from salt water?", "salt passes through", ["salt is too big", "salt is magnetic"], "Dissolved salt goes through the filter with the water."),
    ("Heavy bits settling at the bottom of water is called ___.", "sedimentation", ["decantation", "evaporation", "churning"], "In sedimentation, heavy bits settle at the bottom."),
    ("Pouring off clear water from settled mud is called ___.", "decantation", ["sedimentation", "filtration", "winnowing"], "Decantation pours off the liquid and leaves the settled layer."),
    ("Beating harvested stalks to free the grains is called ___.", "threshing", ["winnowing", "churning", "sieving"], "Threshing beats the stalks to loosen the grains."),
]:
    F(SK, 2, q, a, w, why, S)

# ---- sc6.lifeSigns (CU6 ch10 Living Creatures)
S = "CU6 ch10"
SK = "sc6.lifeSigns"
table("living", S, "Is {np} living or non-living?", [
    C("liv", "living", "is living", "are both living", "Which is living", "Living things grow, breathe, need food and reproduce."),
    C("non", "non-living", "is non-living", "are both non-living", "Which is non-living", "Non-living things do not grow, breathe or reproduce."),
], [R("dog", "liv", pic="dog"), R("neem tree", "liv", pic="neem"), R("mushroom", "liv", "A mushroom grows and reproduces, so it is living.", pic="mushroom"),
    R("ant", "liv", pic="ant"), R("earthworm", "liv", pic="earthworm"), R("seed", "liv", "A seed is alive; it can grow into a plant.", pic="seed"),
    R("fish", "liv", pic="fish"), R("frog", "liv", pic="frog"), R("cactus", "liv", pic="cactus"), R("sparrow", "liv", pic="sparrow"),
    R("tortoise", "liv", pic="turtle"), R("cow", "liv", pic="cow"), R("butterfly", "liv", pic="butterfly"), R("silkworm", "liv"),
    R("tulsi plant", "liv", pic="tulsi"), R("grass", "liv", np="grass", pic="grass"), R("lotus plant", "liv", pic="lotus"),
    R("stone", "non", pic="stone"), R("car", "non", "A car moves, but it cannot grow or reproduce.", pic="car"),
    R("cloud", "non", "Clouds move and change, but they are not alive.", pic="cloud"),
    R("fire", "non", "Fire needs air and spreads, but it is not alive.", np="fire", pic="fire"), R("river", "non", pic="river"),
    R("robot", "non", "A robot moves, but it cannot grow or reproduce."), R("bicycle", "non", pic="bicycle"), R("chair", "non", pic="chair"),
    R("wooden table", "non", "Wood came from a tree, but a table is not alive.", pic="table"), R("paper", "non", np="paper"),
    R("Sun", "non", "The Sun gives light and heat, but it is not alive.", np="the Sun", pic="sun"),
    R("wind", "non", np="wind", pic="wind"), R("water", "non", np="water", pic="drop"), R("plastic doll", "non"), R("computer", "non"), R("ice cube", "non"),
])
LIFE = [("frog", ["egg", "tadpole", "froglet", "adult frog"], "A frog's egg hatches into a tadpole, which becomes a frog."),
        ("butterfly", ["egg", "caterpillar", "pupa", "butterfly"], "A caterpillar forms a pupa, and a butterfly comes out."),
        ("mosquito", ["egg", "larva", "pupa", "adult mosquito"], "Mosquito eggs hatch into larvae in water, then pupae."),
        ("silk moth", ["egg", "caterpillar", "cocoon", "silk moth"], "The silkworm spins a cocoon, and a moth comes out."),
        ("plant", ["seed", "seedling", "young plant", "flowering plant"], "A seed sprouts into a seedling that grows and flowers."),
        ("hen", ["egg", "chick", "hen"], "A hen's egg hatches into a chick that grows up.")]
for name, items, why in LIFE:
    an = "an" if name[0] in "aeiou" else "a"
    O(SK, 2, f"Put the life cycle of {an} {name} in order.", items, why, S)
    CH(SK, id=name, items=items, art="the ", t=2, src=S, why=why,
       next=f"In {an} {name}'s life, what comes after the {{x}}?", prev=f"In {an} {name}'s life, what comes just before the {{x}}?",
       adj="", cmp="", cmpWhy="", pos="", cyclic=False)
SETUPS = [("on dry cotton", "water"), ("on wet cotton", None), ("under boiled water with oil on top", "air")]
PLACES = [("in a warm, bright room", None), ("in a warm, dark cupboard", None), ("in a fridge", "cold")]
WHY = {None: "Seeds need water, air and warmth to sprout; light is not needed.",
       "water": "Seeds cannot sprout without water.", "air": "Boiled water with oil on top has no air for the seeds.",
       "cold": "It is too cold in a fridge for seeds to sprout."}
ANS = {None: "yes", "water": "no, no water", "air": "no, no air", "cold": "no, too cold"}
for seed in ["Gram seeds", "Moong seeds"]:
    for su, f1 in SETUPS:
        for pl, f2 in PLACES:
            if f1 and f2:
                continue
            f = f1 or f2
            F(SK, 3, f"{seed} are kept {su} {pl}. Will they sprout?", ANS[f], [v for k, v in ANS.items() if k != f], WHY[f], S, pic="seed")
for s, v, why in [
    ("All living things need food.", True, "Food gives living things energy to live and grow."),
    ("Plants can make their own food.", True, "Green plants make food using sunlight, water and air."),
    ("A car is living because it moves.", False, "A car moves, but it cannot grow or reproduce."),
    ("Living things respond to changes around them.", True, "A touch-me-not folds its leaves when touched."),
    ("Only animals breathe; plants do not.", False, "Plants also take in air and respire."),
    ("Living things get rid of waste from their bodies.", True, "Removing waste is a sign of life."),
    ("Seeds are non-living because they do not move.", False, "A seed is alive; it can grow into a plant."),
    ("All living things grow.", True, "Growth is a sign of life."),
    ("Fire is living because it grows.", False, "Fire spreads, but it does not breathe or reproduce."),
    ("Plants and animals make more of their own kind.", True, "Reproducing is a sign of life."),
    ("All living things move from place to place.", False, "Most plants stay in one place, yet they are living."),
    ("Seeds need light to sprout.", False, "Seeds need water, air and warmth, but not light."),
]:
    T(SK, 1, s, v, why, S)

# ---- sc6.resources (CU6 ch11 Nature's Treasures)
S = "CU6 ch11"
SK = "sc6.resources"
table("renewable", S, "Is {np} renewable or non-renewable?", [
    C("ren", "renewable", "is renewable", "are both renewable", "Which is renewable", "Renewable resources are replaced by nature and will not run out."),
    C("non", "non-renewable", "is non-renewable", "are both non-renewable", "Which is non-renewable", "Non-renewable resources took millions of years to form and can run out."),
], [R(x, "ren", pic=p) for x, p in [("sunlight", "sun"), ("wind", "wind"), ("air", ""), ("solar energy", "sun"), ("wind energy", "wind"), ("biogas", "")]]
 + [R(x, "non") for x in ["coal", "petroleum", "natural gas", "petrol", "diesel", "kerosene", "CNG", "LPG", "iron ore", "bauxite", "copper ore"]], art="")
table("fossil", S, "Is {np} a fossil fuel?", [
    C("yes", "fossil fuel", "is a fossil fuel", "are both fossil fuels", "Which is a fossil fuel", "Coal, petroleum and natural gas formed from remains of ancient life."),
    C("no", "not a fossil fuel", "is not a fossil fuel", "", "", "Fossil fuels are only coal, petroleum, natural gas and their products."),
], [R(x, "yes") for x in ["coal", "petroleum", "natural gas", "petrol", "diesel", "kerosene"]]
 + [R(x, "no", pic=p) for x, p in [("firewood", ""), ("biogas", ""), ("sunlight", "sun"), ("wind", "wind"), ("cow dung cakes", "")]], art="")
for q, a, w, why in [
    ("Coal, petroleum and natural gas are called ___.", "fossil fuels", ["renewable fuels", "biofuels"], "They formed from remains of plants and animals long ago."),
    ("Fossil fuels formed from ___.", "dead plants and animals", ["sea salt", "melted ice", "sunlight"], "Remains buried for millions of years slowly became fossil fuels."),
    ("Which fuel comes in kitchen gas cylinders?", "LPG", ["petrol", "diesel", "coal"], "LPG is liquefied petroleum gas for cooking."),
    ("Which gas is found most in air?", "nitrogen", ["oxygen", "carbon dioxide"], "Air is about four-fifths nitrogen."),
    ("Which gas in air do we need to breathe?", "oxygen", ["nitrogen", "carbon dioxide", "helium"], "Our bodies use oxygen to get energy from food."),
    ("Which gas do green plants use to make food?", "carbon dioxide", ["oxygen", "nitrogen", "helium"], "Plants make food from carbon dioxide and water."),
    ("Which of these do forests give us?", "wood and medicines", ["petrol and diesel", "iron and copper"], "Forests give wood, fruits, honey and medicinal plants."),
    ("Which device turns sunlight into electricity?", "solar panel", ["windmill", "petrol pump", "gas stove"], "Solar panels turn sunlight into electricity."),
    ("Which device makes electricity from wind?", "wind turbine", ["solar panel", "gas stove", "coal mine"], "A wind turbine's blades turn to make electricity."),
    ("Which fuel does a CNG bus use?", "natural gas", ["petrol", "coal", "biogas"], "CNG means compressed natural gas."),
]:
    F(SK, 1, q, a, w, why, S)
for prod in ["petrol", "diesel", "kerosene", "LPG"]:
    F(SK, 2, "Which fuel is made from petroleum?", prod, ["biogas", "firewood", "cow dung cakes"], "Petrol, diesel, kerosene and LPG come from petroleum.", S)
for s, v, why in [
    ("Turning off the tap while brushing saves water.", True, "Running taps waste a lot of clean water."),
    ("Leaving fans on in an empty room saves electricity.", False, "Switching off unused fans and lights saves electricity."),
    ("Using buses and trains instead of cars saves fuel.", True, "Shared transport burns less fuel per person."),
    ("Burning garbage keeps the air clean.", False, "Burning garbage gives off harmful smoke."),
    ("Tree roots help hold soil in place.", True, "Roots bind the soil so rain cannot wash it away."),
    ("Rainwater can be collected and stored for later use.", True, "Rainwater harvesting saves water for dry months."),
    ("Coal will never run out.", False, "Coal took millions of years to form and can run out."),
    ("Sunlight will not run out for a very long time.", True, "The Sun will keep shining for billions of years."),
    ("A few centimetres of soil take hundreds of years to form.", True, "Rocks break down into soil very slowly."),
    ("Cutting down forests can cause soil erosion.", True, "Without roots, rain washes the topsoil away."),
    ("Biogas is made from cow dung and plant waste.", True, "Waste rotting without air gives off biogas."),
    ("Natural gas is a renewable resource.", False, "Natural gas formed over millions of years and can run out."),
]:
    T(SK, 1, s, v, why, S)

# ---- sc6.space (CU6 ch12 Beyond Earth)
S = "CU6 ch12"
SK = "sc6.space"
PLANETS = ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
PWHY = "From the Sun: Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune."
O(SK, 2, "Put these planets in order, nearest the Sun first.", PLANETS, PWHY, S)
O(SK, 3, "Put these planets in order, farthest from the Sun first.", list(reversed(PLANETS)), PWHY, S)
CH(SK, id="planets", items=PLANETS, art="", t=2, src=S, why=PWHY,
   next="Going out from the Sun, which planet comes after {x}?", prev="Going out from the Sun, which planet comes just before {x}?",
   adj="", cmp="{a} is closer to the Sun than {b}.", cmpWhy="{A} is planet {i} from the Sun; {b} is planet {j}.",
   pos="Which planet is {n} from the Sun?", cyclic=False)
table("planetKind", S, "Is {x} a rocky planet or a giant planet?", [
    C("rock", "rocky", "is a rocky planet", "are both rocky planets", "Which is a rocky planet", "Mercury, Venus, Earth and Mars are small rocky planets."),
    C("giant", "giant", "is a giant planet", "are both giant planets", "Which is a giant planet", "Jupiter, Saturn, Uranus and Neptune are huge giant planets."),
], [R(p, "rock" if i < 4 else "giant", pic="earth" if p == "Earth" else ("saturn" if p == "Saturn" else "planet")) for i, p in enumerate(PLANETS)], art="")
for q, a, w, why, pic in [
    ("Which planet is the largest?", "Jupiter", ["Saturn", "Earth", "Neptune"], "Jupiter is the biggest planet in our solar system.", "planet"),
    ("Which planet is the smallest?", "Mercury", ["Mars", "Venus", "Earth"], "Mercury is the smallest planet and nearest the Sun.", "planet"),
    ("Which planet is the hottest?", "Venus", ["Mercury", "Mars", "Jupiter"], "Venus's thick clouds trap heat, making it hotter than Mercury.", "planet"),
    ("Which planet is called the Red Planet?", "Mars", ["Venus", "Jupiter", "Saturn"], "Mars looks red because of rusty dust on it.", "planet"),
    ("Which planet is famous for its bright rings?", "Saturn", ["Mars", "Venus", "Mercury"], "Saturn's wide rings are made of ice and rock.", "saturn"),
    ("The Sun is a ___.", "star", ["planet", "moon", "comet"], "The Sun is a star, a huge ball of hot gases.", "sun"),
    ("The Moon is Earth's ___.", "natural satellite", ["star", "planet", "comet"], "The Moon goes round the Earth, so it is a satellite.", "moon"),
    ("India's first satellite was ___.", "Aryabhata", ["Chandrayaan", "Mangalyaan", "Rohini"], "Aryabhata was launched in 1975.", ""),
    ("Chandrayaan-3 landed on the ___.", "Moon", ["Mars", "Sun", "Venus"], "Chandrayaan-3 landed near the Moon's south pole in 2023.", "moon"),
    ("India's Mangalyaan went to ___.", "Mars", ["the Moon", "Venus", "Jupiter"], "Mangal means Mars, and Mangalyaan reached Mars in 2014.", "rocket"),
    ("Which star seems fixed in the northern sky?", "Pole Star", ["Sirius", "the Sun", "Moon"], "The Pole Star stays almost still above the North Pole.", "star"),
    ("A group of stars forming a pattern is a ___.", "constellation", ["planet", "comet", "satellite"], "Constellations are star patterns, like Orion.", "star"),
    ("Saptarishi is the Indian name for ___.", "Ursa Major", ["Orion", "the Pole Star", "the Milky Way"], "Ursa Major's seven bright stars are called Saptarishi.", "star"),
    ("Our galaxy is called the ___.", "Milky Way", ["Andromeda", "Orion", "Saptarishi"], "The Sun is one of billions of stars in the Milky Way.", "star"),
    ("Shooting stars are really ___.", "meteors", ["stars", "planets", "satellites"], "Meteors are space rocks burning up in our air.", "comet"),
    ("Between Mars and Jupiter lies the ___.", "asteroid belt", ["Moon", "Milky Way", "Pole Star"], "Many rocky asteroids orbit between Mars and Jupiter.", "planet"),
    ("Sunlight takes about ___ to reach Earth.", "8 minutes", ["8 seconds", "8 days", "8 hours"], "Light from the Sun travels for about eight minutes to us.", "sun"),
    ("Planets shine in the sky because they ___.", "reflect sunlight", ["make their own light", "are on fire"], "Planets have no light of their own.", "planet"),
    ("How many planets go round the Sun?", "8", ["9", "7", "10"], "Pluto is now a dwarf planet, so there are eight.", "planet"),
    ("Pluto is now called a ___.", "dwarf planet", ["star", "moon", "comet"], "Pluto is too small to count as a full planet.", "planet"),
    ("Which tool helps us see faraway stars clearly?", "telescope", ["thermometer", "compass", "beaker"], "A telescope makes faraway things look closer.", "telescope"),
]:
    F(SK, 1, q, a, w, why, S, pic=pic)
for s, v, why in [
    ("The Moon makes its own light.", False, "The Moon shines by reflecting sunlight."),
    ("The Sun is the nearest star to Earth.", True, "The Sun is a star, and the closest one to us."),
    ("Stars are also in the sky during the day.", True, "Bright sunlight hides the stars in the day."),
    ("Earth is the only planet known to have life.", True, "So far, life is known only on Earth."),
    ("A comet has a bright tail when near the Sun.", True, "The Sun's heat makes a comet's ice glow as a tail."),
]:
    T(SK, 1, s, v, why, S)


# ================================================================ CLASS 7

# ---- sc7.acidBase (CU7 ch2 Exploring Substances: Acidic, Basic, and Neutral)
S = "CU7 ch2"
SK = "sc7.acidBase"
SUB = [
    ("lemon juice", "acid", "Lemon juice has citric acid, so it is acidic.", "lemon"),
    ("vinegar", "acid", "Vinegar contains acetic acid.", "bottle"),
    ("orange juice", "acid", "Oranges contain citric acid.", "orange"),
    ("tamarind water", "acid", "Tamarind contains tartaric acid.", ""),
    ("curd", "acid", "Curd contains lactic acid.", "curd"),
    ("buttermilk", "acid", "Buttermilk contains lactic acid.", "glass"),
    ("amla juice", "acid", "Amla contains ascorbic acid, which is vitamin C.", ""),
    ("tomato juice", "acid", "Tomato juice tastes sour because it contains acids.", "tomato"),
    ("soda water", "acid", "Soda water has carbonic acid from dissolved carbon dioxide.", "bottle"),
    ("dilute hydrochloric acid", "acid", "Hydrochloric acid is a strong acid used in labs.", "testtube"),
    ("dilute sulphuric acid", "acid", "Sulphuric acid is a strong acid used in labs.", "testtube"),
    ("soap solution", "base", "Soap solution is basic and feels slippery.", "soap"),
    ("baking soda solution", "base", "Baking soda, sodium hydrogen carbonate, is a base.", "beaker"),
    ("lime water", "base", "Lime water is calcium hydroxide, a base.", "beaker"),
    ("washing soda solution", "base", "Washing soda, sodium carbonate, is basic.", "beaker"),
    ("milk of magnesia", "base", "Milk of magnesia is a base used for acidity.", "bottle"),
    ("ammonia solution", "base", "Ammonia solution, ammonium hydroxide, is a base.", "bottle"),
    ("caustic soda solution", "base", "Caustic soda is sodium hydroxide, a strong base.", "testtube"),
    ("detergent solution", "base", "Detergent solutions are basic and feel soapy.", "bucket"),
    ("sugar solution", "neu", "Sugar solution changes neither red nor blue litmus.", "glass"),
    ("salt solution", "neu", "Common salt solution is neutral.", "glass"),
    ("distilled water", "neu", "Pure, distilled water is neutral.", "beaker"),
    ("glucose solution", "neu", "Glucose solution changes neither red nor blue litmus.", "glass"),
]
table("acidBase", S, "Is {np} acidic, basic or neutral?", [
    C("acid", "acidic", "is acidic", "are both acidic", "Which is acidic", "Acidic substances taste sour and turn blue litmus red."),
    C("base", "basic", "is basic", "are both basic", "Which is basic", "Basic substances feel soapy and turn red litmus blue."),
    C("neu", "neutral", "is neutral", "are both neutral", "Which is neutral", "Neutral substances change neither red nor blue litmus."),
], [R(x, c, why, pic=p) for x, c, why, p in SUB], art="")
for q, a, w, why in [
    ("An ant bite injects formic acid. What helps?", "baking soda paste", ["vinegar", "lemon juice", "salt water"], "Baking soda is a base, so it neutralises the acid."),
    ("For acidity in the stomach, people take ___.", "milk of magnesia", ["vinegar", "lemon juice", "tamarind water"], "Milk of magnesia is a base that neutralises extra acid."),
    ("Soil is too acidic. A farmer can add ___.", "slaked lime", ["vinegar", "lemon juice", "sugar"], "Slaked lime is a base that neutralises acidic soil."),
    ("Soil is too basic. A farmer can add ___.", "compost", ["slaked lime", "baking soda", "washing soda"], "Compost releases acids that neutralise basic soil."),
    ("An acid and a base react to give ___.", "salt and water", ["sugar and water", "oxygen gas", "a stronger acid"], "Neutralisation makes a salt and water."),
    ("When an acid neutralises a base, heat is ___.", "given out", ["taken in", "not changed"], "Neutralisation warms the mixture, giving out heat."),
    ("Acidic factory waste should be treated with ___.", "a base", ["an acid", "more water only"], "A base neutralises the acid before the waste is released."),
    ("Acids usually taste ___.", "sour", ["sweet", "bitter", "salty"], "Lemon, tamarind and vinegar taste sour because they are acidic."),
    ("Bases usually feel ___.", "soapy", ["sticky", "rough", "sandy"], "Bases like soap solution feel slippery and soapy."),
    ("Mixing an acid and a base so both cancel is ___.", "neutralisation", ["evaporation", "rusting", "melting"], "In neutralisation, an acid and a base cancel each other."),
]:
    F(SK, 2, q, a, w, why, S)
T(SK, 1, "We should taste chemicals in a lab to test them.", False, "Never taste lab chemicals; some can harm you.", S)
T(SK, 1, "Lemons taste sour because they contain an acid.", True, "Citric acid gives lemons their sour taste.", S)
acids = ["vinegar", "lemon juice", "dilute hydrochloric acid", "tamarind water", "dilute sulphuric acid"]
bases = [x for x, c, _, _ in SUB if c == "base"]
neus = [x for x, c, _, _ in SUB if c == "neu"]
for i, ac in enumerate(acids):
    for j, b in enumerate(bases):
        w = [acids[(i + 1) % 5], acids[(i + 2) % 5], neus[(i + j) % 4]]
        F(SK, 3, f"Which can neutralise {ac}?", b, w, "Only a base can neutralise an acid.", S)
for i, b in enumerate(bases):
    for j, ac in enumerate(acids):
        w = [bases[(i + 1) % 8], bases[(i + 3) % 8], neus[(i + j) % 4]]
        F(SK, 3, f"Which can neutralise {b}?", ac, w, "Only an acid can neutralise a base.", S)

# ---- sc7.indicators (CU7 ch2)
SK = "sc7.indicators"
nature = {x: c for x, c, _, _ in SUB}
IND = {
    "redLitmus": ("red litmus", {"base": "blue", "acid": "red", "neu": "red"},
                  C("yes", "turns blue", "turns red litmus blue", "both turn red litmus blue", "Which turns red litmus blue", "Only bases turn red litmus blue."),
                  C("no", "stays red", "leaves red litmus red", "", "", "Acids and neutral substances leave red litmus red."), {"base": "yes", "acid": "no", "neu": "no"}),
    "blueLitmus": ("blue litmus", {"acid": "red", "base": "blue", "neu": "blue"},
                   C("yes", "turns red", "turns blue litmus red", "both turn blue litmus red", "Which turns blue litmus red", "Only acids turn blue litmus red."),
                   C("no", "stays blue", "leaves blue litmus blue", "", "", "Bases and neutral substances leave blue litmus blue."), {"acid": "yes", "base": "no", "neu": "no"}),
    "turmeric": ("turmeric paper", {"base": "red", "acid": "yellow", "neu": "yellow"},
                 C("yes", "turns red", "turns turmeric paper red", "both turn turmeric paper red", "Which turns turmeric paper red", "Bases turn yellow turmeric red."),
                 C("no", "stays yellow", "leaves turmeric paper yellow", "", "", "Acids and neutral substances leave turmeric yellow."), {"base": "yes", "acid": "no", "neu": "no"}),
    "chinaRose": ("China rose solution", {"acid": "dark pink", "base": "green"},
                  C("yes", "turns green", "turns China rose solution green", "both turn China rose solution green", "Which turns China rose solution green", "Bases turn China rose indicator green."),
                  C("no", "turns dark pink", "turns China rose solution dark pink", "both turn China rose solution dark pink", "Which turns China rose solution dark pink", "Acids turn China rose indicator dark pink."),
                  {"base": "yes", "acid": "no"}),
}
for name, (ind, colours, cy, cn, cls) in IND.items():
    rows = [R(x, cls[c], pic=p) for x, c, _, p in SUB if c in cls]
    table(name, S, f"{{X}} on {ind}: what happens?", [cy, cn], rows, art="")
    allc = ["red", "blue", "yellow", "green", "dark pink"]
    for x, c, why, p in SUB:
        if c not in colours:
            continue
        a = colours[c]
        w = [k for k in (["red", "blue", "green"] if "litmus" in ind else ["red", "yellow", "green", "dark pink"]) if k != a][:3]
        nm = {"acid": "acidic", "base": "basic", "neu": "neutral"}[c]
        F(SK, 2, f"A drop of {x} on {ind}. What colour does it show?", a, w, f"{cap(x)} is {nm}, so {ind} shows {a}."
          if words(f"{cap(x)} is {nm}, so {ind} shows {a}.") <= 12 else f"{cap(nm)} substances make {ind} show {a}.", S, pic=p)
RES = [("turns red litmus blue", "base"), ("turns blue litmus red", "acid"), ("turns turmeric paper red", "base"),
       ("turns China rose solution green", "base"), ("turns China rose solution dark pink", "acid"), ("changes neither red nor blue litmus", "neu")]
RWHY = {"base": "Only a base does this.", "acid": "Only an acid does this.", "neu": "A neutral substance leaves both litmus colours unchanged."}
for k, (res, c) in enumerate(RES):
    good = [x for x, cc, _, _ in SUB if cc == c]
    bad = [x for x, cc, _, _ in SUB if cc != c]
    for i, g in enumerate(good):
        w = [bad[(i * 3 + k) % len(bad)], bad[(i * 3 + k + 5) % len(bad)], bad[(i * 3 + k + 11) % len(bad)]]
        F(SK, 3, f"A liquid {res}. Which could it be?", g, w, RWHY[c], S, pic="testtube")
TWO = [("turns turmeric paper red", "base"), ("turns blue litmus red", "acid"), ("turns China rose solution green", "base"),
       ("turns China rose solution dark pink", "acid"), ("turns red litmus blue", "base")]
EFF = {"red litmus": {"base": "turns it blue", "acid": "leaves it red"}, "blue litmus": {"base": "leaves it blue", "acid": "turns it red"},
       "turmeric paper": {"base": "turns it red", "acid": "leaves it yellow"}, "China rose solution": {"base": "turns it green", "acid": "turns it dark pink"}}
for res, c in TWO:
    for ind, eff in EFF.items():
        if ind.split()[0] in res and ind.split()[-1] in res:
            continue
        a = eff[c]
        w = [eff["acid" if c == "base" else "base"], "turns it violet"]
        nm = "basic" if c == "base" else "acidic"
        F(SK, 3, f"A liquid {res}. What will it do to {ind}?", a, w, f"The liquid is {nm}, so it {a.replace('it', ind)}.", S)
for q, a, w, why in [
    ("Litmus is a natural indicator made from ___.", "lichens", ["turmeric", "hibiscus", "rocks"], "Litmus dye is taken from lichens."),
    ("China rose indicator is made from ___ petals.", "hibiscus", ["marigold", "lotus", "sunflower"], "China rose is another name for the hibiscus flower."),
    ("A substance that changes colour in acids or bases is an ___.", "indicator", ["insulator", "magnet", "ore"], "Indicators show colour changes in acids or bases."),
    ("A turmeric stain turns red when washed with soap. Why?", "soap is basic", ["soap is acidic", "soap is neutral", "water is acidic"], "Bases turn turmeric red, and soap is a base."),
    ("Which natural indicator comes from a kitchen spice?", "turmeric", ["litmus", "China rose", "vinegar"], "Turmeric is a spice that turns red in bases."),
    ("Blue litmus turns red in an ___.", "acid", ["base", "neutral liquid"], "Only acids turn blue litmus red."),
    ("Red litmus turns blue in a ___.", "base", ["acid", "neutral liquid"], "Only bases turn red litmus blue."),
]:
    F(SK, 1, q, a, w, why, S)

# ---- sc7.circuits (CU7 ch3 Electricity: Circuits and their Components)
S = "CU7 ch3"
SK = "sc7.circuits"
COND = [("copper wire", "wire"), ("iron nail", ""), ("aluminium foil", ""), ("steel spoon", "spoon"), ("brass key", "key"), ("safety pin", ""),
        ("paper clip", ""), ("coin", ""), ("gold chain", ""), ("iron screw", ""), ("silver spoon", "spoon"), ("iron rod", "")]
INS = [("plastic ruler", "ruler"), ("rubber eraser", "eraser"), ("wooden ice-cream stick", ""), ("glass bangle", ""), ("paper strip", ""),
       ("cotton thread", "thread"), ("piece of chalk", ""), ("cardboard strip", ""), ("plastic comb", "comb"), ("rubber band", ""),
       ("candle", "candle"), ("matchstick", ""), ("plastic straw", ""), ("woollen thread", ""), ("thermocol piece", ""), ("cork", "")]
NPM = {"aluminium foil": "aluminium foil", "pencil lead": "pencil lead", "rubber eraser": "an eraser made of rubber"}
rows = [R(x, "cond", np=NPM.get(x), pic=p) for x, p in COND] + [R("pencil lead", "cond", "Pencil lead is graphite, a non-metal that conducts electricity.", np="pencil lead", pic="pencil")] \
    + [R(x, "ins", np=NPM.get(x), pic=p) for x, p in INS]
table("conductor", S, "Is {np} a conductor or an insulator?", [
    C("cond", "conductor", "conducts electricity", "both conduct electricity", "Which conducts electricity", "Metals and graphite let electric current pass through them."),
    C("ins", "insulator", "does not conduct electricity", "", "", "Insulators like plastic, rubber and wood block electric current."),
], rows)
allx = [(x, "cond") for x, _ in COND] + [("pencil lead", "cond")] + [(x, "ins") for x, _ in INS]
for x, c in allx:
    np_ = NPM.get(x, article(x))
    on = c == "cond"
    why = "A conductor in the gap completes the circuit." if on else "An insulator in the gap leaves the circuit open."
    T(SK, 2, f"The switch is on and {np_} bridges the gap in the circuit. The bulb glows.", on, why, S, pic="bulb")
    if on:
        T(SK, 2, f"The switch is off, but {np_} bridges the gap. The bulb glows.", False, "An open switch breaks the circuit, so no current flows.", S, pic="switch")
        T(SK, 3, f"The switch is on and {np_} bridges the gap, but the bulb is fused. The bulb glows.", False,
          "A fused bulb has a broken filament, so the circuit is open.", S, pic="bulb")
        F(SK, 3, f"The cell is new, the switch is on and {np_} bridges the gap. The bulb stays dark. Why?", "the bulb is fused",
          ["insulator in the gap", "the switch is off"], "With everything else fine, the bulb's filament must be broken.", S, pic="bulb")
    else:
        F(SK, 3, f"The cell is new, the switch is on and {np_} bridges the gap. The bulb stays dark. Why?", "insulator in the gap",
          ["the switch is off", "the cell is too new"], f"{cap(np_)} does not conduct, so the circuit stays open." if words(f"{cap(np_)} does not conduct, so the circuit stays open.") <= 12 else "An insulator in the gap leaves the circuit open.", S, pic="bulb")
for q, a, w, why, pic in [
    ("A cell has a positive and a ___ terminal.", "negative", ["neutral", "magnetic", "hot"], "Current flows from the positive to the negative terminal outside the cell.", "battery"),
    ("The thin wire inside a bulb that glows is the ___.", "filament", ["switch", "terminal", "cell"], "The filament glows when current passes through it.", "bulb"),
    ("When the switch is on, the circuit is ___.", "closed", ["open", "broken"], "A closed circuit makes a complete path for current.", "switch"),
    ("Two or more cells joined together make a ___.", "battery", ["bulb", "switch", "filament"], "A battery is a group of cells joined together.", "battery"),
    ("A bulb whose filament is broken is ___.", "fused", ["closed", "charged", "magnetic"], "A broken filament means no path for current.", "bulb"),
    ("Current flows only in a ___ circuit.", "closed", ["open", "broken"], "Current needs a complete, unbroken path.", ""),
    ("Which part breaks or completes a circuit?", "switch", ["filament", "bulb holder", "cell"], "A switch opens or closes the circuit.", "switch"),
    ("In a torch, the positive end of one cell touches the ___ of the next.", "negative end", ["positive end", "switch"], "Cells join positive to negative to work together.", "torch"),
    ("In the cell symbol, the longer line stands for the ___.", "positive terminal", ["negative terminal", "switch"], "In a circuit diagram, the long line is positive.", "battery"),
    ("Electricians wear rubber gloves because rubber is ___.", "an insulator", ["a conductor", "magnetic"], "Rubber does not let current reach the body.", ""),
    ("Wires are covered with plastic because plastic ___.", "is an insulator", ["is a conductor", "is shiny"], "The plastic cover keeps the current inside the wire.", "wire"),
    ("A circuit with a gap in it is an ___ circuit.", "open", ["closed", "short"], "A gap breaks the path, so current cannot flow.", ""),
    ("Which is a conductor though it is not a metal?", "graphite", ["rubber", "plastic", "wood"], "Graphite, used in pencil lead, conducts electricity.", "pencil"),
    ("What is this circuit part?", "bulb", ["switch", "cell", "magnet"], "A bulb glows when current flows through its filament.", "bulb"),
    ("What is this circuit part?", "switch", ["bulb", "cell", "magnet"], "A switch opens or closes a circuit.", "switch"),
    ("What is this circuit part?", "cell", ["bulb", "switch", "compass"], "A cell pushes current around the circuit.", "battery"),
]:
    F(SK, 1, q, a, w, why, S, pic=pic)
for s, v, why in [
    ("Never touch electric sockets with wet hands.", True, "Water can let current flow through your body."),
    ("We can experiment with mains electricity at home.", False, "Mains electricity is dangerous; use only cells for experiments."),
    ("A cell makes electricity from chemicals inside it.", True, "Chemicals in a cell produce electric current."),
    ("A bulb glows with only one wire joined to the cell.", False, "A bulb needs a complete loop through both terminals."),
]:
    T(SK, 1, s, v, why, S)

# ---- sc7.metals (CU7 ch4 The World of Metals and Non-metals)
S = "CU7 ch4"
SK = "sc7.metals"
METALS = ["iron", "copper", "aluminium", "gold", "silver", "zinc", "magnesium", "sodium", "mercury", "lead", "tin", "calcium"]
NONM = ["sulphur", "carbon", "oxygen", "nitrogen", "hydrogen", "phosphorus", "iodine", "chlorine", "bromine", "helium"]
EWHY = {"mercury": "Mercury is a metal, though it is liquid at room temperature.",
        "sodium": "Sodium is a soft metal you can cut with a knife.",
        "iodine": "Iodine is a non-metal, though it looks shiny.",
        "carbon": "Carbon is a non-metal; graphite and diamond are its forms.",
        "bromine": "Bromine is a non-metal that is liquid at room temperature."}
table("metal", S, "Is {x} a metal or a non-metal?", [
    C("m", "metal", "is a metal", "are both metals", "Which is a metal", "Metals are usually shiny, hard and good conductors."),
    C("n", "non-metal", "is a non-metal", "are both non-metals", "Which is a non-metal", "Non-metals are usually dull, brittle and poor conductors."),
], [R(x, "m", EWHY.get(x, "")) for x in METALS] + [R(x, "n", EWHY.get(x, "")) for x in NONM], art="")
STATE = {"mercury": "l", "bromine": "l", "oxygen": "g", "nitrogen": "g", "hydrogen": "g", "chlorine": "g", "helium": "g"}
table("elemState", S, "At room temperature, is {x} a solid, a liquid or a gas?", [
    C("s", "solid", "is a solid at room temperature", "are both solids at room temperature", "Which is a solid at room temperature", "Most metals and some non-metals are solids at room temperature."),
    C("l", "liquid", "is a liquid at room temperature", "are both liquids at room temperature", "Which is a liquid at room temperature", "Only mercury and bromine are liquid elements at room temperature."),
    C("g", "gas", "is a gas at room temperature", "are both gases at room temperature", "Which is a gas at room temperature", "Oxygen, nitrogen, hydrogen, chlorine and helium are gases."),
], [R(x, STATE.get(x, "s")) for x in METALS + NONM if x != "carbon"], art="")
PROPS = [("is lustrous (shiny)", "Metals have lustre; sulphur is dull."),
         ("can be beaten into thin sheets", "Metals are malleable; sulphur breaks into powder."),
         ("can be drawn into wires", "Metals are ductile; sulphur crumbles."),
         ("makes a ringing sound when struck", "Metals are sonorous; non-metals like sulphur are not."),
         ("conducts electricity well", "Metals conduct electricity; sulphur does not."),
         ("conducts heat well", "Metals conduct heat; sulphur is a poor conductor.")]
for el in ["iron", "copper", "aluminium", "gold", "silver", "sulphur"]:
    for p, why in PROPS:
        T(SK, 2, f"{cap(el)} {p}.", el != "sulphur", why, S)
for el, isM in [("magnesium", True), ("sodium", True), ("calcium", True), ("sulphur", False), ("carbon", False), ("phosphorus", False)]:
    why = "Metal oxides are basic." if isM else "Non-metal oxides are acidic."
    F(SK, 3, f"The oxide of {el} is dissolved in water. What does it do to red litmus?", "turns it blue" if isM else "leaves it red",
      ["leaves it red" if isM else "turns it blue", "turns it green"], why, S)
    F(SK, 3, f"The oxide of {el} is dissolved in water. What does it do to blue litmus?", "leaves it blue" if isM else "turns it red",
      ["turns it red" if isM else "leaves it blue", "turns it yellow"], why, S)
for q, a, w, why in [
    ("Which metal is used for electric wires?", "copper", ["sulphur", "iodine", "mercury"], "Copper is a very good conductor and easily drawn into wires."),
    ("Which metal is used as foil to wrap food?", "aluminium", ["mercury", "sodium", "lead"], "Aluminium is light and beaten into thin foil."),
    ("Which non-metal do we need to breathe?", "oxygen", ["nitrogen", "chlorine", "helium"], "Our cells use oxygen to get energy from food."),
    ("Which non-metal is used to kill germs in water?", "chlorine", ["helium", "nitrogen", "sulphur"], "Chlorine kills germs in drinking water and pools."),
    ("Tincture of ___ is put on wounds.", "iodine", ["chlorine", "bromine", "sulphur"], "Tincture of iodine is an antiseptic."),
    ("Which metal is used for jewellery?", "gold", ["iron", "sodium", "mercury"], "Gold is shiny and does not rust or tarnish."),
    ("Which metal was used in old thermometers?", "mercury", ["iron", "gold", "copper"], "Mercury is a liquid metal that expands evenly with heat."),
    ("Which metal burns with a dazzling white light?", "magnesium", ["gold", "copper", "mercury"], "Magnesium ribbon burns brightly to form magnesium oxide."),
    ("Which metal is stored in kerosene?", "sodium", ["gold", "iron", "copper"], "Sodium reacts fast with air, so kerosene keeps it safe."),
    ("Pencil lead is a form of ___.", "carbon", ["lead", "iron", "sulphur"], "Pencil lead is graphite, a form of carbon."),
    ("Which gas fills balloons that float up?", "helium", ["oxygen", "chlorine", "carbon dioxide"], "Helium is much lighter than air."),
    ("Most metals at room temperature are ___.", "solid", ["liquid", "gas"], "Mercury is the only liquid metal at room temperature."),
    ("Metals that can be beaten into sheets are ___.", "malleable", ["ductile", "brittle", "sonorous"], "Malleable means it can be beaten into thin sheets."),
    ("Metals that can be drawn into wires are ___.", "ductile", ["malleable", "brittle", "sonorous"], "Ductile means it can be drawn into thin wires."),
    ("Metals that ring when struck are ___.", "sonorous", ["ductile", "brittle", "malleable"], "Sonorous means it makes a ringing sound."),
    ("Non-metals that break easily into pieces are ___.", "brittle", ["ductile", "malleable", "sonorous"], "Brittle things break into pieces when hit."),
    ("School bells are made of metal because metals are ___.", "sonorous", ["brittle", "dull", "soft"], "Metals ring loudly when struck."),
    ("Oxides of metals are usually ___.", "basic", ["acidic", "neutral"], "Metal oxides dissolve in water to form bases."),
    ("Oxides of non-metals are usually ___.", "acidic", ["basic", "neutral"], "Non-metal oxides dissolve in water to form acids."),
]:
    F(SK, 1, q, a, w, why, S)

# ---- sc7.changes (CU7 ch5 Changes Around Us: Physical and Chemical)
S = "CU7 ch5"
SK = "sc7.changes"
PH = [  # x, why, reversible (True / False / None = don't ask)
    ("ice melting", "Melting only changes state; it is still water.", True, "snow"),
    ("water freezing", "Freezing only changes state; it is still water.", True, "fridge"),
    ("water boiling", "Steam is still water, only in gas form.", True, "kettle"),
    ("sugar dissolving", "The sugar is still there; evaporate the water to get it.", True, ""),
    ("salt dissolving", "The salt is still there; evaporate the water to get it.", True, ""),
    ("tearing paper", "Torn paper is still paper; no new substance forms.", False, "book"),
    ("folding paper", "Folded paper is still paper; only its shape changes.", None, ""),
    ("breaking glass", "Broken glass is still glass; no new substance forms.", False, "glass"),
    ("cutting vegetables", "Cut pieces are still the same vegetable.", False, "knife"),
    ("stretching rubber band", "A stretched band is still rubber and springs back.", True, ""),
    ("crushing a can", "A crushed can is still the same metal.", None, ""),
    ("melting wax", "Melted wax is still wax and hardens again.", True, "candle"),
    ("chopping wood", "Chopped wood is still wood; only its size changes.", False, "axe"),
    ("blowing up a balloon", "The balloon only stretches; no new substance forms.", True, "balloon"),
    ("sharpening a pencil", "Shavings are still wood; no new substance forms.", False, "sharpener"),
    ("grinding wheat to flour", "Flour is still wheat in tiny pieces.", False, ""),
    ("dew forming", "Dew is water vapour turned back into liquid water.", None, "drop"),
    ("melting butter", "Melted butter is still butter and sets again.", True, ""),
    ("making salt crystals", "Crystals of salt are still salt.", None, ""),
]
CHM = [
    ("burning paper", "Burning makes ash, smoke and gases, which are new substances.", "fire"),
    ("burning wood", "Burning wood makes ash and gases, which are new substances.", "fire"),
    ("iron rusting", "Rust is a new substance made from iron, air and water.", ""),
    ("boiling an egg", "Heat changes the egg's substances; it cannot become raw again.", "egg"),
    ("milk turning to curd", "Curd is a new substance made from milk.", "curd"),
    ("fruit ripening", "Ripening makes new substances that change taste and colour.", "banana"),
    ("fruit rotting", "Rotting breaks fruit into new substances.", "apple"),
    ("digesting food", "Digestion breaks food into new, simpler substances.", "stomach"),
    ("baking a cake", "Baking makes new substances; a cake cannot turn back to batter.", "cake"),
    ("burning magnesium ribbon", "Burning magnesium makes a new white powder, magnesium oxide.", ""),
    ("burning coal", "Burning coal makes new gases and ash.", "fire"),
    ("vinegar with baking soda", "Vinegar and baking soda make carbon dioxide gas.", ""),
    ("silver tarnishing", "A dark new layer forms on silver.", "spoon"),
    ("copper turning green", "A green new coating forms on copper in moist air.", ""),
    ("lighting a firecracker", "Burning makes light, sound, smoke and new substances.", ""),
    ("burning a matchstick", "Burning makes ash and gases, which are new substances.", ""),
    ("petrol burning in a car", "Burning petrol makes new gases.", "car"),
    ("photosynthesis in leaves", "Leaves make new substances, glucose and oxygen.", "leaf"),
]
table("change", S, "{X}: physical or chemical change?", [
    C("p", "physical", "is a physical change", "are both physical changes", "Which is a physical change", "A physical change makes no new substance."),
    C("c", "chemical", "is a chemical change", "are both chemical changes", "Which is a chemical change", "A chemical change makes one or more new substances."),
], [R(x, "p", why, pic=p) for x, why, _, p in PH] + [R(x, "c", why, pic=p) for x, why, p in CHM], art="")
REV = ["physical, reversible", "physical, irreversible", "chemical"]
for x, why, rev, _ in PH:
    if rev is None:
        continue
    a = REV[0] if rev else REV[1]
    F(SK, 3, f"{cap(x)}: which kind of change is it?", a, [r for r in REV if r != a], why, S)
for x, why, _ in CHM:
    F(SK, 3, f"{cap(x)}: which kind of change is it?", "chemical", REV[:2], why, S)
RUST = [("in dry air with calcium chloride", "no, no water"), ("in boiled water with oil on top", "no, no air"),
        ("in tap water, open to the air", "yes, it rusts"), ("painted and kept in moist air", "no, it is coated"),
        ("coated with zinc, in moist air", "no, it is coated"), ("left outside in the rain", "yes, it rusts"),
        ("in a humid seaside town", "yes, it rusts"), ("greased and kept in moist air", "no, it is coated")]
RWHY2 = {"no, no water": "Rusting needs water; calcium chloride keeps the air dry.",
         "no, no air": "Boiled water with oil on top keeps air away.",
         "yes, it rusts": "Iron with both air and water rusts.",
         "no, it is coated": "A coating keeps air and water away from the iron."}
for cond, a in RUST:
    F(SK, 3, f"An iron nail is kept {cond}. Will it rust?", a, [v for v in RWHY2 if v != a], RWHY2[a], S)
for q, a, w, why in [
    ("Rusting needs iron, water and ___.", "oxygen", ["nitrogen", "sunlight", "salt"], "Iron reacts with oxygen and water to form rust."),
    ("Coating iron with zinc is called ___.", "galvanisation", ["crystallisation", "evaporation", "rusting"], "Galvanisation puts a zinc layer on iron to stop rust."),
    ("Getting pure, large salt crystals from a solution is ___.", "crystallisation", ["galvanisation", "rusting", "burning"], "Crystallisation gives pure crystals as the solution cools."),
    ("Which is a sign of a chemical change?", "gas bubbles form", ["it changes shape", "it is cut up", "it is folded"], "New gases show that a new substance has formed."),
    ("Vinegar and baking soda make bubbles of ___.", "carbon dioxide", ["oxygen", "hydrogen", "nitrogen"], "This reaction gives off carbon dioxide gas."),
    ("Lime water turns milky with ___.", "carbon dioxide", ["oxygen", "nitrogen", "hydrogen"], "Carbon dioxide turns lime water milky."),
    ("Burning magnesium ribbon makes a white powder called ___.", "magnesium oxide", ["rust", "salt", "chalk"], "Magnesium joins with oxygen to make magnesium oxide."),
    ("Rust is mainly ___.", "iron oxide", ["zinc", "copper", "magnesium oxide"], "Rust forms when iron joins with oxygen and water."),
]:
    F(SK, 1, q, a, w, why, S)
for s, v, why in [
    ("Iron rusts faster near the sea.", True, "Moist, salty air speeds up rusting."),
    ("Rust makes iron stronger.", False, "Rust flakes off and weakens iron."),
    ("All physical changes can be reversed.", False, "Torn paper or broken glass cannot be made whole again."),
    ("A chemical change forms new substances.", True, "New substances are the sign of a chemical change."),
    ("Painting an iron gate helps stop rusting.", True, "Paint keeps air and water away from the iron."),
]:
    T(SK, 1, s, v, why, S)

# ---- sc7.heatFlow (CU7 ch7 Heat Transfer in Nature)
S = "CU7 ch7"
SK = "sc7.heatFlow"
table("heatWay", S, "{Np}: conduction, convection or radiation?", [
    C("cd", "conduction", "happens by conduction", "both happen by conduction", "Which happens by conduction", "In conduction, heat passes through a solid from hot to cold parts."),
    C("cv", "convection", "happens by convection", "both happen by convection", "Which happens by convection", "In convection, warm liquid or gas rises and carries heat."),
    C("rd", "radiation", "happens by radiation", "both happen by radiation", "Which happens by radiation", "Radiation carries heat without touching, even through empty space."),
], [
    R("spoon in hot tea", "cd", np="a spoon in hot tea getting hot", pic="spoon"), R("hot pan handle", "cd", np="a steel pan's handle getting hot", pic="pan"),
    R("heated iron rod", "cd", np="the far end of a heated iron rod getting hot"), R("ironing clothes", "cd", np="a hot iron warming clothes"),
    R("hand on a hot cup", "cd", np="your hand warming on a hot cup", pic="cup"), R("ice melting in hand", "cd", np="an ice cube melting in your hand", pic="hand"),
    R("roti on a hot tawa", "cd", np="a roti cooking on a hot tawa", pic="tawa"), R("wax on a heated rod", "cd", np="wax melting along a rod heated at one end"),
    R("sea breeze", "cv", np="a sea breeze blowing in the day", pic="wave"), R("land breeze", "cv", np="a land breeze blowing at night", pic="wind"),
    R("water heating in a pot", "cv", np="water moving round as it heats in a pot", pic="pot"), R("smoke rising up chimney", "cv", np="smoke rising up a chimney"),
    R("hands above a fire", "cv", np="hands held above a fire warming up", pic="fire"), R("hot air balloon rising", "cv", np="a hot air balloon rising", pic="balloon"),
    R("air leaving ventilators", "cv", np="warm air leaving through ventilators near the ceiling", pic="window"),
    R("warmth of the Sun", "rd", np="the Sun's heat reaching Earth", pic="sun"), R("warmth beside a bonfire", "rd", np="feeling warm sitting beside a bonfire", pic="fire"),
    R("sunlight warming a road", "rd", np="sunlight warming a road", pic="sun"), R("skin warm in sunshine", "rd", np="your skin warming in sunshine", pic="sun"),
    R("sunlight on solar cooker", "rd", np="sunlight heating a solar cooker", pic="sun"),
])
table("heatCond", S, "Is {np} a good or a poor conductor of heat?", [
    C("good", "good conductor", "is a good conductor of heat", "are both good conductors of heat", "Which is a good conductor of heat", "Metals pass heat through them quickly."),
    C("poor", "poor conductor", "is a poor conductor of heat", "are both poor conductors of heat", "Which is a poor conductor of heat", "Poor conductors, or insulators, pass heat slowly."),
], [R(x, "good") for x in ["copper", "aluminium", "iron", "steel", "silver", "brass"]]
 + [R(x, "poor", "Still air is a poor conductor of heat." if x == "air" else "") for x in ["wood", "plastic", "air", "wool", "cotton cloth", "glass", "rubber", "thermocol", "cork", "paper"]], art="")
for q, a, w, why in [
    ("In the day, the breeze near a beach blows from ___.", "sea to land", ["land to sea", "nowhere"], "Land heats faster, so warm air over it rises."),
    ("At night, the breeze near a beach blows from ___.", "land to sea", ["sea to land", "nowhere"], "Land cools faster, so warmer air over the sea rises."),
    ("Pan handles are made of plastic or wood because these are ___.", "poor conductors of heat", ["good conductors of heat", "shiny materials", "magnetic"], "Poor conductors stop heat reaching your hand."),
    ("In summer, it is cooler to wear ___ clothes.", "light-coloured", ["dark-coloured", "black"], "Light colours reflect more heat; dark colours absorb more."),
    ("Which absorbs more heat in sunlight?", "a black cloth", ["a white cloth", "a mirror"], "Dark surfaces absorb more heat than light ones."),
    ("Woollen clothes keep us warm because wool traps ___.", "air", ["water", "light", "smoke"], "Trapped air is a poor conductor, so body heat stays in."),
    ("Heat always flows from ___.", "hotter to colder", ["colder to hotter", "big to small"], "Heat moves from a hotter body to a colder one."),
    ("Which way of heat transfer needs no medium at all?", "radiation", ["conduction", "convection"], "Radiation can cross empty space, like sunlight does."),
    ("Convection happens in ___.", "liquids and gases", ["solids only", "empty space"], "Only liquids and gases can flow to carry heat."),
    ("Conduction happens mainly in ___.", "solids", ["gases", "empty space"], "Heat passes from particle to particle in solids."),
    ("Why are cooking pots made of metal?", "metals conduct heat well", ["metals are light", "metals are cheap"], "Metals let heat pass quickly to the food."),
    ("Why do ventilators sit near the ceiling?", "warm air rises", ["cold air rises", "light comes in"], "Warm air rises by convection and leaves from the top."),
]:
    F(SK, 2, q, a, w, why, S)

# ---- sc7.speed (CU7 ch8 Measurement of Time and Motion)
S = "CU7 ch8"
SK = "sc7.speed"
MOVERS = [
    {"x": "bus", "np": "a bus", "unit": "km/h", "du": "km", "tu": "hour", "speeds": [30, 40, 45, 50, 60], "times": [1, 2, 3, 4, 5, 6, 7, 8], "pic": "bus"},
    {"x": "car", "np": "a car", "unit": "km/h", "du": "km", "tu": "hour", "speeds": [40, 50, 60, 70, 80, 90], "times": [1, 2, 3, 4, 5, 6], "pic": "car"},
    {"x": "train", "np": "a train", "unit": "km/h", "du": "km", "tu": "hour", "speeds": [50, 60, 75, 80, 90, 100, 120], "times": [1, 2, 3, 4, 5, 6, 8, 10], "pic": "train"},
    {"x": "cyclist", "np": "a cyclist", "unit": "km/h", "du": "km", "tu": "hour", "speeds": [10, 12, 15, 16, 18, 20], "times": [1, 2, 3, 4, 5], "pic": "bicycle"},
    {"x": "walker", "np": "a person walking", "unit": "km/h", "du": "km", "tu": "hour", "speeds": [3, 4, 5, 6], "times": [1, 2, 3, 4], "pic": "foot"},
    {"x": "bullock cart", "np": "a bullock cart", "unit": "km/h", "du": "km", "tu": "hour", "speeds": [4, 5, 6], "times": [1, 2, 3, 4, 5], "pic": "ox"},
    {"x": "auto-rickshaw", "np": "an auto-rickshaw", "unit": "km/h", "du": "km", "tu": "hour", "speeds": [20, 25, 30, 40], "times": [1, 2, 3], "pic": "auto"},
    {"x": "runner", "np": "a runner", "unit": "m/s", "du": "m", "tu": "second", "speeds": [2, 3, 4, 5, 6, 7, 8], "times": [10, 20, 30, 40, 50, 60, 80, 100], "pic": ""},
]
for m in MOVERS:
    m["src"] = S
for q, a, w, why in [
    ("Speed is the distance moved in one unit of ___.", "time", ["mass", "length", "temperature"], "Speed tells how far something goes each second or hour."),
    ("The SI unit of speed is ___.", "metre per second", ["kilometre", "second", "metre"], "Speed is distance over time, so metres per second."),
    ("Speed = ___.", "distance ÷ time", ["time ÷ distance", "distance × time"], "Speed is the distance covered divided by the time taken."),
    ("Which instrument in a car shows its speed?", "speedometer", ["odometer", "thermometer"], "A speedometer shows speed, usually in km/h."),
    ("Which instrument in a car shows the distance travelled?", "odometer", ["speedometer", "thermometer"], "An odometer adds up the distance covered."),
    ("Covering equal distances in equal times is ___ motion.", "uniform", ["non-uniform", "oscillatory"], "Uniform motion keeps the same speed all the time."),
    ("A bus in busy city traffic usually has ___ motion.", "non-uniform", ["uniform", "oscillatory"], "In traffic, speed keeps changing, so motion is non-uniform."),
]:
    F(SK, 1, q, a, w, why, S)

# ---- sc7.timePendulum (CU7 ch8)
SK = "sc7.timePendulum"
for q, a, w, why in [
    ("One complete to-and-fro swing of a pendulum is an ___.", "oscillation", ["orbit", "echo", "eclipse"], "One full swing there and back is one oscillation."),
    ("Time taken for one oscillation is the ___.", "time period", ["speed", "length", "frequency of a bus"], "The time period is the time for one full swing."),
    ("A longer pendulum has a ___ time period.", "longer", ["shorter", "same"], "The longer the string, the slower each swing."),
    ("Same length, but a heavier bob: the time period is ___.", "the same", ["longer", "shorter"], "The time period depends on length, not on the bob's mass."),
    ("A sundial tells time using a ___.", "shadow", ["pendulum", "water drip", "magnet"], "The shadow on a sundial moves as the Sun moves."),
    ("A sand clock is also called an ___.", "hourglass", ["odometer", "sundial", "abacus"], "Sand falls through a narrow neck in a set time."),
    ("Ancient India used a bowl that sinks slowly in water to tell time. It is a ___.", "water clock", ["sundial", "hourglass", "pendulum clock"], "The ghatika bowl sank in a fixed time."),
    ("The SI unit of time is the ___.", "second", ["minute", "hour", "day"], "Time is measured in seconds in the SI system."),
    ("How many seconds are in one hour?", "3600", ["360", "600", "6000"], "60 minutes × 60 seconds = 3600 seconds."),
    ("To find a time period, it is better to time ___.", "20 oscillations", ["half a swing", "one swing only"], "Timing many swings and dividing gives a more exact answer."),
]:
    F(SK, 1, q, a, w, why, S, pic="clock" if "clock" in q or "time" in q else "")

# ---- sc7.animalLife (CU7 ch9 Life Processes in Animals)
S = "CU7 ch9"
SK = "sc7.animalLife"
GUT = ["mouth", "food pipe", "stomach", "small intestine", "large intestine", "anus"]
GWHY = "Mouth, food pipe, stomach, small intestine, large intestine, then anus."
O(SK, 2, "Put these in the order food passes through them.", GUT, GWHY, S)
CH(SK, id="gut", items=GUT, art="the ", t=2, src=S, why=GWHY,
   next="Food leaves the {x}. Where does it go next?", prev="Where is food just before it reaches the {x}?",
   adj="", cmp="Food reaches the {a} before the {b}.", cmpWhy="The {a} is stop {i} and the {b} is stop {j}.", pos="", cyclic=False)
AIR = ["nostrils", "nasal cavity", "windpipe", "lungs"]
O(SK, 2, "Put these in the order air passes through them.", AIR, "Air passes nostrils, nasal cavity and windpipe to reach the lungs.", S)
table("organJob", S, "Which part does this: {np}?", [
    C("mouth", "mouth", "happens in the mouth", "both happen in the mouth", "Which happens in the mouth", "Teeth chew food and saliva starts digesting starch in the mouth."),
    C("pipe", "food pipe", "is the job of the food pipe", "", "Which is a job of the food pipe", "The food pipe pushes food down by wave-like movements."),
    C("stom", "stomach", "happens in the stomach", "both happen in the stomach", "Which happens in the stomach", "The stomach mixes food with acid and digestive juices."),
    C("si", "small intestine", "happens in the small intestine", "both happen in the small intestine", "Which happens in the small intestine", "The small intestine completes digestion and absorbs food into blood."),
    C("li", "large intestine", "happens in the large intestine", "", "Which happens in the large intestine", "The large intestine absorbs water from undigested food."),
    C("liver", "liver", "is the job of the liver", "", "Which is a job of the liver", "The liver, the largest gland, makes bile."),
    C("panc", "pancreas", "is the job of the pancreas", "", "Which is a job of the pancreas", "The pancreas makes pancreatic juice for digestion."),
], [
    R("chewing food", "mouth", np="chewing and grinding food", pic="tooth"), R("saliva digesting starch", "mouth", np="saliva beginning to digest starch", pic="mouth"),
    R("tasting food", "mouth", np="tasting food with the tongue", pic="tongue"),
    R("moving food to stomach", "pipe", np="pushing food down to the stomach"),
    R("mixing food with acid", "stom", np="mixing food with acid and juices", pic="stomach"), R("acid killing germs", "stom", np="acid killing germs in food", pic="stomach"),
    R("absorbing digested food", "si", np="absorbing digested food into blood"), R("finishing digestion", "si", np="completing the digestion of food"),
    R("taking water from waste", "li", np="absorbing water from undigested food"),
    R("making bile", "liver", np="making bile"), R("making pancreatic juice", "panc", np="making pancreatic juice"),
], art="")
table("breathe", S, "How does {np} breathe?", [
    C("lungs", "lungs", "breathes using lungs", "both breathe using lungs", "Which breathes using lungs", "Mammals, birds and reptiles breathe air using lungs."),
    C("gills", "gills", "breathes using gills", "both breathe using gills", "Which breathes using gills", "Gills take in oxygen dissolved in water."),
    C("skin", "moist skin", "breathes through its moist skin", "both breathe through moist skin", "Which breathes through its skin", "Some animals take in oxygen through a moist skin."),
    C("spir", "spiracles", "breathes through spiracles", "both breathe through spiracles", "Which breathes through spiracles", "Insects take in air through tiny holes called spiracles."),
], [
    R("human", "lungs", pic="lungs"), R("cow", "lungs", pic="cow"), R("whale", "lungs", "A whale is a mammal; it breathes air with lungs.", pic="whale"),
    R("dolphin", "lungs", "A dolphin is a mammal; it surfaces to breathe with lungs.", pic="dolphin"), R("sparrow", "lungs", pic="sparrow"),
    R("pigeon", "lungs", pic="pigeon"), R("snake", "lungs", pic="snake"), R("crocodile", "lungs", pic="crocodile"), R("tortoise", "lungs", pic="turtle"),
    R("frog", "lungs", "A frog breathes with lungs, and also through moist skin.", also=["skin"], pic="frog"),
    R("fish", "gills", pic="fish"), R("tadpole", "gills", "A tadpole lives in water and breathes with gills.", pic="tadpole"),
    R("crab", "gills", pic="crab"), R("prawn", "gills", pic="prawn"),
    R("earthworm", "skin", "An earthworm breathes through its moist skin.", pic="earthworm"), R("leech", "skin"),
    R("cockroach", "spir", pic="cockroach"), R("grasshopper", "spir", pic="grasshopper"), R("housefly", "spir", pic="housefly"),
    R("ant", "spir", pic="ant"), R("butterfly", "spir", pic="butterfly"), R("mosquito", "spir", pic="mosquito"),
])
for q, a, w, why, pic in [
    ("Air we breathe out has more ___ than air we breathe in.", "carbon dioxide", ["oxygen", "dust"], "Our cells give out carbon dioxide, which we breathe out.", "lungs"),
    ("Lime water turns milky with the air we ___.", "breathe out", ["breathe in", "keep in a fridge"], "Breathed-out air has extra carbon dioxide.", "testtube"),
    ("When we breathe in, the chest ___.", "expands", ["shrinks", "stays still"], "Ribs move up and out, making the chest bigger.", "lungs"),
    ("When we breathe in, the diaphragm moves ___.", "down", ["up", "sideways"], "The diaphragm flattens and moves down to let air in.", "lungs"),
    ("In cows, swallowed grass is first stored in the ___.", "rumen", ["small intestine", "mouth", "liver"], "Cows store grass in the rumen and later chew the cud.", "cow"),
    ("Amoeba takes in food using ___.", "false feet", ["gills", "teeth", "a tongue"], "Amoeba wraps food with false feet, called pseudopodia.", ""),
    ("While running, our breathing rate ___.", "increases", ["decreases", "stops"], "Muscles need more oxygen, so we breathe faster.", "lungs"),
    ("Finger-like parts lining the small intestine are ___.", "villi", ["teeth", "air sacs", "gills"], "Villi give a large surface to absorb digested food.", ""),
    ("The largest gland in our body is the ___.", "liver", ["pancreas", "stomach", "heart"], "The liver is the largest gland and makes bile.", ""),
    ("Which teeth bite and cut food?", "incisors", ["canines", "molars"], "Incisors are the sharp, flat front teeth.", "tooth"),
    ("Which teeth tear food?", "canines", ["incisors", "molars"], "Canines are pointed teeth for tearing.", "tooth"),
    ("Which teeth grind food?", "molars", ["incisors", "canines"], "Molars at the back have broad surfaces for grinding.", "tooth"),
    ("Chewing the cud means ___.", "chewing food again", ["drinking water", "sleeping"], "Cows bring back stored grass to chew it again.", "cow"),
    ("Food is pushed along the food pipe by ___.", "wave-like movements", ["gravity alone", "the tongue"], "Muscles in the food pipe squeeze food down in waves.", ""),
]:
    F(SK, 1, q, a, w, why, S, pic=pic)

# ---- sc7.plantLife (CU7 ch10 Life Processes in Plants)
S = "CU7 ch10"
SK = "sc7.plantLife"
table("plantPart", S, "Which part does this: {np}?", [
    C("rh", "root hairs", "is the job of the root hairs", "are both jobs of the root hairs", "Which is a job of the root hairs", "Root hairs take in water and minerals from the soil."),
    C("xy", "xylem", "is the job of the xylem", "are both jobs of the xylem", "Which is a job of the xylem", "Xylem carries water and minerals up from the roots."),
    C("ph", "phloem", "is the job of the phloem", "", "Which is a job of the phloem", "Phloem carries food from the leaves to all parts."),
    C("st", "stomata", "is the job of the stomata", "are both jobs of the stomata", "Which is a job of the stomata", "Stomata are tiny pores that let gases and vapour pass."),
    C("ch", "chlorophyll", "is the job of chlorophyll", "are both jobs of chlorophyll", "Which is a job of chlorophyll", "Chlorophyll is the green pigment that traps sunlight."),
    C("gc", "guard cells", "is the job of the guard cells", "", "Which is a job of the guard cells", "Guard cells open and close each stoma."),
], [R("taking in soil water", "rh", np="absorbing water from the soil", pic="roots"), R("taking in minerals", "rh", np="absorbing minerals from the soil", pic="roots"),
    R("carrying water upward", "xy", np="carrying water up to the leaves"), R("carrying minerals up", "xy", np="carrying minerals up from the roots"),
    R("carrying food around", "ph", np="carrying food from leaves to other parts"),
    R("gas exchange in leaves", "st", np="letting gases in and out of leaves", pic="leaf"), R("letting water vapour out", "st", np="letting water vapour out of leaves", pic="leaf"),
    R("trapping sunlight", "ch", np="trapping sunlight to make food", pic="sun"), R("making leaves green", "ch", np="making leaves green", pic="leaf"),
    R("opening the stomata", "gc", np="opening and closing the stomata")], art="")
table("plantOrgan", S, "Which part of a plant does this: {np}?", [
    C("root", "roots", "is a job of the roots", "are both jobs of the roots", "Which is a job of the roots", "Roots hold the plant and take in water."),
    C("stem", "stem", "is a job of the stem", "are both jobs of the stem", "Which is a job of the stem", "The stem holds the plant up and carries water and food."),
    C("leaf", "leaves", "is a job of the leaves", "are both jobs of the leaves", "Which is a job of the leaves", "Leaves make food and have most of the stomata."),
    C("flower", "flower", "is a job of the flower", "are both jobs of the flower", "Which is a job of the flower", "Flowers attract insects and make seeds and fruits."),
], [R("holding plant in soil", "root", np="holding the plant firmly in the soil", pic="roots"), R("absorbing soil water", "root", np="absorbing water from the soil", pic="roots"),
    R("holding up leaves", "stem", np="holding up leaves and flowers", pic="sapling"), R("linking roots to leaves", "stem", np="carrying water from roots to leaves", pic="sapling"),
    R("making most of the food", "leaf", np="making most of the plant's food", pic="leaf"), R("having most stomata", "leaf", np="having most of the stomata", pic="leaf"),
    R("making seeds", "flower", np="making seeds and fruits", pic="flower"), R("attracting insects", "flower", np="attracting insects with colour and smell", pic="flower")], art="")
table("photo", S, "In photosynthesis, is {np} needed or produced?", [
    C("in", "needed", "is needed for photosynthesis", "are both needed for photosynthesis", "Which is needed for photosynthesis", "Plants need carbon dioxide, water, sunlight and chlorophyll to make food."),
    C("out", "produced", "is produced in photosynthesis", "are both produced in photosynthesis", "Which is produced in photosynthesis", "Photosynthesis makes glucose, stored as starch, and gives out oxygen."),
], [R("carbon dioxide", "in"), R("water", "in", pic="drop"), R("sunlight", "in", pic="sun"), R("chlorophyll", "in", pic="leaf"),
    R("oxygen", "out", "Leaves give out oxygen while making food."), R("glucose", "out"), R("starch", "out", "Glucose made in leaves is stored as starch.")], art="")
LIGHT = [("in sunlight", True), ("in the dark", False)]
CO2 = [("in normal air", True), ("with carbon dioxide removed", False)]
PART = [("a green part", True), ("a white part", False)]
for ln, lv in LIGHT:
    for cn, cv in CO2:
        for pn, pv in PART:
            ok = lv and cv and pv
            if ok:
                why = "Light, carbon dioxide and chlorophyll were all there, so starch formed."
            elif not lv:
                why = "Without sunlight, no food and no starch is made."
            elif not pv:
                why = "The white part has no chlorophyll, so no starch forms."
            else:
                why = "Without carbon dioxide, the leaf cannot make food."
            T(SK, 3, f"A destarched plant with green-and-white leaves is {ln} {cn}. Iodine turns {pn} of its leaf blue-black.", ok, why, S, pic="leaf")
            miss = [n for n, v in (("no sunlight", lv), ("no carbon dioxide", cv), ("no chlorophyll", pv)) if not v]
            if len(miss) == 1:
                F(SK, 3, f"A destarched plant is {ln} {cn}. Iodine on {pn} of a leaf shows no blue-black. Why?", miss[0],
                  [m for m in ["no sunlight", "no carbon dioxide", "no chlorophyll", "too much water"] if m != miss[0]][:3], why, S, pic="leaf")
for q, a, w, why in [
    ("Plants make their food by ___.", "photosynthesis", ["respiration", "digestion", "transpiration"], "Photosynthesis means making food using light."),
    ("Loss of water vapour from leaves is called ___.", "transpiration", ["photosynthesis", "condensation", "respiration"], "Water vapour escapes from leaves through the stomata."),
    ("A plastic bag over a leafy twig gets water drops inside. Why?", "transpiration", ["rain", "photosynthesis"], "Leaves give out water vapour, which condenses on the bag."),
    ("Plants store extra food as ___.", "starch", ["protein", "salt", "oxygen"], "Glucose made in leaves is stored as starch."),
    ("The iodine test on a leaf shows ___.", "starch", ["oxygen", "water", "carbon dioxide"], "Iodine turns blue-black where starch is present."),
    ("Plants respire ___.", "all day and night", ["only at night", "only in sunlight"], "Plants respire all the time to get energy."),
    ("Roots get oxygen from ___.", "air spaces in soil", ["sunlight", "flowers", "fruits"], "Soil has tiny air spaces that give roots oxygen."),
    ("Transpiration helps the plant by ___.", "pulling water up", ["making seeds", "trapping light"], "Water lost from leaves pulls more water up the xylem."),
    ("Tiny pores mostly on the underside of leaves are ___.", "stomata", ["root hairs", "veins", "petals"], "Stomata let gases in and water vapour out."),
    ("Plants that make their own food are called ___.", "autotrophs", ["heterotrophs", "parasites"], "Auto means self, so autotrophs feed themselves."),
    ("Why can an overwatered pot plant die?", "roots get no air", ["roots get too much light", "leaves get too cold"], "Waterlogged soil has no air spaces for the roots."),
    ("Which gas do leaves give out during photosynthesis?", "oxygen", ["carbon dioxide", "nitrogen", "helium"], "Leaves give out oxygen while making food."),
]:
    F(SK, 1, q, a, w, why, S)

# ---- sc7.light (CU7 ch11 Light: Shadows and Reflections)
S = "CU7 ch11"
SK = "sc7.light"
SAME = set("AHIMOTUVWXY")
table("mirrorLetter", S, "The capital letter {x} in a plane mirror: same or changed?", [
    C("same", "same", "looks the same in a plane mirror", "both look the same in a plane mirror", "Which looks the same in a mirror", "Letters with matching left and right halves look the same."),
    C("chg", "changed", "looks changed in a plane mirror", "both look changed in a plane mirror", "", "A mirror swaps left and right, so lopsided letters look changed."),
], [R(ch, "same" if ch in SAME else "chg", np=f"the letter {ch}") for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"], card="Letter {X}")
table("shadow", S, "In torchlight, what shadow does {np} make?", [
    C("dark", "dark shadow", "makes a dark shadow", "both make dark shadows", "Which makes a dark shadow", "Opaque things block all light and make dark shadows."),
    C("faint", "faint or no shadow", "makes a faint shadow or none", "", "", "Light passes through clear or translucent things, so shadows are faint."),
], [R(x, "dark", np=n, pic=p) for x, n, p in [("wooden board", "a wooden board", ""), ("cardboard", "cardboard", ""), ("book", "a book", "book"), ("stone", "a stone", "stone"),
     ("steel plate", "a steel plate", "plate"), ("brick", "a brick", ""), ("aluminium foil", "aluminium foil", ""), ("your hand", "your hand", "hand"), ("red ball", "a red ball", "ball")]]
 + [R(x, "faint", np=n, pic=p) for x, n, p in [("clear glass sheet", "a clear glass sheet", "window"), ("clear plastic sheet", "a clear plastic sheet", ""),
     ("butter paper", "butter paper", ""), ("tracing paper", "tracing paper", ""), ("frosted glass", "frosted glass", ""), ("tissue paper", "tissue paper", "")]])
table("luminous", S, "Is {np} luminous or non-luminous?", [
    C("lum", "luminous", "gives out its own light", "both give out their own light", "Which gives out its own light", "Luminous things, like the Sun and flames, make their own light."),
    C("non", "non-luminous", "has no light of its own", "", "", "Non-luminous things are seen only by light they reflect."),
], [R("Sun", "lum", np="the Sun", pic="sun"), R("candle flame", "lum", pic="candle"), R("glowing bulb", "lum", pic="bulb"), R("firefly", "lum"),
    R("star", "lum", pic="star"), R("burning matchstick", "lum", pic="fire"), R("lit torch", "lum", pic="torch"),
    R("Moon", "non", "The Moon only reflects sunlight; it has no light of its own.", np="the Moon", pic="moon"),
    R("mirror", "non", "A mirror reflects light but makes none.", pic="mirror"), R("book", "non", pic="book"),
    R("switched-off bulb", "non", pic="bulb"), R("wall", "non"), R("chair", "non", pic="chair"), R("planet Venus", "non", "Venus shines only by reflecting sunlight.", np="the planet Venus", pic="planet")])
for q, a, w, why, pic in [
    ("Light travels in ___.", "straight lines", ["curves", "circles", "zigzags"], "That is why shadows have sharp edges.", "torch"),
    ("An image in a plane mirror is ___.", "upright and same size", ["upside down", "much smaller", "much bigger"], "A plane mirror gives an upright image of the same size.", "mirror"),
    ("In a mirror, your raised right hand looks like a ___.", "left hand", ["right hand", "foot"], "A mirror swaps left and right.", "mirror"),
    ("This left-right swap in a mirror is called ___.", "lateral inversion", ["refraction", "shadow", "eclipse"], "Lateral means sideways, and inversion means swapped.", "mirror"),
    ("Why is AMBULANCE written in reverse on the front?", "to read in car mirrors", ["to look nice", "to save paint"], "Drivers see it the right way round in their mirrors.", "mirror"),
    ("The image in a pinhole camera is ___.", "upside down", ["upright", "always bigger"], "Light rays cross at the pinhole, so the image flips.", ""),
    ("A shadow forms when an ___ object blocks light.", "opaque", ["transparent", "invisible"], "Opaque things stop light, leaving a dark area behind.", "torch"),
    ("What colour is the shadow of a red ball?", "dark", ["red", "pink", "white"], "A shadow is dark whatever the object's colour.", "ball"),
    ("Shadows outdoors are shortest around ___.", "noon", ["morning", "evening"], "At noon the Sun is highest, so shadows are short.", "sun"),
    ("To see a shadow you need light, an opaque object and a ___.", "screen", ["mirror", "lens", "prism"], "The shadow falls on a screen, wall or ground.", "torch"),
    ("Light bouncing back from a shiny surface is ___.", "reflection", ["shadow", "eclipse", "transparency"], "Mirrors and shiny metals reflect light well.", "mirror"),
    ("Which reflects light best?", "a mirror", ["a brick", "a wooden board", "a black cloth"], "A smooth, shiny mirror reflects almost all light.", "mirror"),
    ("Which word looks the same in a plane mirror?", "WOW", ["MAP", "SUN", "BED"], "W and O are symmetric, and WOW reads the same backwards.", "mirror"),
    ("Which word looks the same in a plane mirror?", "TOOT", ["TOP", "NET", "RAT"], "T and O are symmetric, and TOOT reads the same backwards.", "mirror"),
    ("Which word looks the same in a plane mirror?", "MUM", ["MAN", "SUN", "PEN"], "M and U are symmetric, and MUM reads the same backwards.", "mirror"),
]:
    F(SK, 1, q, a, w, why, S, pic=pic)
MORN = ["7 am", "8 am", "9 am", "10 am", "11 am"]
AFT = ["2 pm", "3 pm", "4 pm", "5 pm"]
for t in ["7 am", "8 am", "9 am"]:
    F(SK, 3, f"At {t}, which way does a pole's shadow point?", "west", ["east", "south", "straight up"], "The morning Sun is in the east, so shadows point west.", S, pic="sun")
for t in ["4 pm", "5 pm"]:
    F(SK, 3, f"At {t}, which way does a pole's shadow point?", "east", ["west", "south", "straight up"], "The evening Sun is in the west, so shadows point east.", S, pic="sun")
for half in (MORN, AFT):
    for i in range(len(half)):
        for j in range(i + 1, len(half)):
            a, b = half[i], half[j]
            far, near = (a, b) if half is MORN else (b, a)
            F(SK, 2, f"When is a pole's shadow longer: at {a} or at {b}?", far, [near, "same length"],
              "The lower the Sun in the sky, the longer the shadow.", S, pic="sun")
            F(SK, 2, f"When is a pole's shadow shorter: at {a} or at {b}?", near, [far, "same length"],
              "The higher the Sun in the sky, the shorter the shadow.", S, pic="sun")

# ---- sc7.earthMoon (CU7 ch12 Earth, Moon, and the Sun)
S = "CU7 ch12"
SK = "sc7.earthMoon"
PH8 = ["new moon", "waxing crescent", "first quarter", "waxing gibbous", "full moon", "waning gibbous", "last quarter", "waning crescent"]
MWHY = "The lit part grows from new moon to full moon, then shrinks."
O(SK, 2, "Starting just after a new moon, put these phases in order.", PH8, MWHY, S)
O(SK, 3, "Starting just after a full moon, put these phases in order.", PH8[4:] + PH8[:4], MWHY, S)
CH(SK, id="moon", items=PH8, art="the ", t=2, src=S, why=MWHY,
   next="Which phase of the Moon comes after the {x}?", prev="Which phase of the Moon comes just before the {x}?",
   adj="The {b} comes just after the {a}.", cmp="", cmpWhy="", pos="", cyclic=True)
MAIN = ["new moon", "first quarter", "full moon", "last quarter"]
for i, p in enumerate(MAIN):
    a1, a2 = MAIN[(i + 1) % 4], MAIN[(i + 2) % 4]
    F(SK, 3, f"About one week after the {p}, the Moon shows the ___.", a1, [m for m in MAIN if m not in (a1,)][:3], "Each main phase is about a week after the last.", S, pic="moon")
    F(SK, 3, f"About two weeks after the {p}, the Moon shows the ___.", a2, [m for m in MAIN if m != a2][:3], "Two weeks is half the Moon's cycle of phases.", S, pic="moon")
O(SK, 3, "In a solar eclipse, put the bodies in a line, starting from the Sun.", ["Sun", "Moon", "Earth"], "In a solar eclipse, the Moon is between the Sun and Earth.", S)
O(SK, 3, "In a lunar eclipse, put the bodies in a line, starting from the Sun.", ["Sun", "Earth", "Moon"], "In a lunar eclipse, Earth is between the Sun and the Moon.", S)
for q, a, w, why, pic in [
    ("In a solar eclipse, which is in the middle?", "the Moon", ["Earth", "the Sun"], "The Moon blocks sunlight from reaching part of Earth.", "sun"),
    ("In a lunar eclipse, which is in the middle?", "Earth", ["the Moon", "the Sun"], "Earth's shadow falls on the Moon.", "moon"),
    ("A solar eclipse can happen only on a ___ day.", "new moon", ["full moon", "first quarter"], "Only at new moon is the Moon between the Sun and Earth.", "sun"),
    ("A lunar eclipse can happen only on a ___ night.", "full moon", ["new moon", "first quarter"], "Only at full moon is Earth between the Sun and Moon.", "moon"),
    ("In a lunar eclipse, whose shadow falls on the Moon?", "Earth's", ["the Sun's", "Mars's"], "Earth blocks sunlight, and its shadow covers the Moon.", "moon"),
    ("Why must we never look straight at the Sun?", "it can harm our eyes", ["it makes us sleepy", "it is too far"], "Strong sunlight can burn the eye, even during an eclipse.", "sun"),
    ("Earth spins once on its axis in about ___.", "24 hours", ["365 days", "one month", "one hour"], "One spin of Earth gives one day and night.", "earth"),
    ("Earth goes round the Sun once in about ___.", "365 days", ["24 hours", "one month", "one week"], "One trip round the Sun takes a year.", "earth"),
    ("Day and night happen because Earth ___.", "spins on its axis", ["goes round the Sun", "moves away from the Sun"], "As Earth spins, each side faces the Sun in turn.", "earth"),
    ("The Sun seems to rise in the ___.", "east", ["west", "north", "south"], "Earth spins west to east, so the Sun rises in the east.", "sun"),
    ("Earth spins from ___.", "west to east", ["east to west", "north to south"], "That is why the Sun seems to rise in the east.", "earth"),
    ("The Moon shines because it ___.", "reflects sunlight", ["makes its own light", "is on fire"], "The Moon has no light of its own.", "moon"),
    ("About how long is it from one full moon to the next?", "about a month", ["about a week", "about a year", "one day"], "The Moon's phases repeat about every 29 to 30 days.", "moon"),
    ("From Earth, we always see ___ of the Moon.", "the same side", ["both sides in turn", "only the dark side"], "The Moon spins once for each trip round Earth.", "moon"),
    ("The full moon night is called ___ in many Indian languages.", "Purnima", ["Amavasya", "Ekadashi"], "Purnima is the night of the full moon.", "moon"),
    ("The new moon day is called ___ in many Indian languages.", "Amavasya", ["Purnima", "Ekadashi"], "On Amavasya, the Moon's lit side faces away from us.", "moon"),
    ("Seasons happen mainly because Earth's axis is ___.", "tilted", ["straight up", "made of iron"], "The tilt changes how directly sunlight falls on each place.", "earth"),
    ("When the Moon's lit part grows night by night, it is ___.", "waxing", ["waning", "eclipsed"], "Waxing means growing; waning means shrinking.", "moon"),
    ("When the Moon's lit part shrinks night by night, it is ___.", "waning", ["waxing", "eclipsed"], "Waxing means growing; waning means shrinking.", "moon"),
]:
    F(SK, 1, q, a, w, why, S, pic=pic)


# ---------------------------------------------------------------- write

def main():
    pics = set()
    if os.path.exists(PICS):
        pj = json.load(open(PICS))
        for k, v in pj.items():
            if not k.startswith("_"):
                pics.update(v)
    used = [r.get("pic") for t in TABLES.values() for r in t["items"]] + [f.get("pic") for fs in FACTS.values() for f in fs] \
        + [f.get("pic") for fs in TFS.values() for f in fs] + [m.get("pic") for m in MOVERS]
    for p in used:
        if p and pics and p not in pics:
            ERR.append(f"unknown picture {p}")
    if ERR:
        print("\n".join(ERR), file=sys.stderr)
        sys.exit(1)
    data = {
        "_doc": "Science tables for Classes 6-7 (NCERT Curiosity CU6/CU7), read by learn-core ScienceGen. "
                "tables: classification tables {ask, card, classes[{id,label,sing,both,which,why}], items[{x,np,c,also?,skip?,why?,pic?,src}]}; "
                "'also' = classes also true for the row, 'skip' = arguable, never asked. facts/tfs/orders/chains are per skill id. "
                "movers: speed contexts. Generated by boretube-learn/tools/content/data/science_data.py; edit there.",
        "tables": TABLES, "facts": FACTS, "tfs": TFS, "orders": ORDERS, "chains": CHAINS, "movers": MOVERS,
    }
    with open(OUT, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    n = sum(len(t["items"]) for t in TABLES.values())
    print(f"wrote {os.path.normpath(OUT)}: {len(TABLES)} tables, {n} rows, "
          f"{sum(map(len, FACTS.values()))} facts, {sum(map(len, TFS.values()))} statements, "
          f"{sum(map(len, ORDERS.values()))} orders, {sum(map(len, CHAINS.values()))} chains")


main()
