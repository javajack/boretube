#!/usr/bin/env python3
"""Builds content/data/lexicon.json and content/data/english.json (Tubby's Town, spec P2b §4).

Run from anywhere:  python3 boretube-learn/tools/content/data/english_data.py

The data lives as Python literals in english_lex.py (headwords) and
english_tables_a.py / english_tables_b.py (curated tables). This script
expands inflections by rule, checks every form it makes against the
British word list (/usr/share/dict/british-english) and fails loudly on
anything it can't confirm, then writes sorted, stable JSON.
"""
import json
import os
import string
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import english_lex as L  # noqa: E402
import english_tables_a as A  # noqa: E402
import english_tables_b as B  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "../../../app/src/main/assets/content/data"))
DICT = "/usr/share/dict/british-english"

problems = []


def load_dict():
    if not os.path.exists(DICT):
        sys.exit(f"needs {DICT} (apt install wbritish) to check the word forms")
    words = set()
    with open(DICT, encoding="utf-8", errors="ignore") as f:
        for line in f:
            w = line.strip()
            if w and "'" not in w:
                words.add(w.lower())
    return words


WORDS = load_dict()
US_WORDS = set()
if os.path.exists("/usr/share/dict/american-english"):
    with open("/usr/share/dict/american-english", encoding="utf-8", errors="ignore") as f:
        US_WORDS = {w.strip().lower() for w in f if w.strip() and "'" not in w}
EXTRA_REAL = set("idli idlis dosa dosas roti rotis ladoo ladoos jalebi jalebis samosa samosas paratha parathas chapati chapatis "
                 "puri puris kurta kurtas sari saris almirah almirahs mela melas brinjal brinjals chikoo litchi lychee lychees "
                 "tawa poha upma kheer khichdi halwa dal lassi myna mynas ladyfinger ladyfingers capsicum capsicums auto autos "
                 "rickshaw rickshaws sharpener sharpeners tumbler tumblers jackfruit jackfruits momos frock frocks".split())
REAL = WORDS | EXTRA_REAL


def real(w):
    return w.lower() in REAL


def check(form, what):
    for part in form.split():
        if not real(part):
            problems.append(f"{what}: '{form}' not in the word list")


def pictures():
    p = os.path.join(OUT, "pictures.json")
    if not os.path.exists(p):
        return set()
    j = json.load(open(p))
    return {x for k, v in j.items() if k != "_doc" for x in v}


PICS = pictures()
PIC_ALIAS = {"cycle": "bicycle", "pea": "peas", "bean": "beans", "glove": "gloves", "sari": "saree"}
PIC_SKIP = {"bat", "palm", "saw", "pine", "drop", "star", "glass", "pan", "pen", "fan"}


def pic_for(w):
    w2 = PIC_ALIAS.get(w, w)
    return w2 if w2 in PICS and w not in PIC_SKIP else None


VOW = "aeiou"


def plural(w):
    if w[-1] == "y" and w[-2] not in VOW:
        return w[:-1] + "ies"
    if w.endswith(("s", "x", "z", "ch", "sh")):
        return w + "es"
    if w in ("potato", "tomato", "hero", "echo", "mosquito", "buffalo", "volcano"):
        return w + "es"
    return w + "s"


def s3(v):
    if v == "have":
        return "has"
    if v in ("do", "go"):
        return v + "es"
    if v.endswith(("s", "x", "z", "ch", "sh")):
        return v + "es"
    if v[-1] == "y" and v[-2] not in VOW:
        return v[:-1] + "ies"
    return v + "s"


def ing(v, dbl):
    if v == "be":
        return "being"
    if v.endswith("ie"):
        return v[:-2] + "ying"
    if dbl:
        return v + v[-1] + "ing"
    if v.endswith(("ee", "ye", "oe")):
        return v + "ing"
    if v.endswith("e") and len(v) > 2:
        return v[:-1] + "ing"
    return v + "ing"


def past(v, dbl):
    if v.endswith("e"):
        return v + "d"
    if v[-1] == "y" and v[-2] not in VOW:
        return v[:-1] + "ied"
    if dbl:
        return v + v[-1] + "ed"
    return v + "ed"


def comp_sup(a, rule):
    if rule == "M":
        return "more " + a, "most " + a
    if rule == "D":
        return a + a[-1] + "er", a + a[-1] + "est"
    if a.endswith("e"):
        return a + "r", a + "st"
    if a[-1] == "y" and a[-2] not in VOW:
        return a[:-1] + "ier", a[:-1] + "iest"
    return a + "er", a + "est"


def an_for(w):
    w = w.lower()
    if w.startswith(("hour", "honest", "honour", "heir")):
        return True
    if w.startswith(("uni", "use", "usu", "eu", "one", "once", "ewe", "ufo", "uro")):
        return False
    if w.startswith("u") and len(w) > 2 and w[1] not in VOW and w[2] in VOW and w[1] in "nt" and not w.startswith("un"):
        return False
    return w[0] in VOW


lex = {}


def entry(w):
    if w not in lex:
        lex[w] = {"w": w, "pos": []}
    return lex[w]


def add_pos(e, p):
    if p not in e["pos"]:
        e["pos"].append(p)


# Nouns
for cat, toks in L.NOUNS.items():
    for t in toks.split():
        parts = t.split(":")
        w, lvl, flags = parts[0], int(parts[1]), parts[2:]
        e = entry(w)
        new = "lvl" not in e
        e["lvl"] = min(e.get("lvl", 9), lvl)
        add_pos(e, "n")
        if new:
            e["cat"] = cat
        pl = None
        unc = False
        for f in flags:
            if f == "v":
                add_pos(e, "v")
            elif f == "a":
                add_pos(e, "adj")
            elif f == "u":
                unc = True
            elif f == "x":
                pl = ""
            elif f.startswith("P="):
                pl = f[2:]
        if unc:
            e["count"] = False
        else:
            e["count"] = True
            if pl is None:
                pl = plural(w)
            if pl:
                e["plural"] = pl
                check(pl, f"plural of {w}")
        e["an"] = an_for(w)

# Verbs
for t in L.VERBS:
    parts = t.split(":")
    v, lvl = parts[0], int(parts[1])
    pst = parts[2] if len(parts) > 2 and parts[2] else None
    pp = parts[3] if len(parts) > 3 and parts[3] else None
    flags = parts[4] if len(parts) > 4 else (parts[3] if len(parts) == 4 and pst is None else "")
    if len(parts) == 4 and pst is None:
        pp = None
        flags = parts[3]
    dbl = "D" in flags
    e = entry(v)
    e["lvl"] = min(e.get("lvl", 9), lvl)
    add_pos(e, "v")
    if "n" in flags:
        add_pos(e, "n")
    if "a" in flags:
        add_pos(e, "adj")
    reg = pst is None
    e["past"] = pst or past(v, dbl)
    e["pp"] = pp or e["past"]
    e["s3"] = s3(v)
    e["ing"] = ing(v, dbl)
    e["irr"] = not reg
    if reg:
        e["edRule"] = "double" if dbl else ("d" if v.endswith("e") else ("ied" if v[-1] == "y" and v[-2] not in VOW else "ed"))
    for k in ("past", "pp", "s3", "ing"):
        check(e[k], f"{k} of {v}")

# Adjectives
for t in L.ADJS:
    parts = t.split(":")
    a, lvl = parts[0], int(parts[1])
    rule = parts[2] if len(parts) > 2 else ""
    extra = ""
    if "+" in rule:
        rule, extra = rule.split("+", 1)
    e = entry(a)
    e["lvl"] = min(e.get("lvl", 9), lvl)
    add_pos(e, "adj")
    for ch, p in (("n", "n"), ("v", "v"), ("d", "adv"), ("p", "prep")):
        if ch in extra:
            add_pos(e, p)
    if rule == "X":
        continue
    if rule.startswith("I="):
        c, s = rule[2:].split("/")
        e["comp"], e["sup"], e["compRule"] = c, s, "irr"
    elif rule == "B":
        e["compRule"] = "both"
    else:
        c, s = comp_sup(a, rule)
        e["comp"], e["sup"] = c, s
        e["compRule"] = "more" if rule == "M" else ("double" if rule == "D" else
                                                    ("ier" if a[-1] == "y" else ("r" if a.endswith("e") else "er")))
        if rule != "M":
            check(c, f"comp of {a}")
            check(s, f"sup of {a}")

for t in L.ADVERBS.split():
    w, lvl = t.split(":")
    e = entry(w)
    e["lvl"] = min(e.get("lvl", 9), int(lvl))
    add_pos(e, "adv")
for group, p in ((L.PRONOUNS, "pron"), (L.PREPS, "prep"), (L.CONJS, "conj"), (L.INTERJ, "interj")):
    for w in group.split():
        e = entry(w)
        e.setdefault("lvl", 3)
        add_pos(e, p)
# Known extra senses of POS-tagged words.
for w, p in (("well", "adj"), ("well", "n"), ("fast", "adj"), ("hard", "adj"), ("round", "prep"), ("near", "adj"),
             ("over", "adv"), ("in", "adv"), ("on", "adv"), ("today", "n"), ("tomorrow", "n"), ("yesterday", "n"),
             ("here", "n"), ("so", "adv"), ("but", "prep"), ("since", "prep"), ("until", "prep"), ("light", "v")):
    if w in lex:
        add_pos(lex[w], p)

for w in L.CONTESTED:
    if w in lex:
        lex[w]["contested"] = True

# Syllables
for s in B.SYLLABLES:
    if s in B.SYLLABLE_SKIP:
        continue
    w = s.replace("-", "")
    e = entry(w.lower()) if w.lower() in lex else None
    if e is not None:
        e["syl"] = s.count("-") + 1
        e["sylBreak"] = s

# Opposites / synonyms on headwords (single sense).
for a, b, _ in A.OPP_PAIRS:
    if a in lex and b in lex:
        lex[a]["opp"], lex[b]["opp"] = b, a
for a, b, _ in A.SYN_EASY:
    for x, y in ((a, b), (b, a)):
        if x in lex:
            lex[x].setdefault("syn", [])
            if y not in lex[x]["syn"]:
                lex[x]["syn"].append(y)

# Rhyme keys from the families.
for rime, ws in A.FAMILIES.items():
    for w in ws.split():
        if w in lex:
            lex[w]["rhyme"] = rime

for w, e in lex.items():
    e.setdefault("lvl", 3)
    p = pic_for(w)
    if p:
        e["pic"] = p


# ---- generated helpers: misspellings and gap letters, checked against the word list ----
def misspellings(w, n=4):
    out = []
    lw = w.lower()

    def add(c):
        if c and c != lw and not real(c) and c not in US_WORDS and c not in out and c.isalpha():
            out.append(c)
    for i in range(len(lw) - 1):
        add(lw[:i] + lw[i + 1] + lw[i] + lw[i + 2:])
    for i in range(len(lw)):
        if lw[i] in VOW:
            for v in VOW:
                add(lw[:i] + v + lw[i + 1:])
    if len(lw) > 2:
        for i in range(len(lw)):
            add(lw[:i] + lw[i + 1:])
    for i in range(len(lw)):
        add(lw[:i + 1] + lw[i] + lw[i + 1:])
    if w[0].isupper():
        out = [o.capitalize() for o in out]
    # spread: prefer different kinds
    return out[:: max(1, len(out) // n)][:n] if out else []


def lookalikes(w):
    lw = w.lower()
    cands = []
    rev = lw[::-1]
    if rev != lw:
        cands.append(rev)
    swaps = {"b": "d", "d": "b", "p": "q", "m": "n", "n": "m", "u": "n", "w": "m", "a": "o", "o": "a", "e": "a",
             "i": "l", "h": "n", "t": "f", "s": "z"}
    for i, ch in enumerate(lw):
        if ch in swaps:
            cands.append(lw[:i] + swaps[ch] + lw[i + 1:])
    if len(lw) > 2:
        cands.append(lw[1:])
    cands.append(lw + "s")
    out = []
    for c in cands:
        if c != lw and c not in out:
            out.append(c)
    return out[:6]


def gaps(w, letters=string.ascii_lowercase):
    """For each position, letters that make a non-word (safe wrong options)."""
    lw = w.lower()
    res = {}
    for i, ch in enumerate(lw):
        bad = []
        pool = VOW if ch in VOW else "".join(c for c in letters if c not in VOW)
        for c in pool:
            if c != ch and not real(lw[:i] + c + lw[i + 1:]):
                bad.append(c)
        res[str(i)] = bad
    return res


sight = []
for lvl, lst in ((0, A.SIGHT_KG), (1, A.SIGHT_1)):
    for w in lst:
        sight.append({"w": w, "lvl": lvl, "look": lookalikes(w), "miss": misspellings(w) if len(w) > 1 else [],
                      "gaps": gaps(w) if w.isalpha() and len(w) > 1 else {}})

cvc = [{"w": w, "gaps": gaps(w), "pic": pic_for(w)} for w in A.CVC]
for c in cvc:
    if not real(c["w"]):
        problems.append(f"cvc {c['w']} not a word")

spell = []
for right, wrongs in B.SPELL:
    ws = [x for x in wrongs.split() if not x.endswith("-")]
    ws = [x for x in ws if not real(x)]
    if len(ws) >= 1:
        spell.append([right, ws])
    if not real(right):
        problems.append(f"spell: {right} not a word")

PREFIXES = ["un", "re", "dis", "mis", "pre", "im", "in"]
prefix = []
for word, pre, base, mean in A.PREFIX:
    check(word, "prefix word")
    wrong = [p + base for p in PREFIXES if p != pre and not real(p + base)]
    prefix.append([word, pre, base, mean, wrong])


def ful(base, suf):
    stem = base[:-1] + "i" if base[-1] == "y" and base[-2] not in VOW else base
    return stem + suf


fulless = []
for b in A.FUL_LESS:
    f, l_ = ful(b, "ful"), ful(b, "less")
    fulless.append([b, f if real(f) else "", l_ if real(l_) else ""])
for b, d in A.ER_DOER:
    check(d, "doer")

# Magic e: keep pairs whose both words are real and that are kid words.
magic = []
seen_me = set()
for row in A.MAGIC_E:
    s, l_ = row[0], row[1]
    if (s, l_) in seen_me or s in ("tim", "pete", "dim", "rob", "cod", "gap", "fat", "bath", "cop", "dot", "fir", "twin",
                                    "glob", "van", "pal", "mop", "rat"):
        continue
    seen_me.add((s, l_))
    if not (real(s) and real(l_)):
        problems.append(f"magic e {s}/{l_}")
        continue
    magic.append([s, l_, row[2], row[3], pic_for(l_) or "", pic_for(s) or ""])
# Frames with the right word filled must make sense; the long word's frame is row[2], the short word's row[3].
for m in magic:
    if m[2] and "a ___" in m[2]:
        pass
for m in magic:
    if m[1] == "stripe":
        m[2] = "A zebra has black and white ___s."

# Homophones: drop empty frames.
homs = []
for st in A.HOMOPHONES:
    words = [x[0] for x in st]
    if words in ([w for w in h["words"]] for h in homs):
        continue
    frames = [[x[0], [f for f in x[1:] if f]] for x in st]
    if sum(len(f[1]) for f in frames) == 0:
        continue
    homs.append({"words": words, "frames": frames})

# Collective nouns
coll = [[c, n, ok.split()] for c, n, ok in A.COLLECTIVE if c not in A.COLLECTIVE_SKIP]

# Gender
gender = [[m, f] for m, f in A.GENDER if m not in A.GENDER_SKIP]

# Compounds
for a, b in A.COMPOUNDS:
    check(a + b, "compound")

if problems:
    print("\n".join(problems))
    print(f"{len(problems)} problems")
    if "--force" not in sys.argv:
        sys.exit(1)

LEX_DOC = ("Headwords for the English generators (spec P2b §4). w word; lvl class 0..7 (0 = KG); pos every part of "
           "speech a child may meet (n v adj adv pron prep conj interj); cat noun group; plural, past, pp, s3, ing, comp, sup "
           "inflections (checked against the British word list); irr irregular verb; edRule ed|d|ied|double; compRule "
           "er|r|ier|double|more|irr|both; count false for uncountable nouns; an true when it takes 'an'; opp single-sense "
           "opposite; syn safe synonyms; rhyme word-family key; syl syllables and sylBreak the claps; pic picture id in "
           "pictures.json; miss misspellings and gaps (position -> letters that make no word) for picture words; contested true to keep out of category questions. Built by "
           "boretube-learn/tools/content/data/english_data.py; do not edit by hand.")

for w, e in lex.items():
    if "pic" in e and w.isalpha():
        m = misspellings(w)
        if m:
            e["miss"] = m
        if len(w) >= 3:
            e["gaps"] = gaps(w)

lexicon = {"_doc": LEX_DOC, "words": sorted(lex.values(), key=lambda e: e["w"])}


def T(*rows):
    return [list(r) for r in rows]


english = {
    "_doc": ("Curated English tables (spec P2b §4), read by learn-core gen/EnglishGen.kt. Rows are arrays; each key's "
             "columns are listed in docCols. Built by boretube-learn/tools/content/data/english_data.py from Python "
             "literals; do not edit by hand. Indian/British English throughout."),
    "docCols": {
        "names": "girls, boys", "colourThings": "thing, colour", "colourMix": "a, b, result",
        "oppKG": "a, b, twoWay(1|0)", "sight": "w, lvl, look (lookalikes), miss (misspellings), gaps (pos -> safe wrong letters)",
        "actionFrames": "frame, answer, other fitting verbs", "actionVerbs": "verbs", "canDo": "verb -> objects",
        "families": "rime -> words", "familyPairs": "rime, rime", "seqKG": "steps in order",
        "cvc": "w, gaps, pic", "digraphs": "digraph -> words", "capPred": "predicates", "capI": "sentences with I",
        "capName": "frames with {n}", "days": "", "months": "", "magicE": "short, long, frame for long, frame for short, pic long, pic short",
        "pronNP": "noun phrase, pronoun, kind f|m|pl", "pronThing": "noun phrase, pronoun",
        "beSubj": "text, kind I|you|3s|pl", "beThing": "text, kind, complements", "bePeopleComp": "complements",
        "qwFrames": "frame, answer, wrong words", "qwSlots": "slot -> fills", "compounds": "first, second",
        "notCompound": "simple words", "synEasy": "a, b, lvl", "oppPairs": "a, b, lvl",
        "sbSubj": "subject, kind", "sbVp3/4/5": "verb phrases", "proper": "name, what it names", "commonKinds": "",
        "adjSets": "category, adjectives, nouns, endings", "adjPred": "noun, adjectives",
        "homophones": "{words, frames: [word, [frames]]}", "prefix": "word, prefix, base, meaning, wrong forms",
        "fulLess": "base, -ful form or '', -less form or ''", "erDoer": "verb, doer", "fulFrames": "frame, answer, wrong",
        "gender": "male, female", "collective": "collective, noun, other collectives that fit",
        "svSubj": "subject, kind", "svVp": "base phrase, s3 phrase", "svTricky": "frame, answer, wrong",
        "tenseVp": "verb, object", "tenseSubj": "subject, kind", "advSent": "subject, past verb, object, adverbs",
        "advForm": "adjectives", "advIrr": "doer phrase, verb s3, adverb, wrong", "contract": "full, short, wrongs",
        "contractFrames": "frame, answer, wrong", "commands/exclaims/questions/statements": "sentences",
        "timeExpr": "expression, preposition, tier", "timeStart": "starters", "timeStartBad": "starter -> expressions to skip",
        "placePrep": "frame, preposition", "similes": "adjective, noun, group", "simileMean": "simile, meaning",
        "oneWord": "phrase, word, group, lvl", "analogy": "relation -> [A, B]", "adjNoun": "adjective, noun, wrongs",
        "verbNoun": "verb, noun, wrongs", "adjNounFrames": "frame, answer, base", "spell": "right, wrongs",
        "facts": "", "opinionFrames": "frame, fills", "opinions": "", "phrasal": "phrase, meaning, frames (| separated)",
        "confuse": "[[word, frames...]...]", "errors": "correct, wrong word, right word, explanation",
        "wordForm": "verb, noun, adjective", "wordFormNoV": "rows without a real verb", "wordFormFrames": "frame, answer, wrongs",
        "fig6": "line, s|m|p", "fig7": "line, a|o|h|p", "clauses": "main, subordinate, other joins, wrong joins",
        "rel*": "relative clause parts", "cond0/1/2": "frame, answer, wrongs", "repq": "direct, reported, answer, wrongs",
        "repc": "command, reported, answer, wrongs", "roots": "root, meaning, examples", "makeDo/sayTell": "verb -> phrases",
        "verbColl/adjColl": "frame, answer, wrongs", "punct*": "punctuation frames", "speech": "speaker, words",
        "analogy2": "relation -> [A, B]", "seq7": "steps in order",
    },
    "names": [A.GIRLS, A.BOYS],
    "colourThings": T(*A.COLOUR_THINGS), "colourMix": T(*A.COLOUR_MIX), "oppKG": T(*A.OPP_KG),
    "sight": sight, "actionFrames": T(*A.ACTION_FRAMES), "actionVerbs": A.ACTION_VERBS,
    "canDo": {k: v.split(" ") if k != "drink" else ["milk", "water", "juice", "tea", "lassi", "coconut water"]
              for k, v in A.CAN_DO.items()},
    "families": {k: v.split() for k, v in A.FAMILIES.items()}, "familyPairs": T(*A.FAMILY_PAIRS), "seqKG": A.SEQ_KG,
    "cvc": cvc, "digraphs": {k: v.split() for k, v in A.DIGRAPHS.items()},
    "capPred": A.CAP_PRED, "capI": A.CAP_I, "capName": A.CAP_NAME, "days": A.DAYS, "months": A.MONTHS,
    "magicE": magic, "pronNP": T(*A.PRON_NP), "pronThing": T(*A.PRON_THING),
    "pronFrames": {"sg": A.PRON_PERSON_FRAMES_SG, "pl": A.PRON_PERSON_FRAMES_PL, "thingSg": A.PRON_THING_FRAMES_SG,
                   "thingPl": A.PRON_THING_FRAMES_PL, "obj": A.PRON_OBJ_FRAMES},
    "beSubj": T(*A.BE_SUBJ), "beThing": [[a, b, c.split()] for a, b, c in A.BE_THING], "bePeopleComp": A.BE_PEOPLE_COMP,
    "qwFrames": [[f, a, w.split()] for f, a, w in A.QW_FRAMES], "qwSlots": A.QW_SLOTS,
    "compounds": T(*A.COMPOUNDS), "notCompound": A.NOT_COMPOUND, "synEasy": T(*A.SYN_EASY),
    "oppPairs": [list(r) for r in A.OPP_PAIRS if r[2] <= 7],
    "sbSubj": T(*A.SB_SUBJ), "sbVp3": A.SB_VP3, "sbVp4": A.SB_VP4, "sbVp5": A.SB_VP5,
    "proper": T(*A.PROPER), "commonKinds": A.COMMON_KINDS,
    "adjSets": [[c, a.split(), n.split(), e] for c, a, n, e in A.ADJ_SETS], "adjPred": [[n, a.split()] for n, a in A.ADJ_PRED],
    "homophones": homs, "prefix": prefix, "fulLess": fulless, "erDoer": T(*A.ER_DOER), "fulFrames": T(*A.FUL_FRAMES),
    "gender": gender, "collective": coll,
    "svSubj": T(*B.SV_SUBJ), "svVp": [list(r) for r in B.SV_VP if r[1]], "svTricky": T(*B.SV_TRICKY),
    "tenseVp": T(*B.TENSE_VP), "tenseSubj": T(*B.TENSE_SUBJ),
    "advSent": [[s, v, o, a.split()] for s, v, o, a in B.ADV_SENT], "advForm": B.ADV_FORM, "advIrr": T(*B.ADV_IRR),
    "contract": [[f, s, w.split()] for f, s, w in B.CONTRACT], "contractFrames": T(*B.CONTRACT_FRAMES),
    "commands": B.COMMANDS, "exclaims": B.EXCLAIMS, "questions": B.QUESTIONS, "statements": B.STATEMENTS,
    "timeExpr": T(*B.TIME_EXPR), "timeStart": B.TIME_START, "timeStartBad": {k: sorted(v) for k, v in B.TIME_START_BAD.items()},
    "placePrep": T(*B.PLACE_PREP), "similes": T(*B.SIMILES), "simileMean": T(*B.SIMILE_MEAN), "oneWord": T(*B.ONE_WORD),
    "analogy": {k: [list(r) for r in v if r not in B.ANALOGY_SKIP_ROWS] for k, v in B.ANALOGY.items()},
    "adjNoun": [[a, n, w.split()] for a, n, w in B.ADJ_NOUN], "verbNoun": [[a, n, w.split()] for a, n, w in B.VERB_NOUN if a not in B.VERB_NOUN_SKIP],
    "adjNounFrames": T(*B.ADJ_NOUN_FRAMES), "spell": spell, "facts": B.FACTS,
    "opinionFrames": [[f, x.split(" ") if "Hide" not in x and "The monsoon" not in x else None] for f, x in B.OPINION_FRAMES],
    "opinions": B.OPINIONS, "phrasal": [[p, m, f.split("|")] for p, m, f in B.PHRASAL], "confuse": B.CONFUSE,
    "errors": [list(r) for r in B.ERRORS if r[3]], "wordForm": T(*B.WORD_FORM), "wordFormNoV": sorted(B.WORD_FORM_NO_V),
    "wordFormFrames": [[f, a, w.split()] for f, a, w in B.WORD_FORM_FRAMES], "fig6": T(*B.FIG6), "fig7": [list(r) for r in B.FIG7 if r[0] not in B.FIG7_SKIP],
    "clauses": [[m, s, o.split(), w.split()] for m, s, o, w in B.CLAUSES],
    "relPerson": B.REL_PERSON, "relPersonCl": B.REL_PERSON_CL, "relThing": B.REL_THING, "relThingCl": B.REL_THING_CL,
    "relEnds": B.REL_ENDS, "relThingEnds": B.REL_THING_ENDS, "relWhose": T(*B.REL_WHOSE), "relWhere": T(*B.REL_WHERE),
    "cond1": [[c, r, a, w.split("|")] for c, r, a, w in B.COND1_ROWS if a], "cond1If": [[f, a, w.split("|")] for f, a, w in B.COND1_IF],
    "cond2": [[f, a, w.split("|")] for f, a, w in B.COND2], "cond0": [[f, a, w.split("|")] for f, a, w in B.COND0],
    "repq": [[d, r, a, w.split("|")] for d, r, a, w in B.REPQ], "repqSpeakers": B.REPQ_SPEAKERS,
    "repc": [[d, r, a, w.split("|")] for d, r, a, w in B.REPC], "repcSpeakers": B.REPC_SPEAKERS,
    "roots": [[r, m, e.split()] for r, m, e in B.ROOTS if r not in B.ROOTS_SKIP],
    "makeDo": {k: v.split("|") for k, v in B.MAKE_DO.items()}, "sayTell": {k: v.split("|") for k, v in B.SAY_TELL.items()},
    "verbColl": [[f, a, w.split()] for f, a, w in B.VERB_COLL], "adjColl": [[f, a, w.split()] for f, a, w in B.ADJ_COLL_OK],
    "punctListStart": B.PUNCT_LIST_START, "punctLists": B.PUNCT_LISTS, "punctSemi": T(*B.SEMI), "punctComma": T(*B.COMMA_INTRO),
    "speech": T(*B.SPEECH), "anTricky": T(*B.AN_TRICKY), "theFrames": B.THE_FRAMES, "passive": T(*B.PASSIVE),
    "reported": [[d, a, r, w.split("|"), t] for d, a, r, w, t in B.REPORTED], "cond1p": T(*B.COND1P), "qgen": B.QGEN, "analogy2": {k: [list(r) for r in v] for k, v in B.ANALOGY2.items()}, "seq7": B.SEQ_7,
}
# Opinion frames with multi-word fills.
fills = {"{x} is the nicest season.": ["Summer", "Winter", "The monsoon", "Spring"],
         "{x} is a boring game.": ["Chess", "Cricket", "Ludo", "Carrom", "Hide and seek"]}
english["opinionFrames"] = [[f, fills.get(f, x.split(" "))] for f, x in B.OPINION_FRAMES]

os.makedirs(OUT, exist_ok=True)
for name, obj in (("lexicon.json", lexicon), ("english.json", english)):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, sort_keys=True, indent=0, separators=(",", ":"))
        f.write("\n")
print(f"lexicon: {len(lex)} words, {sum(1 for e in lex.values() if 'pic' in e)} with pictures; "
      f"english.json: {len(english)} tables; pictures known: {len(PICS)}")
