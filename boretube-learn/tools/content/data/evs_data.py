#!/usr/bin/env python3
"""Curated EVS fact tables (KG to Class 5) for Tubby's Town generated skills.

Run:  python3 boretube-learn/tools/content/data/evs_data.py
Writes boretube-learn/app/src/main/assets/content/data/evs.json (stable, sorted).

Rules (spec P2b §4, skill map §4):
- facts are for children and NCERT-consistent; anything arguable is left
  blank (None) or flagged contested, never guessed;
- lists hold every true value, so a wrong option is never also right;
- British spelling (colour, centre, metre), Indian context.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "app", "src", "main", "assets", "content", "data", "evs.json")


def rows(text, n):
    out = []
    for line in text.strip().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        assert len(parts) == n, (n, line)
        out.append(parts)
    return out


def lst(s):
    return [] if s in ("", "-") else [x.strip() for x in s.split(",")]


def opt(s):
    return None if s in ("", "-") else s


def an(word):
    return word[0] in "aeiou" and not word.startswith(("uni", "use", "eu"))


def plural(w):
    special = {
        "mouse": "mice", "sheep": "sheep", "deer": "deer", "fish": "fish", "ox": "oxen", "goose": "geese",
        "wolf": "wolves", "louse": "lice", "goldfish": "goldfish", "rohu": "rohu", "catla": "catla",
        "hilsa": "hilsa", "pomfret": "pomfrets", "salmon": "salmon", "tuna": "tuna", "yak": "yaks",
        "blackbuck": "blackbucks", "nilgai": "nilgai", "reindeer": "reindeer", "catfish": "catfish",
        "clownfish": "clownfish", "starfish": "starfish", "jellyfish": "jellyfish", "mackerel": "mackerels",
        "gaur": "gaur", "bison": "bison", "moose": "moose", "trout": "trout", "cod": "cod",
        "swordfish": "swordfish", "silverfish": "silverfish", "octopus": "octopuses", "rhinoceros": "rhinos",
        "hippopotamus": "hippos", "cactus": "cacti", "leaf": "leaves", "knife": "knives", "shelf": "shelves",
        "loaf": "loaves", "potato": "potatoes", "tomato": "tomatoes", "mango": "mangoes",
        "buffalo": "buffaloes", "mosquito": "mosquitoes", "flamingo": "flamingos", "kangaroo": "kangaroos",
        "dragonfly": "dragonflies", "butterfly": "butterflies", "firefly": "fireflies", "housefly": "houseflies",
        "ladybird": "ladybirds", "puppy": "puppies", "monkey": "monkeys", "donkey": "donkeys", "turkey": "turkeys",
    }
    if w in special:
        return special[w]
    last = w.split(" ")[-1]
    head = w[: len(w) - len(last)]
    if last in special:
        return head + special[last]
    if last.endswith("y") and last[-2] not in "aeiou":
        return head + last[:-1] + "ies"
    if last.endswith(("s", "x", "z", "ch", "sh")):
        return head + last + "es"
    return head + last + "s"


# ---------------------------------------------------------------- animals
# name | group | habitats | homes (first = main) | food h/c/o | covering | young | legs | birth e/l |
# kind pet/farm/wild | size 1..7 | flies y/n | flags (c contested group, k KG-familiar, a land and water)
# Habitats: forest grassland desert snow sea fresh(ponds, rivers) farm house mountain soil.
# Size: 1 tiny (ant) 2 small (mouse) 3 cat 4 dog 5 deer/person 6 horse/cow/lion 7 elephant/whale.
# '-' means unknown or arguable, so never used.
ANIMALS = rows("""
cow|mammal|farm|cowshed|h|hair|calf|4|l|farm|6|n|k
buffalo|mammal|farm|cowshed|h|hair|calf|4|l|farm|6|n|k
ox|mammal|farm|cowshed|h|hair|calf|4|l|farm|6|n|
goat|mammal|farm,mountain|-|h|hair|kid|4|l|farm|4|n|k
sheep|mammal|farm,mountain|-|h|wool|lamb|4|l|farm|4|n|k
horse|mammal|farm,grassland|stable|h|hair|foal|4|l|farm|6|n|k
donkey|mammal|farm|stable|h|hair|foal|4|l|farm|5|n|k
mule|mammal|farm,mountain|stable|h|hair|-|4|l|farm|6|n|
camel|mammal|desert|-|h|hair|calf|4|l|farm|6|n|k
pig|mammal|farm|sty|o|hair|piglet|4|l|farm|5|n|k
dog|mammal|house|kennel|-|fur|puppy|4|l|pet|4|n|k
cat|mammal|house|-|c|fur|kitten|4|l|pet|3|n|k
rabbit|mammal|grassland,house|burrow|h|fur|-|4|l|pet|3|n|k
guinea pig|mammal|house|-|h|fur|-|4|l|pet|2|n|
hamster|mammal|house|-|-|fur|-|4|l|pet|2|n|
yak|mammal|mountain,snow|-|h|hair|calf|4|l|-|6|n|
mouse|mammal|house,farm,grassland|hole,burrow|o|fur|-|4|l|-|2|n|k
rat|mammal|house,farm|hole,burrow|o|fur|-|4|l|-|2|n|k
squirrel|mammal|forest,house|-|-|fur|-|4|l|wild|2|n|k
bat|mammal|forest,house|-|-|fur|-|-|l|wild|2|y|c
elephant|mammal|forest,grassland|-|h|-|calf|4|l|-|7|n|k
lion|mammal|grassland,forest|den|c|fur|cub|4|l|wild|6|n|k
tiger|mammal|forest,grassland|den|c|fur|cub|4|l|wild|6|n|k
leopard|mammal|forest|-|c|fur|cub|4|l|wild|5|n|k
cheetah|mammal|grassland|-|c|fur|cub|4|l|wild|5|n|
jaguar|mammal|forest|-|c|fur|cub|4|l|wild|5|n|
puma|mammal|forest,mountain|-|c|fur|cub|4|l|wild|5|n|
snow leopard|mammal|mountain,snow|-|c|fur|cub|4|l|wild|5|n|
wolf|mammal|forest,grassland,mountain|den|c|fur|-|4|l|wild|5|n|k
fox|mammal|forest,grassland,desert|den,burrow|-|fur|-|4|l|wild|4|n|k
jackal|mammal|forest,grassland|den|-|fur|-|4|l|wild|4|n|
hyena|mammal|grassland|den|c|fur|-|4|l|wild|5|n|
bear|mammal|forest,mountain|den|o|fur|cub|4|l|wild|6|n|k
polar bear|mammal|snow,sea|den|c|fur|cub|4|l|wild|6|n|k
panda|mammal|forest,mountain|-|h|fur|cub|4|l|wild|6|n|k
red panda|mammal|forest,mountain|-|-|fur|cub|4|l|wild|3|n|
deer|mammal|forest,grassland|-|h|hair|fawn|4|l|wild|5|n|k
blackbuck|mammal|grassland|-|h|hair|-|4|l|wild|5|n|
nilgai|mammal|grassland,forest|-|h|hair|calf|4|l|wild|6|n|
reindeer|mammal|snow|-|h|fur|calf|4|l|-|6|n|
moose|mammal|forest,snow|-|h|fur|calf|4|l|wild|7|n|
giraffe|mammal|grassland|-|h|hair|calf|4|l|wild|7|n|k
zebra|mammal|grassland|-|h|hair|foal|4|l|wild|6|n|k
rhinoceros|mammal|grassland|-|h|-|calf|4|l|wild|7|n|k
hippopotamus|mammal|fresh,grassland|-|h|-|calf|4|l|wild|7|n|ka
gaur|mammal|forest|-|h|hair|calf|4|l|wild|6|n|
bison|mammal|grassland,forest|-|h|fur|calf|4|l|wild|6|n|
wild boar|mammal|forest,grassland|-|o|hair|piglet|4|l|wild|5|n|
monkey|mammal|forest,house|-|-|fur|-|-|l|wild|4|n|k
langur|mammal|forest|-|h|fur|-|-|l|wild|4|n|
chimpanzee|mammal|forest|-|o|hair|-|-|l|wild|5|n|
gorilla|mammal|forest|-|h|hair|-|-|l|wild|6|n|
orangutan|mammal|forest|-|-|hair|-|-|l|wild|5|n|
kangaroo|mammal|grassland|-|h|fur|joey|-|l|wild|5|n|k
koala|mammal|forest|-|h|fur|joey|4|l|wild|3|n|
mongoose|mammal|grassland,forest,farm|burrow|-|fur|-|4|l|wild|3|n|
porcupine|mammal|forest,grassland|burrow|h|-|-|4|l|wild|3|n|
hedgehog|mammal|forest,grassland|-|-|-|-|4|l|wild|2|n|
mole|mammal|grassland,soil|burrow|c|fur|-|4|l|wild|2|n|
hare|mammal|grassland,desert|-|h|fur|-|4|l|wild|3|n|
meerkat|mammal|desert|burrow|-|fur|-|4|l|wild|2|n|
sloth|mammal|forest|-|h|hair|-|-|l|wild|3|n|
otter|mammal|fresh,sea|-|c|fur|-|4|l|wild|4|n|a
seal|mammal|sea,snow|-|c|fur|-|-|l|wild|5|n|a
walrus|mammal|sea,snow|-|c|-|calf|-|l|wild|6|n|a
whale|mammal|sea|-|-|-|calf|-|l|wild|7|n|c
dolphin|mammal|sea,fresh|-|c|-|calf|-|l|wild|5|n|c
pangolin|mammal|forest,grassland|burrow|c|-|-|4|l|wild|3|n|c
crow|bird|house,forest,farm|nest|o|feathers|-|2|e|wild|3|y|k
sparrow|bird|house,farm|nest|-|feathers|-|2|e|wild|2|y|k
pigeon|bird|house,farm|nest|h|feathers|-|2|e|-|3|y|k
parrot|bird|forest|-|h|feathers|-|2|e|-|3|y|k
peacock|bird|forest,farm|-|o|feathers|peachick|2|e|wild|4|y|k
hen|bird|farm|coop,nest|o|feathers|chick|2|e|farm|3|-|k
duck|bird|fresh,farm|-|o|feathers|duckling|2|e|farm|3|-|ka
swan|bird|fresh|-|-|feathers|cygnet|2|e|wild|5|y|a
goose|bird|fresh,farm|-|h|feathers|gosling|2|e|farm|4|-|a
turkey|bird|farm|-|o|feathers|-|2|e|farm|5|-|
quail|bird|grassland,farm|-|-|feathers|-|2|e|-|2|-|
eagle|bird|mountain,forest,grassland|nest|c|feathers|eaglet|2|e|wild|4|y|k
vulture|bird|grassland,mountain,forest|nest|c|feathers|-|2|e|wild|4|y|
hawk|bird|forest,grassland|nest|c|feathers|-|2|e|wild|3|y|
falcon|bird|grassland,mountain|-|c|feathers|-|2|e|wild|3|y|
owl|bird|forest,farm|-|c|feathers|owlet|2|e|wild|3|y|k
kingfisher|bird|fresh|-|c|feathers|-|2|e|wild|2|y|
woodpecker|bird|forest|-|-|feathers|-|2|e|wild|2|y|
myna|bird|house,farm|nest|o|feathers|-|2|e|wild|2|y|k
koel|bird|forest,house|-|-|feathers|-|2|e|wild|3|y|
bulbul|bird|forest,house|nest|-|feathers|-|2|e|wild|2|y|
tailorbird|bird|forest,house|nest|-|feathers|-|2|e|wild|2|y|
weaverbird|bird|grassland,farm|nest|-|feathers|-|2|e|wild|2|y|
sunbird|bird|forest,house|nest|-|feathers|-|2|e|wild|2|y|
hummingbird|bird|forest|nest|-|feathers|-|2|e|wild|2|y|
hoopoe|bird|grassland,farm|-|-|feathers|-|2|e|wild|2|y|
hornbill|bird|forest|-|-|feathers|-|2|e|wild|4|y|
crane|bird|fresh,grassland|-|-|feathers|-|2|e|wild|5|y|
heron|bird|fresh|-|c|feathers|-|2|e|wild|4|y|
stork|bird|fresh|nest|c|feathers|-|2|e|wild|5|y|
egret|bird|fresh,farm|-|c|feathers|-|2|e|wild|3|y|
flamingo|bird|fresh,sea|-|-|feathers|-|2|e|wild|5|y|
pelican|bird|fresh,sea|-|c|feathers|-|2|e|wild|5|y|
gull|bird|sea|-|-|feathers|-|2|e|wild|3|y|
albatross|bird|sea|-|c|feathers|-|2|e|wild|5|y|
ostrich|bird|grassland,desert|-|-|feathers|-|2|e|wild|6|n|k
emu|bird|grassland,forest|-|-|feathers|-|2|e|wild|6|n|
kiwi|bird|forest|burrow|-|feathers|-|2|e|wild|3|n|
penguin|bird|snow,sea|-|c|feathers|-|2|e|wild|4|n|ca
lovebird|bird|house|-|-|feathers|-|2|e|pet|2|y|
macaw|bird|forest|-|-|feathers|-|2|e|wild|4|y|
toucan|bird|forest|-|-|feathers|-|2|e|wild|3|y|
snake|reptile|forest,grassland,farm,desert|hole,burrow|c|scales|-|0|e|wild|-|n|k
cobra|reptile|forest,farm,grassland|hole,burrow|c|scales|-|0|e|wild|-|n|
king cobra|reptile|forest|-|c|scales|-|0|e|wild|-|n|
python|reptile|forest|-|c|scales|-|0|e|wild|-|n|
rat snake|reptile|farm,forest,grassland|-|c|scales|-|0|e|wild|-|n|
lizard|reptile|house,forest,desert|-|c|scales|-|4|e|wild|2|n|k
gecko|reptile|house,forest|-|c|scales|-|4|e|wild|2|n|
chameleon|reptile|forest|-|c|scales|-|4|e|wild|2|n|
monitor lizard|reptile|forest,grassland|-|c|scales|-|4|e|wild|4|n|
iguana|reptile|forest|-|h|scales|-|4|e|wild|4|n|
crocodile|reptile|fresh|-|c|scales|-|4|e|wild|6|n|ka
alligator|reptile|fresh|-|c|scales|-|4|e|wild|6|n|a
gharial|reptile|fresh|-|c|scales|-|4|e|wild|6|n|a
tortoise|reptile|grassland,forest,desert|-|h|shell|-|4|e|-|3|n|k
turtle|reptile|sea,fresh|-|-|shell|-|-|e|wild|4|n|ka
frog|amphibian|fresh,forest|-|c|skin|tadpole|4|e|wild|2|n|ka
toad|amphibian|forest,farm|-|c|skin|tadpole|4|e|wild|2|n|a
salamander|amphibian|forest,fresh|-|c|skin|-|4|e|wild|2|n|a
fish|fish|fresh,sea|-|-|scales|-|0|e|-|2|n|k
goldfish|fish|fresh|-|-|scales|-|0|e|pet|2|n|
rohu|fish|fresh|-|-|scales|-|0|e|-|4|n|
catla|fish|fresh|-|-|scales|-|0|e|-|4|n|
hilsa|fish|sea,fresh|-|-|scales|-|0|e|-|3|n|
pomfret|fish|sea|-|-|scales|-|0|e|-|3|n|
sardine|fish|sea|-|-|scales|-|0|e|-|2|n|
mackerel|fish|sea|-|c|scales|-|0|e|-|3|n|
tuna|fish|sea|-|c|scales|-|0|e|-|6|n|
salmon|fish|sea,fresh|-|c|scales|-|0|e|-|5|n|
trout|fish|fresh|-|c|scales|-|0|e|-|4|n|
clownfish|fish|sea|-|-|scales|-|0|e|-|2|n|
catfish|fish|fresh|-|-|-|-|0|e|-|4|n|
shark|fish|sea|-|c|-|-|0|-|wild|7|n|k
seahorse|fish|sea|-|c|-|-|0|-|wild|2|n|
swordfish|fish|sea|-|c|-|-|0|e|wild|7|n|
ant|insect|grassland,house,forest|anthill|-|-|-|6|e|-|1|-|k
bee|insect|forest,farm,grassland|hive|-|-|-|6|e|-|1|y|k
butterfly|insect|forest,grassland,house|-|-|-|caterpillar|6|e|wild|1|y|k
moth|insect|forest,house|-|-|-|caterpillar|6|e|-|1|y|
mosquito|insect|house,fresh|-|-|-|-|6|e|-|1|y|k
housefly|insect|house,farm|-|-|-|maggot|6|e|-|1|y|k
cockroach|insect|house|-|o|-|-|6|e|-|1|-|k
grasshopper|insect|grassland,farm|-|h|-|-|6|e|wild|1|y|k
cricket|insect|grassland,house|-|-|-|-|6|e|-|1|-|
ladybird|insect|grassland,farm,forest|-|c|-|-|6|e|-|1|y|k
dragonfly|insect|fresh,grassland|-|c|-|-|6|e|-|1|y|k
beetle|insect|forest,grassland|-|-|-|-|6|e|-|1|-|
termite|insect|soil,forest,house|-|h|-|-|6|e|-|1|-|
firefly|insect|forest,grassland|-|-|-|-|6|e|-|1|y|
wasp|insect|forest,house|-|-|-|-|6|e|-|1|y|
silkworm|insect|farm|-|h|-|-|-|-|farm|2|n|
mantis|insect|grassland,forest|-|c|-|-|6|e|-|1|-|
stick insect|insect|forest|-|h|-|-|6|e|-|2|-|
cicada|insect|forest|-|-|-|-|6|e|-|1|y|
louse|insect|house|-|-|-|-|6|e|-|1|n|
caterpillar|insect|forest,grassland,farm|-|h|-|-|-|-|-|1|n|c
spider|other|house,forest,grassland|web|c|-|-|8|e|-|1|n|ck
scorpion|other|desert,forest|-|c|-|-|8|-|wild|2|n|
earthworm|other|soil|burrow|-|-|-|0|-|-|2|n|k
snail|other|forest,farm,fresh|-|h|shell|-|-|e|-|1|n|k
slug|other|forest,farm|-|h|-|-|-|e|-|1|n|
crab|other|sea,fresh|-|-|shell|-|-|e|-|2|n|ka
prawn|other|sea,fresh|-|-|shell|-|-|e|-|1|n|
lobster|other|sea|-|-|shell|-|-|e|-|3|n|
oyster|other|sea|-|-|shell|-|-|e|-|2|n|
octopus|other|sea|-|c|-|-|-|e|-|4|n|k
squid|other|sea|-|c|-|-|-|e|-|4|n|
starfish|other|sea|-|c|-|-|-|-|-|2|n|c
jellyfish|other|sea|-|c|-|-|-|-|-|3|n|c
centipede|other|forest,soil,house|-|c|-|-|-|e|-|1|n|
millipede|other|forest,soil|-|-|-|-|-|e|-|1|n|
leech|other|fresh|-|-|-|-|0|-|-|1|n|
""", 13)

# Sounds: animal -> (verb, noise or -). Distractor verbs are never one the animal makes.
SOUNDS = rows("""
cow|moos|Moo
buffalo|moos|-
dog|barks|Woof
cat|meows|Meow
duck|quacks|Quack
horse|neighs|Neigh
donkey|brays|Hee-haw
sheep|bleats|Baa
goat|bleats|-
lion|roars|Roar
tiger|roars|-
snake|hisses|Hiss
cobra|hisses|-
bee|buzzes|Buzz
mosquito|buzzes|-
housefly|buzzes|-
hen|clucks|Cluck
pigeon|coos|Coo
crow|caws|Caw
frog|croaks|Croak
elephant|trumpets|-
wolf|howls|-
jackal|howls|-
owl|hoots|Hoot
mouse|squeaks|Squeak
pig|grunts|Oink
monkey|chatters|-
bear|growls|-
sparrow|chirps|Chirp
cricket|chirps|-
hyena|laughs|-
""", 3)

# Birds: beak and feet (OWW 4). beak: hooked, flat, long-thin, long-pointed, short-strong, chisel, pouch.
# feet: webbed, talons, perching, climbing, wading, scratching.
BIRDS = rows("""
eagle|hooked|talons
vulture|hooked|talons
hawk|hooked|talons
falcon|hooked|talons
owl|hooked|talons
parrot|hooked|climbing
duck|flat|webbed
swan|flat|webbed
goose|flat|webbed
sunbird|long-thin|perching
hummingbird|long-thin|-
kingfisher|long-pointed|-
heron|long-pointed|wading
crane|long-pointed|wading
stork|long-pointed|wading
egret|long-pointed|wading
flamingo|-|wading
sparrow|short-strong|perching
weaverbird|short-strong|perching
woodpecker|chisel|climbing
pelican|pouch|webbed
gull|-|webbed
albatross|hooked|webbed
crow|-|perching
myna|-|perching
bulbul|-|perching
tailorbird|-|perching
hen|-|scratching
peacock|-|scratching
quail|-|scratching
turkey|-|scratching
""", 3)

# How animals move (Class 1). yes = verbs it surely does; no = verbs it surely cannot do.
# Verbs: fly swim hop crawl. Swimming is only asked as yes (most land animals can swim a little).
MOVES = rows("""
sparrow|fly|swim,crawl
crow|fly|swim,crawl
pigeon|fly|swim,crawl
parrot|fly|swim,crawl
eagle|fly|swim,crawl
butterfly|fly|swim,hop
bee|fly|swim,hop
dragonfly|fly|-
housefly|fly|swim
duck|swim|crawl,hop
swan|fly,swim|crawl,hop
fish|swim|fly,hop,crawl
goldfish|swim|fly,hop,crawl
shark|swim|fly,hop,crawl
frog|hop,swim|fly
toad|hop|fly
kangaroo|hop|fly,crawl
rabbit|hop|fly,crawl
grasshopper|hop,fly|swim
snake|crawl|fly,hop
earthworm|crawl|fly,hop
snail|crawl|fly,hop
caterpillar|crawl|fly,hop
lizard|crawl|fly,hop
cow|-|fly,hop,crawl
elephant|-|fly,hop,crawl
horse|-|fly,crawl
camel|-|fly,hop,crawl
giraffe|-|fly,hop,crawl
cat|-|fly
dog|-|fly
lion|-|fly
tiger|-|fly
goat|-|fly
crocodile|swim,crawl|fly,hop
turtle|swim,crawl|fly,hop
tortoise|crawl|fly,hop
ostrich|-|fly,crawl
hen|-|crawl
dolphin|swim|fly,hop,crawl
whale|swim|fly,hop,crawl
octopus|swim|fly,hop
seal|swim|fly
""", 3)

# ---------------------------------------------------------------- plants
# name | type tree/shrub/herb/climber/creeper (- = arguable) | products we get | seed travel | why | flags
# Products: oil fibre rubber tea coffee sugar spice dye medicine wood food.
# flags: n = gives none of oil/fibre/rubber/tea/coffee/sugar/spice/dye/medicine (safe wrong option).
PLANTS = rows("""
mango|tree|food,wood,spice|-|-|
neem|tree|medicine,wood,oil|-|-|
banyan|tree|-|animal|birds eat its small figs|n
peepal|tree|-|animal|birds eat its small figs|n
coconut|tree|food,oil,fibre|water|it floats on water|
teak|tree|wood|-|-|n
sal|tree|wood|wind|it has wings|
sheesham|tree|wood|-|-|
pine|tree|wood|wind|it has wings|
deodar|tree|wood|-|-|
eucalyptus|tree|wood,oil|-|-|
jamun|tree|food|animal|birds eat its fruits|
guava|tree|food|animal|birds eat its fruits|n
tamarind|tree|food|-|-|
ashoka|tree|-|-|-|
gulmohar|tree|-|-|-|n
amaltas|tree|-|-|-|
jackfruit|tree|food,wood|-|-|
papaya|-|food|-|-|
banana|-|food|-|-|
date palm|tree|food,sugar|-|-|
bamboo|-|-|-|-|
apple|tree|food|-|-|n
orange|tree|food|-|-|
lemon|-|food|-|-|
litchi|tree|food|-|-|n
chikoo|tree|food|-|-|n
silk cotton|tree|fibre|wind|it has silky hairs|
rubber|tree|rubber,wood|-|-|
cashew|tree|food|-|-|
almond|tree|food,oil|-|-|
walnut|tree|food,wood|-|-|
arjun|tree|wood|-|-|
babool|tree|wood|-|-|
kadamba|tree|-|-|-|n
sandalwood|tree|wood,oil|animal|birds eat its fruits|
cinnamon|tree|spice|-|-|
clove|tree|spice|-|-|
drumstick|tree|food|wind|it has wings|
maple|tree|wood,sugar|wind|it has wings|
oak|tree|wood|-|-|
mulberry|-|food|animal|birds eat its fruits|
amla|tree|food,medicine|-|-|
cotton|shrub|fibre,oil|wind|it has fluffy hairs|
jute|-|fibre|-|-|
tea|shrub|tea|-|-|
coffee|shrub|coffee|-|-|
rose|shrub|-|-|-|
hibiscus|shrub|-|-|-|
jasmine|-|-|-|-|
tulsi|-|medicine|-|-|
henna|shrub|dye|-|-|
indigo|shrub|dye|-|-|
oleander|shrub|-|-|-|
lantana|shrub|-|animal|birds eat its berries|
curry leaf|-|food|-|-|
chilli|-|food,spice|-|-|
brinjal|-|food|-|-|
tomato|-|food|-|-|
aloe vera|-|medicine|-|-|
cactus|-|-|-|-|
bougainvillea|-|-|-|-|
madar|shrub|-|wind|it has silky hairs|
castor|-|oil|burst|its seed pods burst open|
balsam|herb|-|burst|its seed pods burst open|
lady's finger|-|food|burst|its dry pods split open|
xanthium|-|-|animal|it has hooks|
burdock|-|-|animal|it has hooks|
spear grass|-|-|animal|it sticks to clothes|
dandelion|herb|-|wind|it has fluffy hairs|
sunflower|herb|oil|-|-|
mustard|herb|oil,food,spice|-|-|
groundnut|herb|oil,food|-|-|
sesame|herb|oil,food|-|-|
soybean|herb|oil,food|-|-|
sugarcane|-|sugar|-|-|
wheat|herb|food|-|-|
rice|herb|food|-|-|
maize|-|food|-|-|
mint|herb|food|-|-|
coriander|herb|food,spice|-|-|
spinach|herb|food|-|-|n
radish|herb|food|-|-|n
carrot|herb|food|-|-|n
onion|herb|food|-|-|
garlic|herb|food|-|-|
ginger|herb|food,spice|-|-|
turmeric|herb|spice,medicine,dye|-|-|
methi|herb|food|-|-|
cabbage|herb|food|-|-|n
cauliflower|herb|food|-|-|n
marigold|herb|-|-|-|
lily|herb|-|-|-|n
grass|herb|-|-|-|n
cumin|herb|spice|-|-|
fennel|herb|spice|-|-|
cardamom|-|spice|-|-|
saffron|-|spice,dye|-|-|
lotus|-|food|water|its seeds float on water|
water lily|-|-|water|its seeds float on water|
money plant|climber|-|-|-|n
grapevine|climber|food|-|-|
pea|climber|food|burst|its seed pods burst open|
bean|-|food|burst|its seed pods burst open|
bitter gourd|climber|food|-|-|n
bottle gourd|-|food|-|-|n
cucumber|-|food|-|-|
black pepper|climber|spice|-|-|
betel|climber|-|-|-|
morning glory|climber|-|-|-|n
passion fruit|climber|food|-|-|
pumpkin|creeper|food|-|-|
watermelon|creeper|food|-|-|
muskmelon|creeper|food|-|-|
sweet potato|creeper|food|-|-|
strawberry|-|food|-|-|
""", 6)

# ---------------------------------------------------------------- foods
# name | form s(a mango)/pl(grapes)/m(rice) | fruit/veg (- arguable) | from plant/animal (- arguable) |
# part we eat | rich in (c carbohydrates p proteins f fats v vitamins and minerals) | surely not rich in |
# raw/cooked/both | cooked by steam/fry/bake/boil/roast | healthy h / junk j | tastes
FOODS = rows("""
mango|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
apple|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
banana|s|fruit|plant|fruit|c,v|p,f|raw|-|h|sweet
orange|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet,sour
grapes|pl|fruit|plant|fruit|v|p,f|raw|-|h|sweet,sour
guava|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
papaya|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
pineapple|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet,sour
watermelon|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
muskmelon|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
pomegranate|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
litchi|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
chikoo|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
custard apple|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
jamun|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
amla|s|fruit|plant|fruit|v|p,f|raw|-|h|sour
strawberry|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet,sour
cherry|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
plum|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet,sour
pear|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
peach|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
kiwi|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet,sour
fig|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
dates|pl|fruit|plant|fruit|c,v|p,f|raw|-|h|sweet
sweet lime|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
ber|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet,sour
apricot|s|fruit|plant|fruit|v|p,f|raw|-|h|sweet
jackfruit|s|-|plant|fruit|-|-|-|-|h|-
lemon|s|-|plant|fruit|v|p,f|raw|-|h|sour
coconut|s|-|plant|fruit|-|-|both|-|h|-
tamarind|m|-|plant|fruit|-|-|-|-|-|sour
raw mango|s|-|plant|fruit|v|p,f|both|-|h|sour
carrot|s|veg|plant|root|v|p,f|both|-|h|sweet
radish|s|veg|plant|root|v|p,f|both|-|h|-
beetroot|s|veg|plant|root|v|p,f|both|-|h|sweet
turnip|s|veg|plant|root|v|p,f|both|-|h|-
sweet potato|s|veg|plant|root|c,v|p,f|cooked|-|h|sweet
tapioca|m|veg|plant|root|c|p,f|cooked|-|h|-
potato|s|veg|plant|stem|c|p,f|cooked|-|h|-
ginger|m|-|plant|stem|-|-|both|-|h|spicy
turmeric|m|-|plant|stem|-|-|-|-|h|-
lotus stem|s|veg|plant|stem|v|f|cooked|-|h|-
bamboo shoot|s|veg|plant|stem|v|f|cooked|-|h|-
sugarcane|m|-|plant|stem|c|p,f|raw|-|-|sweet
spinach|m|veg|plant|leaf|v|p,f|both|-|h|-
cabbage|s|veg|plant|leaf|v|p,f|both|-|h|-
lettuce|m|veg|plant|leaf|v|p,f|raw|-|h|-
methi|m|veg|plant|leaf|v|f|cooked|-|h|bitter
mint|m|-|plant|leaf|v|f|raw|-|h|-
coriander leaves|pl|-|plant|leaf|v|f|raw|-|h|-
curry leaves|pl|-|plant|leaf|-|-|-|-|h|-
mustard leaves|pl|veg|plant|leaf|v|f|cooked|-|h|-
tea|m|-|plant|leaf|-|-|-|boil|-|-
cauliflower|s|veg|plant|flower|v|p,f|both|-|h|-
broccoli|m|veg|plant|flower|v|f|both|-|h|-
banana flower|s|veg|plant|flower|v|f|cooked|-|h|-
clove|s|-|plant|flower|-|-|-|-|-|spicy
brinjal|s|veg|plant|fruit|v|p,f|cooked|-|h|-
lady's finger|s|veg|plant|fruit|v|p,f|-|-|h|-
bitter gourd|s|veg|plant|fruit|v|p,f|-|-|h|bitter
bottle gourd|s|veg|plant|fruit|v|p,f|cooked|-|h|-
drumstick|s|veg|plant|fruit|v|f|cooked|-|h|-
beans|pl|veg|plant|-|v|f|cooked|-|h|-
pumpkin|s|-|plant|fruit|v|p,f|cooked|-|h|-
cucumber|s|-|plant|fruit|v|p,f|raw|-|h|-
tomato|s|-|plant|fruit|v|p,f|both|-|h|sour
capsicum|s|-|plant|fruit|v|p,f|both|-|h|-
green chilli|s|-|plant|fruit|-|-|-|-|-|spicy
onion|s|veg|plant|-|v|p,f|both|-|h|-
garlic|m|-|plant|-|-|-|cooked|-|h|-
mushroom|s|-|-|-|-|-|-|-|h|-
corn|m|-|plant|seed|c|f|cooked|-|h|-
peas|pl|veg|plant|seed|p,v|f|both|-|h|sweet
rice|m|-|plant|seed|c|p,f|cooked|boil|h|-
wheat|m|-|plant|seed|c|f|cooked|-|h|-
ragi|m|-|plant|seed|c|f|cooked|-|h|-
bajra|m|-|plant|seed|c|f|cooked|-|h|-
jowar|m|-|plant|seed|c|f|cooked|-|h|-
oats|pl|-|plant|seed|c|f|cooked|-|h|-
moong dal|m|-|plant|seed|p|f|cooked|boil|h|-
masoor dal|m|-|plant|seed|p|f|cooked|boil|h|-
urad dal|m|-|plant|seed|p|f|cooked|boil|h|-
chana|m|-|plant|seed|p|f|cooked|-|h|-
rajma|m|-|plant|seed|p|f|cooked|-|h|-
soybean|m|-|plant|seed|p,f|-|cooked|-|h|-
sprouts|pl|-|plant|seed|p|f|both|-|h|-
groundnuts|pl|-|plant|seed|p,f|-|both|-|h|-
almonds|pl|-|plant|seed|p,f|-|raw|-|h|-
cashews|pl|-|plant|seed|p,f|-|-|-|h|-
walnuts|pl|-|plant|seed|f|-|raw|-|h|-
sesame seeds|pl|-|plant|seed|f|-|-|-|h|-
mustard seeds|pl|-|plant|seed|-|-|-|-|-|-
cumin seeds|pl|-|plant|seed|-|-|-|-|-|-
black pepper|m|-|plant|seed|-|-|-|-|-|spicy
coffee|m|-|plant|seed|-|-|-|-|-|bitter
sugar|m|-|plant|-|c|p,f,v|-|-|-|sweet
jaggery|m|-|plant|-|c|p,f|-|-|-|sweet
mustard oil|m|-|plant|-|f|c,p,v|-|-|-|-
coconut oil|m|-|plant|-|f|c,p,v|-|-|-|-
tofu|m|-|plant|-|p|-|-|-|h|-
bread|m|-|plant|-|c|f|cooked|bake|-|-
roti|s|-|plant|-|c|f|cooked|-|h|-
poha|m|-|plant|-|c|f|cooked|-|h|-
idli|s|-|-|-|-|-|cooked|steam|h|-
dosa|s|-|-|-|-|-|cooked|-|h|-
upma|m|-|-|-|c|-|cooked|-|h|-
khichdi|m|-|-|-|-|-|cooked|-|h|-
dhokla|s|-|-|-|-|-|cooked|steam|h|-
puttu|m|-|-|-|c|-|cooked|steam|h|-
idiyappam|m|-|-|-|c|-|cooked|steam|h|-
sambar|m|-|-|-|-|-|cooked|-|h|-
momos|pl|-|-|-|-|-|cooked|steam|-|-
samosa|s|-|-|-|-|-|cooked|fry|-|spicy
pakora|s|-|-|-|-|-|cooked|fry|-|-
puri|s|-|-|-|-|-|cooked|fry|-|-
vada|s|-|-|-|-|-|cooked|fry|-|-
bhatura|s|-|-|-|-|-|cooked|fry|-|-
kachori|s|-|-|-|-|-|cooked|fry|-|-
jalebi|s|-|-|-|-|-|cooked|fry|-|sweet
gulab jamun|s|-|-|-|-|-|cooked|fry|-|sweet
rasgulla|s|-|animal|-|-|-|cooked|-|-|sweet
laddoo|s|-|-|-|-|-|-|-|-|sweet
cake|s|-|-|-|-|-|cooked|bake|-|sweet
biscuit|s|-|-|-|-|-|cooked|bake|-|-
bun|s|-|-|-|-|-|cooked|bake|-|-
pizza|s|-|-|-|-|-|cooked|bake|j|-
burger|s|-|-|-|-|-|cooked|-|j|-
chips|pl|-|plant|-|-|-|cooked|fry|j|salty
French fries|pl|-|plant|-|-|-|cooked|fry|j|salty
instant noodles|pl|-|-|-|-|-|cooked|-|j|-
cola|m|-|-|-|-|-|-|-|j|sweet
toffee|s|-|-|-|-|-|-|-|j|sweet
lollipop|s|-|-|-|-|-|-|-|j|sweet
candyfloss|m|-|-|-|-|-|-|-|j|sweet
pastry|s|-|-|-|-|-|cooked|bake|j|sweet
cream biscuits|pl|-|-|-|-|-|-|-|j|sweet
doughnut|s|-|-|-|-|-|cooked|fry|j|sweet
bhutta|s|-|plant|seed|c|f|cooked|roast|h|-
popcorn|m|-|plant|seed|-|-|cooked|-|-|-
papad|s|-|plant|-|-|-|cooked|-|-|salty
pickle|m|-|-|-|-|-|-|-|-|-
salt|m|-|-|-|-|-|-|-|-|salty
honey|m|-|animal|-|c|p,f|raw|-|-|sweet
milk|m|-|animal|-|-|-|-|-|h|-
curd|m|-|animal|-|-|-|raw|-|h|sour
buttermilk|m|-|animal|-|-|-|raw|-|h|-
paneer|m|-|animal|-|p,f|c|both|-|h|-
cheese|m|-|animal|-|p,f|c|raw|-|-|-
butter|m|-|animal|-|f|c,p|raw|-|-|-
ghee|m|-|animal|-|f|c,p|-|-|-|-
cream|m|-|animal|-|f|p|raw|-|-|-
egg|s|-|animal|-|p|c|cooked|-|h|-
chicken|m|-|animal|-|p|c|cooked|-|h|-
fish|m|-|animal|-|p|c|cooked|-|h|-
mutton|m|-|animal|-|p,f|c|cooked|-|-|-
prawns|pl|-|animal|-|p|c|cooked|-|h|-
lassi|m|-|animal|-|-|-|raw|-|h|sweet
coconut water|m|-|plant|-|v|p,f|raw|-|h|-
neem leaves|pl|-|plant|leaf|-|-|-|-|-|bitter
karela juice|m|-|plant|-|-|-|raw|-|h|bitter
salted peanuts|pl|-|plant|seed|-|-|-|-|-|salty
namkeen|m|-|-|-|-|-|-|-|-|salty
red chilli powder|m|-|plant|-|-|-|-|-|-|spicy
kheer|m|-|-|-|-|-|cooked|-|-|sweet
halwa|m|-|-|-|-|-|cooked|-|-|sweet
tomato sauce|m|-|plant|-|-|-|-|-|-|sweet,sour
""", 11)

# ---------------------------------------------------------------- objects and materials
# name | form s/pl/m | made of | magnetic y/n | see-through y/n | floats y/n | waste wet/dry | natural y/n | hard/soft
# '-' = arguable (steel can be non-magnetic; translucent things; paper floats then sinks).
OBJECTS = rows("""
wooden chair|s|wood|n|n|-|-|n|h
plastic chair|s|plastic|n|n|-|-|n|h
wooden table|s|wood|n|n|-|-|n|h
wooden spoon|s|wood|n|n|y|-|n|h
plastic spoon|s|plastic|n|n|-|dry|n|h
steel spoon|s|metal|-|n|n|-|n|h
steel plate|s|metal|-|n|-|-|n|h
steel tumbler|s|metal|-|n|-|-|n|h
iron nail|s|metal|y|n|n|-|n|h
iron key|s|metal|y|n|n|-|n|h
iron chain|s|metal|y|n|n|-|n|h
iron rod|s|metal|y|n|n|-|n|h
iron gate|s|metal|y|n|-|-|n|h
iron tawa|s|metal|y|n|n|-|n|h
iron kadhai|s|metal|y|n|-|-|n|h
iron filings|pl|metal|y|n|n|-|n|-
safety pin|s|metal|y|n|n|-|n|h
paper clip|s|metal|y|n|n|-|n|h
needle|s|metal|y|n|n|-|n|h
tin can|s|metal|y|n|-|dry|n|h
coin|s|metal|-|n|n|-|n|h
scissors|pl|metal|-|n|n|-|n|h
aluminium can|s|metal|n|n|-|dry|n|h
aluminium foil|m|metal|n|n|-|dry|n|-
aluminium pot|s|metal|n|n|-|-|n|h
copper wire|s|metal|n|n|n|-|n|-
copper pot|s|metal|n|n|-|-|n|h
gold ring|s|metal|n|n|n|-|n|h
gold chain|s|metal|n|n|n|-|n|-
silver bangle|s|metal|n|n|n|-|n|h
silver spoon|s|metal|n|n|n|-|n|h
pressure cooker|s|metal|-|n|-|-|n|h
window pane|s|glass|n|y|-|-|n|h
glass tumbler|s|glass|n|y|-|-|n|h
glass jar|s|glass|n|y|-|dry|n|h
glass bottle|s|glass|n|y|-|dry|n|h
glass door|s|glass|n|y|-|-|n|h
glass marble|s|glass|n|-|n|-|n|h
broken glass|m|glass|n|-|-|dry|n|h
mirror|s|glass|n|n|-|-|n|h
spectacles|pl|-|-|y|-|-|n|-
empty plastic bottle|s|plastic|n|-|y|dry|n|-
plastic bucket|s|plastic|n|n|-|-|n|h
plastic mug|s|plastic|n|n|-|-|n|h
plastic comb|s|plastic|n|n|-|dry|n|h
plastic plate|s|plastic|n|n|-|dry|n|h
plastic lunch box|s|plastic|n|n|-|-|n|h
plastic pipe|s|plastic|n|n|-|-|n|h
toothbrush|s|plastic|n|n|-|dry|n|-
plastic bag|s|plastic|n|-|-|dry|n|s
chips packet|s|plastic|n|n|-|dry|n|s
milk packet|s|plastic|n|-|-|dry|n|s
cellophane sheet|s|plastic|n|y|-|dry|n|s
plastic toy|s|plastic|n|n|-|dry|n|-
plastic straw|s|plastic|n|-|y|dry|n|-
ball pen|s|plastic|n|n|-|dry|n|h
raincoat|s|plastic|n|-|-|-|n|s
thermocol|m|plastic|n|n|y|dry|n|s
plastic ball|s|plastic|n|n|y|-|n|-
newspaper|s|paper|n|n|-|dry|n|s
notebook|s|paper|n|n|-|dry|n|-
paper bag|s|paper|n|n|-|dry|n|s
cardboard box|s|paper|n|n|-|dry|n|-
paper plate|s|paper|n|n|-|dry|n|-
paper cup|s|paper|n|n|-|dry|n|-
kite|s|paper|n|n|-|-|n|s
tissue paper|m|paper|n|-|-|-|n|s
butter paper|m|paper|n|-|-|-|n|s
book|s|paper|n|n|-|-|n|-
paper boat|s|paper|n|n|y|-|n|s
pencil|s|wood|n|n|y|dry|n|h
cricket bat|s|wood|n|n|y|-|n|h
wooden block|s|wood|n|n|y|-|n|h
wooden door|s|wood|n|n|-|-|n|h
wooden comb|s|wood|n|n|y|-|n|h
matchstick|s|wood|n|n|y|-|n|h
log of wood|s|wood|n|n|y|-|y|h
twig|s|wood|n|n|y|wet|y|-
cotton shirt|s|cloth|n|n|-|dry|n|s
saree|s|cloth|n|n|-|-|n|s
towel|s|cloth|n|n|-|-|n|s
handkerchief|s|cloth|n|n|-|-|n|s
pillow|s|cloth|n|n|-|-|n|s
bedsheet|s|cloth|n|n|-|-|n|s
curtain|s|cloth|n|-|-|-|n|s
old clothes|pl|cloth|n|n|-|dry|n|s
woollen sweater|s|wool|n|n|-|-|n|s
woollen cap|s|wool|n|n|-|-|n|s
woollen socks|pl|wool|n|n|-|-|n|s
leather belt|s|leather|n|n|-|-|n|-
leather bag|s|leather|n|n|-|-|n|-
leather shoes|pl|leather|n|n|-|-|n|-
clay pot|s|clay|n|n|-|-|n|h
clay diya|s|clay|n|n|-|-|n|h
kulhad|s|clay|n|n|-|-|n|h
clay toy|s|clay|n|n|-|-|n|h
brick|s|clay|n|n|n|-|n|h
rubber band|s|rubber|n|n|-|dry|n|s
tyre|s|rubber|n|n|-|dry|n|-
balloon|s|rubber|n|-|y|dry|n|s
rubber ball|s|rubber|n|n|y|-|n|-
rubber gloves|pl|rubber|n|n|-|dry|n|s
candle|s|wax|n|n|y|-|n|h
crayon|s|wax|n|n|-|-|n|-
stone|s|stone|n|n|n|-|y|h
pebble|s|stone|n|n|n|-|y|h
rock|s|stone|n|n|n|-|y|h
sand|m|-|-|n|n|-|y|-
soil|m|-|-|n|n|-|y|-
clay|m|-|n|n|n|-|y|s
coal|m|-|n|n|n|-|y|h
feather|s|-|n|n|y|-|y|s
seashell|s|-|n|n|n|-|y|h
cork|s|-|n|n|y|-|-|-
sponge|s|-|n|n|y|dry|-|s
ice cube|s|-|n|-|y|-|-|h
cotton ball|s|-|n|n|-|-|-|s
water|m|-|n|y|-|-|y|-
air|m|-|n|y|-|-|y|-
cooking oil|m|-|n|-|y|-|-|-
banana peel|s|-|n|n|-|wet|y|s
vegetable peels|pl|-|n|n|-|wet|y|s
fruit peels|pl|-|n|n|-|wet|y|s
leftover food|m|-|n|n|-|wet|-|s
used tea leaves|pl|-|n|n|-|wet|y|-
eggshells|pl|-|n|n|-|wet|y|h
rotten fruit|s|-|n|n|-|wet|y|s
old flowers|pl|-|n|n|-|wet|y|s
onion peels|pl|-|n|n|-|wet|y|s
dry leaves|pl|-|n|n|y|wet|y|-
""", 9)

# Non-living things that seem alive (they move, grow or change), and living ones that seem not.
NONLIVING_TRICKY = rows("""
sun|it gives light but does not breathe or grow
moon|it shines but does not eat or breathe
cloud|it moves but does not eat or grow
river|it flows but does not breathe or grow
wind|it moves but does not eat or grow
fire|it spreads but does not breathe or grow
rain|it falls but does not eat or grow
star|it shines but does not breathe or grow
car|it moves but does not eat or grow
train|it moves but does not eat or grow
aeroplane|it flies but does not eat or grow
robot|it moves but does not eat or grow
ceiling fan|it turns but does not eat or grow
clock|it ticks but does not breathe or grow
bicycle|it moves but does not eat or grow
boat|it floats but does not eat or grow
mountain|it is big but does not breathe or grow
""", 2)
# Never asked as living or non-living (children argue both ways): seed, egg, dry leaves, wood, cotton.

# ---------------------------------------------------------------- helpers
# name | tools | workplaces | what they do (each "they ..." phrase) | what they make
HELPERS = rows("""
doctor|stethoscope,thermometer,syringe|hospital,clinic|treats sick people,gives us medicines|-
nurse|stethoscope,thermometer,syringe,bandage|hospital,clinic|looks after patients,treats sick people|-
farmer|plough,sickle,spade|field|grows our food|grains
teacher|chalk,blackboard,duster|school|teaches children|-
tailor|needle,thread,sewing machine,measuring tape,scissors|tailor's shop|stitches clothes|clothes
barber|scissors,comb,razor|salon|cuts hair|-
cobbler|needle,thread,hammer|roadside stall|mends shoes|shoes
carpenter|saw,hammer,chisel,measuring tape,screwdriver|workshop|makes furniture|furniture
potter|potter's wheel,clay|workshop|makes clay pots|pots and diyas
weaver|loom,thread|workshop|weaves cloth|cloth
blacksmith|anvil,hammer,tongs|workshop|makes iron tools|iron tools
goldsmith|hammer,tongs|jewellery shop|makes jewellery|jewellery
mason|trowel,bricks,cement,measuring tape|building site|builds walls and houses|walls
plumber|spanner,pipes|-|fixes leaking taps|-
electrician|screwdriver,tester,wire|-|fixes wires and fans|-
mechanic|spanner,screwdriver,jack|garage|repairs cars|-
painter|paintbrush,roller,paint|-|paints walls|-
gardener|watering can,spade,trowel,hose|garden|looks after plants|-
fisherman|fishing net,boat,fishing rod|sea,river|catches fish|-
milkman|milk can|dairy|brings us milk|-
postman|letters,parcels|post office|delivers letters|-
police officer|whistle|police station|keeps us safe,catches thieves|-
firefighter|hose,fire engine,ladder|fire station|puts out fires|-
pilot|aeroplane|airport|flies aeroplanes|-
bus driver|bus,steering wheel|bus depot|drives a bus|-
cook|ladle,tawa,pressure cooker|kitchen,restaurant|cooks food|food
baker|oven|bakery|bakes bread and cakes|bread and cakes
dentist|dental mirror,drill|dental clinic|looks after our teeth|-
vegetable seller|weighing scale,cart|market|sells vegetables|-
shopkeeper|weighing scale|shop|sells things|-
sweeper|broom,dustbin|street|keeps streets clean|-
vet|stethoscope,thermometer,syringe|animal hospital|treats sick animals|-
pharmacist|medicines|chemist shop|gives us medicines|-
photographer|camera|studio|takes photos|photos
astronaut|spacesuit,rocket|space station|goes to space|-
librarian|books|library|lends us books|-
scientist|microscope|laboratory|does experiments|-
soldier|-|army camp|guards our borders,keeps us safe|-
""", 5)

# ---------------------------------------------------------------- transport
# name | land/water/air | wheels | moved by (pedal, animal, wind, paddle, -)
TRANSPORT = rows("""
bus|land|-|-
car|land|4|-
truck|land|-|-
bicycle|land|2|pedal
motorcycle|land|2|-
scooter|land|2|-
auto-rickshaw|land|3|-
cycle-rickshaw|land|3|pedal
e-rickshaw|land|3|-
tricycle|land|3|pedal
jeep|land|4|-
taxi|land|4|-
van|land|4|-
ambulance|land|-|-
fire engine|land|-|-
tractor|land|-|-
train|land|-|-
metro|land|-|-
tram|land|-|-
bullock cart|land|2|animal
tonga|land|2|animal
camel cart|land|-|animal
sledge|land|-|-
boat|water|-|-
ship|water|-|-
ferry|water|-|-
steamer|water|-|-
submarine|water|-|-
canoe|water|-|paddle
raft|water|-|-
sailboat|water|-|wind
shikara|water|-|paddle
kayak|water|-|paddle
yacht|water|-|-
motorboat|water|-|-
cruise ship|water|-|-
snake boat|water|-|paddle
aeroplane|air|-|-
helicopter|air|-|-
hot air balloon|air|-|-
glider|air|-|-
jet plane|air|-|-
""", 4)

# ---------------------------------------------------------------- the body
# part | how many (- if it varies) | count question
BODY_PARTS = rows("""
eyes|2|How many eyes do we have?
ears|2|How many ears do we have?
nose|1|How many noses do we have?
mouth|1|How many mouths do we have?
tongue|1|How many tongues do we have?
hands|2|How many hands do we have?
legs|2|How many legs do we have?
feet|2|How many feet do we have?
fingers|5|How many fingers are on one hand?
toes|5|How many toes are on one foot?
thumbs|2|How many thumbs do we have?
knees|2|How many knees do we have?
elbows|2|How many elbows do we have?
neck|1|How many necks do we have?
head|1|How many heads do we have?
lips|2|How many lips do we have?
eyebrows|2|How many eyebrows do we have?
nostrils|2|How many nostrils are in a nose?
shoulders|2|How many shoulders do we have?
wrists|2|How many wrists do we have?
ankles|2|How many ankles do we have?
cheeks|2|How many cheeks do we have?
chin|1|How many chins do we have?
heart|1|How many hearts do we have?
lungs|2|How many lungs do we have?
brain|1|How many brains do we have?
teeth|-|-
skin|-|-
hair|-|-
nails|-|-
""", 3)

# We <verb> with our <part>. Every part that can do it is listed.
BODY_USES = rows("""
see|eyes
blink|eyes
hear|ears
smell|nose
taste|tongue
chew food|teeth
bite|teeth
clap|hands
wave|hands
write|hands,fingers
hold a pencil|hands,fingers
walk|legs,feet
run|legs,feet
kick a ball|legs,feet
jump|legs,feet
kneel|knees
nod|head,neck
think|brain
breathe|nose,mouth,lungs
talk|mouth,tongue,lips
smile|lips,mouth,cheeks
feel hot and cold|skin,hands,fingers,feet,lips,cheeks,tongue
""", 2)

# We wear <thing> on our <part>.
WEAR = rows("""
a cap|head
a turban|head
shoes|feet
socks|feet
sandals|feet
gloves|hands
a watch|wrist
a ring|finger
bangles|wrists
earrings|ears
spectacles|eyes
a necklace|neck
a scarf|neck
a belt|waist
anklets|ankles
a bindi|forehead
a nose pin|nose
""", 2)

# ---------------------------------------------------------------- houses
# house | kutcha/pucca/- | made of | features (keys in HOUSE_FEATURES)
HOUSES = rows("""
hut|kutcha|mud,straw,bamboo|-
mud house|kutcha|mud,straw|thick
brick house|pucca|bricks,cement|-
block of flats|pucca|bricks,cement|flats
houseboat|-|wood|floats,kashmir
stilt house|-|bamboo,wood|stilts
igloo|-|ice,snow|ice,snow
tent|-|cloth|carry
tree house|-|wood|tree
wooden house|-|wood|slope
bungalow|pucca|bricks,cement|-
stone house|pucca|stone,cement|slope
bamboo hut|kutcha|bamboo,straw|-
""", 4)
HOUSE_FEATURES = rows("""
thick|has thick mud walls that keep it cool|Thick mud walls keep the heat out.
flats|has many families living in one building|Many families share one tall building.
floats|floats on water|It is built on a boat.
kashmir|is found on the Dal Lake in Kashmir|Houseboats float on the Dal Lake.
stilts|stands on tall poles|Poles keep it above flood water.
ice|is made of blocks of snow and ice|Snow blocks are packed tightly together.
snow|is built in very cold, snowy places|It is made where snow is everywhere.
carry|can be folded and carried|Cloth and poles fold up easily.
tree|is built in the branches of a tree|It rests on strong branches.
slope|has a sloping roof for rain and snow|Rain and snow slide off sloping roofs.
""", 3)
HOUSE_MATERIALS = ["mud", "straw", "bamboo", "wood", "bricks", "cement", "ice", "snow", "cloth", "stone"]
# Kutcha (mud, straw, bamboo) or pucca (bricks, cement, stone) parts of a house.
KUTCHA_PUCCA = rows("""
mud walls|kutcha
straw roof|kutcha
bamboo walls|kutcha
floor of mud|kutcha
roof of leaves|kutcha
brick walls|pucca
cement floor|pucca
concrete roof|pucca
stone walls|pucca
cement walls|pucca
marble floor|pucca
grass roof|kutcha
floor of cow dung|kutcha
wooden poles|kutcha
steel rods in walls|pucca
tiled floor|pucca
""", 2)

# ---------------------------------------------------------------- India (28 states, 8 UTs since 2020)
# name | state/ut | capital (- if changing or two) | main languages | dances | big festivals
# Left out on purpose: Andhra Pradesh capital (in flux), J&K (two capitals), Andaman and Nicobar
# (capital renamed 2024), Chandigarh as a "state". Kathak and Chhau are shared by several states.
INDIA = rows("""
Andhra Pradesh|state|-|Telugu|Kuchipudi|Ugadi
Arunachal Pradesh|state|Itanagar|-|-|-
Assam|state|Dispur|Assamese|Bihu,Sattriya|Bihu,Durga Puja
Bihar|state|Patna|Hindi|Jat-Jatin|Chhath
Chhattisgarh|state|Raipur|Hindi|Panthi,Raut Nacha|-
Goa|state|Panaji|Konkani|Dekhni|-
Gujarat|state|Gandhinagar|Gujarati|Garba,Dandiya|Navratri,Makar Sankranti
Haryana|state|Chandigarh|Hindi|-|Lohri,Baisakhi
Himachal Pradesh|state|Shimla|Hindi|Nati|Lohri
Jharkhand|state|Ranchi|Hindi|-|Chhath,Durga Puja
Karnataka|state|Bengaluru|Kannada|Yakshagana,Dollu Kunitha|Ugadi,Makar Sankranti,Ganesh Chaturthi
Kerala|state|Thiruvananthapuram|Malayalam|Kathakali,Mohiniyattam|Onam,Vishu
Madhya Pradesh|state|Bhopal|Hindi|-|-
Maharashtra|state|Mumbai|Marathi|Lavani|Gudi Padwa,Ganesh Chaturthi,Makar Sankranti
Manipur|state|Imphal|Manipuri|Manipuri|-
Meghalaya|state|Shillong|-|Wangala|-
Mizoram|state|Aizawl|Mizo|Cheraw|-
Nagaland|state|Kohima|-|-|Hornbill Festival
Odisha|state|Bhubaneswar|Odia|Odissi|Durga Puja
Punjab|state|Chandigarh|Punjabi|Bhangra,Giddha|Lohri,Baisakhi
Rajasthan|state|Jaipur|Hindi|Ghoomar,Kalbelia|-
Sikkim|state|Gangtok|Nepali|Singhi Chham|-
Tamil Nadu|state|Chennai|Tamil|Bharatanatyam,Karakattam|Pongal
Telangana|state|Hyderabad|Telugu|-|Bathukamma,Ugadi
Tripura|state|Agartala|Bengali,Kokborok|Hojagiri|Durga Puja
Uttar Pradesh|state|Lucknow|Hindi|-|Chhath
Uttarakhand|state|Dehradun|Hindi|-|-
West Bengal|state|Kolkata|Bengali|-|Durga Puja
Andaman and Nicobar Islands|ut|-|-|-|-
Chandigarh|ut|-|-|-|-
Dadra and Nagar Haveli and Daman and Diu|ut|Daman|-|-|-
Delhi|ut|New Delhi|Hindi|-|-
Jammu and Kashmir|ut|-|-|Rouf|-
Ladakh|ut|Leh|-|-|-
Lakshadweep|ut|Kavaratti|Malayalam|-|-
Puducherry|ut|Puducherry|Tamil|-|-
""", 6)
CLASSICAL_DANCES = ["Bharatanatyam", "Kathakali", "Kuchipudi", "Manipuri", "Mohiniyattam", "Odissi", "Sattriya"]

# ---------------------------------------------------------------- festivals
# name | fixed month (- if it moves) | fixed date | foods | features (keys, all that are true)
# | maybe (keys that are partly true, so never a wrong option)
FESTIVALS = rows("""
Diwali|-|-|-|lights,diyas|harvest,cattle,gujiya
Holi|-|-|gujiya,puran poli|colours,bonfire|harvest
Eid ul-Fitr|-|-|sewaiyan|ramzan|-
Christmas|December|25 December|plum cake|tree,santa,jesus|-
Pongal|January|-|sweet pongal|harvest,cattle,bonfire|kolam
Makar Sankranti|January|-|til laddoo,pitha|harvest,kites|cattle,bonfire
Lohri|January|-|rewri,gajak,til laddoo|harvest,bonfire,bhangra|-
Onam|-|-|sadya|harvest,pookalam,boatrace|-
Bihu|-|-|pitha|harvest,bihudance,bonfire|-
Baisakhi|April|-|-|harvest,bhangra|-
Vishu|April|-|sadya|vishukkani|harvest
Durga Puja|-|-|-|pandals,durga|harvest
Navratri|-|-|-|garba,durga,pandals|-
Dussehra|-|-|-|ravana|-
Ganesh Chaturthi|-|-|modak|ganesha|-
Raksha Bandhan|-|-|-|rakhi|-
Janmashtami|-|-|-|krishna,dahihandi|-
Guru Nanak Jayanti|-|-|-|nanak|-
Buddha Purnima|-|-|-|buddha|-
Mahavir Jayanti|-|-|-|mahavira|-
Easter|-|-|-|eastereggs|-
Chhath|-|-|thekua|sunriver|harvest
Ugadi|-|-|ugadi pachadi|-|harvest
Gudi Padwa|-|-|-|gudi|harvest
Bathukamma|-|-|-|flowertower|-
Hornbill Festival|December|-|-|hornbill|-
Republic Day|January|26 January|-|parade|flag
Independence Day|August|15 August|-|redfort,kites|flag
Gandhi Jayanti|October|2 October|-|gandhi|-
Children's Day|November|14 November|-|nehru|-
Teachers' Day|September|5 September|-|teachers|-
""", 6)
FESTIVAL_FEATURES = rows("""
lights|is called the festival of lights
diyas|is when we light clay diyas in rows
colours|is called the festival of colours
ramzan|comes after a month of Ramzan fasts
tree|is when we decorate a Christmas tree
santa|is when children wait for Santa Claus
jesus|is the birthday of Jesus
harvest|is a harvest festival
cattle|is when cows and bulls are decorated
bonfire|has a big bonfire
kites|is when the sky is full of kites
bhangra|is when people dance the bhangra
pookalam|has a flower rangoli called pookalam
boatrace|has snake boat races
bihudance|has the lively Bihu dance
vishukkani|starts by seeing the Vishukkani
pandals|has idols of Goddess Durga in pandals
durga|is when Goddess Durga is worshipped
garba|has nine nights of garba dancing
ravana|is when big Ravana figures are burnt
ganesha|is Lord Ganesha's birthday
rakhi|is when a rakhi is tied on the wrist
krishna|is Lord Krishna's birthday
dahihandi|has the dahi handi game
nanak|is Guru Nanak's birthday
buddha|is Lord Buddha's birthday
mahavira|is Lord Mahavira's birthday
eastereggs|has painted Easter eggs
sunriver|is when people pray to the Sun at rivers
gudi|is when a gudi is raised at homes
flowertower|has flowers stacked like a tower
hornbill|is named after a big bird
parade|has a big parade in New Delhi
redfort|is when the flag is hoisted at the Red Fort
gandhi|is Mahatma Gandhi's birthday
nehru|is Chacha Nehru's birthday
teachers|is a day to thank our teachers
""", 2)

# ---------------------------------------------------------------- seasons and weather
# we ... | seasons (summer, monsoon, winter). Phrases fit a 24-character option.
SEASON_ITEMS = rows("""
wear woollen clothes|winter
wear cotton clothes|summer
use raincoats|monsoon
wear gumboots|monsoon
use umbrellas|summer,monsoon
eat lots of mangoes|summer
eat juicy watermelons|summer
eat oranges|winter
drink cool nimbu pani|summer
drink hot soup|winter
see fog in the morning|winter
see many puddles|monsoon
see dark rain clouds|monsoon
hear frogs croak a lot|monsoon
see peacocks dance|monsoon
sit in warm sunshine|winter
get long hot days|summer
get short days|winter
use heaters|winter
use coolers and fans|summer
make paper boats|monsoon
see rivers fill up|monsoon
eat roasted bhutta|monsoon
see snow on the hills|winter
sleep under quilts|winter
have summer holidays|summer
sweat a lot|summer
eat litchis|summer
go for a swim|summer
see dry, cracked fields|summer
wear caps in the sun|summer
smell the wet earth|monsoon
see more mosquitoes|monsoon
see earthworms come out|monsoon
see farmers plant rice|monsoon
wear mufflers|winter
eat gajar halwa|winter
see our breath as mist|winter
wear socks to bed|winter
eat hot peanuts|winter
""", 2)
# KG weather: thing | days it is used (hot, cold, rainy, windy) | never on | worn y/n
WEATHER = rows("""
umbrella|rainy,hot|-|n
raincoat|rainy|hot|y
gumboots|rainy|hot|y
paper boat|rainy|-|n
sweater|cold|hot|y
woollen cap|cold|hot|y
gloves|cold|hot|y
shawl|cold|hot|y
muffler|cold|hot|y
jacket|cold|hot|y
blanket|cold|hot|n
quilt|cold|hot|n
heater|cold|hot|n
bonfire|cold|hot|n
hot soup|cold|hot|n
cotton clothes|hot|cold|y
cap|hot|-|y
sunglasses|hot|rainy|y
fan|hot|cold|n
cooler|hot|cold,rainy|n
air conditioner|hot|cold|n
nimbu pani|hot|cold|n
kite|windy|rainy|n
pinwheel|windy|-|n
""", 4)
WEATHER_WORDS = {"hot": "a hot day", "cold": "a cold day", "rainy": "a rainy day", "windy": "a windy day"}

MONTHS = [["January", 31], ["February", 28], ["March", 31], ["April", 30], ["May", 31], ["June", 30],
          ["July", 31], ["August", 31], ["September", 30], ["October", 31], ["November", 30], ["December", 31]]
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

# ---------------------------------------------------------------- water
# source | natural y/n | salty y/n
WATER_SOURCES = rows("""
river|y|n
lake|y|n
pond|y|n
spring|y|n
waterfall|y|n
rain|y|n
glacier|y|n
sea|y|y
ocean|y|y
well|n|n
tube well|n|n
hand pump|n|n
tap|n|n
water tank|n|n
dam|n|n
canal|n|n
stepwell|n|n
""", 3)
SAFE_WATER = rows("""
boiled water|y
filtered water|y
pond water|n
puddle water|n
drain water|n
muddy water|n
sea water|n
dirty river water|n
""", 2)
SAVE_WATER = rows("""
Closing a dripping tap|save
Bathing with a bucket|save
Using a mug to brush|save
Fixing leaking pipes|save
Collecting rainwater|save
Washing veggies in a tub|save
Watering plants by mug|save
Reusing RO waste water|save
Turning off the shower|save
Mopping the floor|save
Reusing rinse water|save
Watering plants at dusk|save
Filling a bucket halfway|save
Closing the tap tightly|save
Using a glass of water|save
Leaving the tap running|waste
Brushing with tap on|waste
Long showers every day|waste
Hosing down a car|waste
Letting a tank overflow|waste
Playing with a hose|waste
Throwing clean water out|waste
Ignoring a leaking tap|waste
Soaping hands, tap on|waste
Hosing the driveway|waste
Half-empty washing loads|waste
Pouring away clean water|waste
Bathing with a hosepipe|waste
Rinsing dishes, tap on|waste
Letting a pipe drip|waste
Rinsing rice, tap on|waste
Flushing for fun|waste
Splashing water to play|waste
Filling a tub to the top|waste
Mopping with a hose|waste
Washing clothes by hand|save
Reusing water to mop|save
Saving rice water|save
Turning off a hosepipe|save
Covering the water tank|save
Reporting a broken pipe|save
Washing a full load|save
Sweeping, not hosing|save
Using a half flush|save
Watering roots, not leaves|save
Cleaning a car with a cloth|save
Cooking with less water|save
Turning off taps at school|save
Running a dripping pipe|waste
Soaking dishes in running water|waste
""", 2)

# ---------------------------------------------------------------- habits and safety
HABITS = rows("""
Washing hands with soap|good
Bathing every day|good
Brushing twice a day|good
Cutting nails|good
Eating fruits|good
Drinking clean water|good
Sleeping early|good
Covering a sneeze|good
Using a dustbin|good
Saying thank you|good
Sharing toys|good
Waiting for your turn|good
Combing your hair|good
Wearing clean clothes|good
Putting toys away|good
Eating vegetables|good
Playing outdoors|good
Helping at home|good
Greeting elders|good
Flushing the toilet|good
Washing fruits first|good
Chewing food well|good
Saying sorry|good
Using a handkerchief|good
Washing hands after play|good
Packing your own bag|good
Watering the plants|good
Feeding birds water|good
Saying please|good
Reading a book daily|good
Keeping the room tidy|good
Biting nails|bad
Littering the road|bad
Spitting on the road|bad
Picking your nose|bad
Eating with dirty hands|bad
Wasting food|bad
Wasting water|bad
Sleeping very late|bad
Eating lots of junk food|bad
Shouting at others|bad
Pushing in a line|bad
Hitting friends|bad
Watching TV all day|bad
Skipping brushing|bad
Throwing toys around|bad
Grabbing others' things|bad
Pencil in your mouth|bad
Talking with mouth full|bad
Drinking dirty water|bad
Sneezing on others|bad
Leaving lights on|bad
Skipping breakfast|bad
Scribbling on walls|bad
Plucking flowers|bad
Teasing animals|bad
Lying to parents|bad
Reading in dim light|bad
""", 2)
SAFETY = rows("""
Using the zebra crossing|safe
Wearing a helmet|safe
Wearing a seat belt|safe
Walking on the footpath|safe
Holding an adult's hand|safe
Waiting for green light|safe
Looking both ways|safe
Playing in the park|safe
Keeping away from fire|safe
Using scissors carefully|safe
Sitting still in a bus|safe
Telling an adult if hurt|safe
Swimming with an adult|safe
Keeping away from wires|safe
Walking, not running|safe
Crossing with an adult|safe
Using a dustbin|safe
Knowing your address|safe
Staying with your group|safe
Using the handrail|safe
Wearing a life jacket|safe
Keeping knives away|safe
Sitting while eating|safe
Bathing with an adult|safe
Wiping a wet floor|safe
Closing the gas knob|safe
Playing with matches|unsafe
Touching electric wires|unsafe
Running across the road|unsafe
Leaning out of a bus|unsafe
Playing near a fire|unsafe
Swimming alone|unsafe
Flying kites on a roof|unsafe
Playing with a knife|unsafe
Eating unknown berries|unsafe
Getting off a moving bus|unsafe
Riding without a helmet|unsafe
Playing on the road|unsafe
Touching a hot iron|unsafe
Going with a stranger|unsafe
Letting strangers in|unsafe
Tasting medicines|unsafe
Climbing a window|unsafe
Playing with plugs|unsafe
Running near a pool|unsafe
Playing near a well|unsafe
Crossing a railway line|unsafe
Standing on a chair|unsafe
Playing with crackers|unsafe
Touching a stray dog|unsafe
Pushing on the stairs|unsafe
Hiding in a fridge box|unsafe
Playing with a lighter|unsafe
Jumping on the bed|unsafe
""", 2)
SIGNALS = rows("""
red|stop
yellow|get ready
green|go
""", 2)

# ---------------------------------------------------------------- day and night, and sequences
DAY_NIGHT = rows("""
The sun shines|day
Stars twinkle|night
Owls hunt for food|night
Children go to school|day
We sleep in our beds|night
Fireflies glow|night
Sunflowers face the sun|day
Bats fly out to eat|night
The sky is bright blue|day
Street lights glow|night
Owls rest in trees|day
We eat breakfast|day
It is dark outside|night
Farmers work in fields|day
We see our shadows|day
Children play outside|day
Crickets chirp loudly|night
The moon lights the sky|night
We eat our lunch|day
The rooster crows|day
Flowers open in the sun|day
We eat our dinner|night
The sky is full of stars|night
We brush before bed|night
Lizards come out to hunt|night
We see a rainbow|day
""", 2)
# Things that happen in a fixed order (any items taken in this order stay in order).
SEQUENCES = rows("""
day|Put the parts of the day in order.|morning,afternoon,evening,night
meals|Put the meals in order.|breakfast,lunch,dinner
sun|Put the sun's day in order.|sunrise,noon,sunset
hands|How do we wash our hands?|wet hands,rub on soap,scrub hands,rinse with water,dry hands
brush|How do we brush our teeth?|put paste on brush,brush teeth,rinse mouth
shoes|How do we put on shoes?|put on socks,put on shoes,tie the laces
seed|How do we plant a seed?|dig a small hole,put the seed in,cover it with soil,water it
bed|How do we go to bed?|change clothes,brush teeth,switch off light,go to sleep
dress|How do we get ready after a bath?|dry with a towel,put on clothes,comb hair
""", 3)

# ---------------------------------------------------------------- then and now (Class 4)
# old | new | what it is for
THEN_NOW = rows("""
lantern|electric bulb|light
oil lamp|tube light|light
hand fan|electric fan|keeping cool
chulha|gas stove|cooking
grinding stone|mixer|grinding
clay pot|fridge|keeping water cool
slate|notebook|writing
reed pen|ball pen|writing
letter|email|sending messages
telegram|text message|sending messages
landline phone|mobile phone|talking far away
bullock plough|tractor|ploughing fields
bullock cart|truck|carrying goods
tonga|auto-rickshaw|riding in town
rowing boat|motorboat|crossing rivers
sundial|wristwatch|telling time
hourglass|clock|telling time
washing stone|washing machine|washing clothes
charcoal iron|electric iron|ironing clothes
typewriter|computer|typing
film camera|phone camera|taking photos
gramophone|music player|playing music
dung cakes|LPG cylinder|cooking fuel
abacus|calculator|counting
handloom|power loom|weaving cloth
well|tap|getting water
hand pump|water pump|getting water
quill pen|fountain pen|writing
messenger|telephone|talking far away
sickle|harvester|cutting crops
wooden plough|tractor plough|ploughing fields
kerosene lamp|LED bulb|light
mud stove|induction stove|cooking
handwritten book|printed book|reading
""", 3)

# ---------------------------------------------------------------- keeping food (Class 4)
# food | ways it is kept (dry, salt, sugar, oil, cold, boil, airtight)
KEEP_FOOD = rows("""
mango pickle|oil,salt
lemon pickle|salt,oil
jam|sugar
murabba|sugar
papad|dry
raisins|dry
dry red chillies|dry
amchur|dry
dried fish|dry,salt
salted fish|salt,dry
milk|boil,cold
curd|cold
green vegetables|cold
ice cream|cold
frozen peas|cold
paneer|cold
chips|airtight
biscuits|airtight
wheat grains|dry,airtight
rice grains|dry,airtight
fish pickle|oil,salt
amla murabba|sugar
fruit squash|sugar
sun-dried tomatoes|dry
dry pulses|dry,airtight
butter|cold
cheese|cold
eggs|cold
cooked food|cold
flour|airtight
tea leaves|airtight
coffee powder|airtight
fryums|dry
dry coconut|dry
""", 2)
KEEP_WAYS = {"dry": "drying in the sun", "salt": "adding salt", "sugar": "adding sugar", "oil": "adding oil",
             "cold": "keeping it cold", "boil": "boiling it", "airtight": "packing it airtight"}
SPOILS = rows("""
milk|fast
cooked rice|fast
cut fruit|fast
cooked dal|fast
fresh fish|fast
bread|fast
idli batter|fast
fresh paneer|fast
rice grains|slow
sugar|slow
salt|slow
honey|slow
pickle|slow
jaggery|slow
dry dal|slow
raisins|slow
ghee|slow
cooked vegetables|fast
fresh juice|fast
curd rice|fast
chutney|fast
rice flour|slow
tea leaves|slow
papad|slow
vinegar|slow
biscuits in a tin|slow
""", 2)

# ---------------------------------------------------------------- water cycle (Class 4)
# what happens | change (evaporation, condensation, freezing, melting)
WATER_CHANGES = rows("""
Wet clothes dry in the sun.|evaporation
A puddle dries up after rain.|evaporation
Sweat dries on your skin.|evaporation
Water in a plate dries away.|evaporation
A wet floor dries.|evaporation
Seawater dries and leaves salt.|evaporation
Wet hair dries in the sun.|evaporation
Ponds shrink in hot summer.|evaporation
Drops form on a cold glass.|condensation
Dew forms on grass at dawn.|condensation
A bathroom mirror fogs up.|condensation
Drops form on a pot's lid.|condensation
Clouds form in the sky.|condensation
Your breath fogs a cold window.|condensation
Water turns to ice in a freezer.|freezing
A lake in Ladakh turns to ice.|freezing
Kulfi sets in the freezer.|freezing
Water in an ice tray hardens.|freezing
Puddles freeze on cold hills.|freezing
Snow forms high in the clouds.|freezing
Wet roads dry after rain.|evaporation
A cold bottle gets wet outside.|condensation
Spectacles fog up in a kitchen.|condensation
Ice on a lake melts in spring.|melting
A kulfi melts on a hot day.|melting
Ghee melts in a warm kitchen.|melting
An ice cube melts in a glass.|melting
Ice cream melts in the sun.|melting
Snow on mountains melts.|melting
Butter melts in a hot pan.|melting
Candle wax melts.|melting
Chocolate melts in your hand.|melting
""", 2)
WATER_CYCLE = ["the sun heats water", "water turns to vapour", "vapour cools into clouds", "rain falls", "water flows to the sea"]

# ---------------------------------------------------------------- food chains (Class 5)
# eater | what it eats (plants: grass, leaves, grain, water plants)
EATS = rows("""
grasshopper|grass,leaves
caterpillar|leaves
cow|grass
goat|grass,leaves
deer|grass,leaves
rabbit|grass
zebra|grass
giraffe|leaves
elephant|grass,leaves
mouse|grain
sparrow|grain,caterpillar
hen|grain,grasshopper
small fish|water plants
frog|grasshopper
lizard|grasshopper
snake|frog,mouse,lizard
eagle|snake,mouse,rabbit
owl|mouse
cat|mouse
hawk|sparrow,mouse
fox|rabbit,mouse
wolf|deer,rabbit
tiger|deer
lion|zebra,deer
peacock|snake,grasshopper
mongoose|snake
big fish|small fish
kingfisher|small fish
heron|frog,small fish
crocodile|big fish,deer
""", 2)
PRODUCERS = ["grass", "leaves", "grain", "water plants"]
HERBIVORES = ["cow", "goat", "deer", "rabbit", "zebra", "giraffe", "elephant", "grasshopper", "caterpillar", "buffalo", "horse", "camel"]
CARNIVORES = ["lion", "tiger", "eagle", "snake", "frog", "owl", "hawk", "wolf", "kingfisher", "crocodile", "heron", "mongoose", "lizard"]

# ---------------------------------------------------------------- space (Class 5)
PLANETS = rows("""
Mercury|is closest to the Sun,is the smallest planet
Venus|is the hottest planet
Earth|is the planet we live on,has plants and animals
Mars|is called the red planet
Jupiter|is the biggest planet
Saturn|has big bright rings
Uranus|spins on its side
Neptune|is farthest from the Sun
""", 2)

# ---------------------------------------------------------------- life cycles (Class 5)
LIFE_CYCLES = rows("""
frog|egg,tadpole,froglet,frog
butterfly|egg,caterpillar,pupa,butterfly
mosquito|egg,larva,pupa,mosquito
housefly|egg,maggot,pupa,housefly
silkworm|egg,silkworm,cocoon,silk moth
hen|egg,chick,hen
cockroach|egg,nymph,cockroach
mango tree|mango seed,seedling,young tree,flowering tree,tree with mangoes
person|baby,child,teenager,adult,old person
bean seed|soaked seed,tiny root,tiny shoot,first leaves
""", 2)

# ---------------------------------------------------------------- inside the body (Class 5)
# organ | form | jobs (all of them) | number in the body
ORGANS = rows("""
heart|s|pumps blood|1
lungs|pl|help us breathe|2
stomach|s|digests food|1
small intestine|s|digests food,takes food into blood|1
brain|s|helps us think,controls the body|1
kidneys|pl|clean the blood|2
skin|m|feels touch,covers the body|-
food pipe|s|carries food to the stomach|1
windpipe|s|carries air to the lungs|1
skull|s|protects the brain|1
ribs|pl|protect the heart and lungs|-
backbone|s|keeps us upright|1
muscles|pl|help us move|-
teeth|pl|break up food|-
eyes|pl|help us see|2
ears|pl|help us hear|2
tongue|s|helps us taste|1
nose|s|helps us smell,helps us breathe|1
large intestine|s|stores food waste|1
blood vessels|pl|carry blood|-
bladder|s|stores urine|1
""", 4)
DIGESTION = ["mouth", "food pipe", "stomach", "small intestine", "large intestine"]
BREATHING = ["nose", "windpipe", "lungs"]

# ---------------------------------------------------------------- energy (Class 5)
ENERGY = rows("""
sunlight|renewable
wind|renewable
flowing water|renewable
biogas|renewable
coal|non-renewable
petrol|non-renewable
diesel|non-renewable
natural gas|non-renewable
LPG|non-renewable
kerosene|non-renewable
CNG|non-renewable
""", 2)
# thing | what it runs on (from ENERGY)
ENERGY_USES = rows("""
solar panel|sunlight
solar cooker|sunlight
windmill|wind
sailboat|wind
dam|flowing water
watermill|flowing water
biogas stove|biogas
car|petrol
scooter|petrol
truck|diesel
tractor|diesel
gas stove|LPG
coal power plant|coal
kerosene lamp|kerosene
CNG bus|CNG
""", 2)
SAVE_ENERGY = rows("""
Switching off lights|save
Walking to a nearby shop|save
Riding a bicycle|save
Using LED bulbs|save
Closing the fridge door|save
Taking a bus together|save
Drying clothes outside|save
Using a solar cooker|save
Turning off a car at red|save
Switching off the TV|save
Fans on in an empty room|waste
Lights on in daytime|waste
Leaving the fridge open|waste
Engine on at a red light|waste
TV on with no one there|waste
Car for a short walk|waste
Charger left switched on|waste
AC with windows open|waste
""", 2)

# ---------------------------------------------------------------- health (Class 5)
# disease | spread by (mosquito, water, air)
DISEASES = rows("""
malaria|mosquito
dengue|mosquito
chikungunya|mosquito
cholera|water
typhoid|water
diarrhoea|water
common cold|air
flu|air
tuberculosis|air
chickenpox|air
measles|air
polio|water
hepatitis A|water
COVID-19|air
mumps|air
whooping cough|air
filaria|mosquito
zika|mosquito
""", 2)
SPREAD = {"mosquito": "mosquito bites", "water": "dirty water and food", "air": "coughs and sneezes"}
GERMS = rows("""
Sleeping under a net|stop
Boiling drinking water|stop
Covering cooked food|stop
Washing hands with soap|stop
Covering a cough|stop
Emptying cooler water|stop
Getting vaccines|stop
Wearing full sleeves|stop
Using a clean toilet|stop
Eating fresh, hot food|stop
Water left in old tyres|spread
Uncovered sweets|spread
Open drains|spread
Drinking pond water|spread
Coughing on others|spread
Eating with dirty hands|spread
Flies on food|spread
Garbage near homes|spread
Sharing a used towel|spread
Touching eyes with dirt|spread
Biting your nails|spread
Cut fruit left open|spread
Spitting on the road|spread
Stale food|spread
Trimming your nails|stop
Bathing every day|stop
Clean drinking water|stop
Washing fruit first|stop
Covering water pots|stop
Closed dustbins|stop
""", 2)

# ---------------------------------------------------------------- people (family questions)
NAMES = rows("""
Asha|f
Meena|f
Priya|f
Riya|f
Anjali|f
Fatima|f
Zoya|f
Kavya|f
Diya|f
Neha|f
Lakshmi|f
Mary|f
Aisha|f
Pooja|f
Nisha|f
Gauri|f
Tara|f
Simran|f
Ravi|m
Arjun|m
Kabir|m
Aman|m
Rohan|m
Imran|m
Sameer|m
Joseph|m
Rahul|m
Vikram|m
Karan|m
Arun|m
Dev|m
Manoj|m
Farhan|m
Tenzin|m
Sunil|m
Nikhil|m
""", 2)


# ---------------------------------------------------------------- pictures
PICS_FILE = os.path.join(os.path.dirname(OUT), "pictures.json")
ALIAS = {
    "hippopotamus": "hippo", "rhinoceros": "rhino", "auto-rickshaw": "auto", "spectacles": "glasses",
    "ice cream": "icecream", "pressure cooker": "pressurecooker", "money plant": "moneyplant",
    "clay diya": "diya", "woollen sweater": "sweater", "sweater": "sweater", "cotton shirt": "shirt",
    "iron key": "key", "steel spoon": "spoon", "wooden spoon": "spoon", "plastic spoon": "spoon",
    "wooden chair": "chair", "plastic chair": "chair", "wooden table": "table", "glass bottle": "bottle",
    "empty plastic bottle": "bottle", "plastic comb": "comb", "wooden comb": "comb", "plastic bucket": "bucket",
    "wooden door": "door", "window pane": "window", "seashell": "shell", "rubber ball": "ball", "plastic ball": "ball",
    "steel plate": "plate", "plastic plate": "plate", "glass tumbler": "glass", "clay pot": "pot", "aluminium pot": "pot",
    "iron tawa": "tawa", "needle": "needle", "cardboard box": "box", "leather shoes": "shoe", "woollen socks": "sock",
    "socks": "sock", "shoes": "shoe", "woollen cap": "hat", "cap": "hat", "sunglasses": "glasses", "a cap": "hat",
    "green chilli": "chilli", "chilli": "chilli", "bhutta": "corn", "roti": "roti", "moong dal": "dal",
    "brick house": "house", "field": "farm", "date palm": "palm", "seedling": "sapling", "mango seed": "seed",
    "seed": "seed", "young tree": "sapling", "sea": "wave", "ocean": "wave", "rubber gloves": "gloves",
    "eyes": "eye", "ears": "ear", "hands": "hand", "teeth": "tooth", "feet": "foot", "legs": "leg",
    "kidneys": "", "muscles": "muscle", "skull": "bone", "ribs": "bone", "backbone": "bone",
    "jet plane": "aeroplane", "steamer": "ship", "cruise ship": "ship", "ferry": "ship", "motorboat": "boat",
    "rowing boat": "boat", "electric bulb": "bulb", "fridge": "fridge", "mobile phone": "phone", "tube light": "",
    "honeybee": "bee", "paper boat": "boat", "curd": "curd", "ceiling fan": "", "bedsheet": "", "towel": "",
    "coconut tree": "palm", "notebook": "notebook", "ball pen": "pen", "candle": "candle", "broom": "broom",
}


def load_pics():
    d = json.load(open(PICS_FILE))
    return {x for k, v in d.items() if k != "_doc" for x in v}


PICS = load_pics()


def pic(name):
    if name in ALIAS:
        a = ALIAS[name]
        return a if a in PICS else None
    return name if name in PICS else None


def put(d, k, v):
    if v not in (None, [], "", False):
        d[k] = v


FOOD_PIC = {"coconut": "coconut", "mango": "mango", "apple": "apple", "banana": "banana", "orange": "orange",
            "lemon": "lemon", "guava": "guava", "papaya": "papaya", "tomato": "tomato", "potato": "potato"}


def build():
    out = {"_doc": DOC}
    animals = []
    for r in ANIMALS:
        n, g, hab, home, food, cover, young, legs, birth, kind, size, fly, flags = r
        d = {"n": n}
        put(d, "an", an(n))
        d["pl"] = plural(n)
        d["group"] = g
        put(d, "contested", "c" in flags)
        put(d, "kg", "k" in flags)
        put(d, "both", "a" in flags)
        d["hab"] = lst(hab)
        put(d, "home", lst(home))
        put(d, "food", {"h": "herbivore", "c": "carnivore", "o": "omnivore"}.get(food))
        put(d, "cover", opt(cover))
        put(d, "young", opt(young))
        if legs != "-":
            d["legs"] = int(legs)
        put(d, "birth", {"e": "eggs", "l": "live"}.get(birth))
        put(d, "kind", opt(kind))
        if size != "-":
            d["size"] = int(size)
        if fly != "-":
            d["flies"] = fly == "y"
        animals.append(d)
    by = {a["n"]: a for a in animals}
    for n, verb, noise in SOUNDS:
        by[n]["sound"] = verb
        put(by[n], "noise", opt(noise))
    for n, beak, feet in BIRDS:
        put(by[n], "beak", opt(beak))
        put(by[n], "feet", opt(feet))
    for n, yes, no in MOVES:
        put(by[n], "moves", lst(yes))
        put(by[n], "cannot", lst(no))
    for a in animals:
        put(a, "pic", pic(a["n"]))
    out["animals"] = animals

    plants = []
    for n, typ, uses, disp, why, flags in PLANTS:
        d = {"n": n}
        put(d, "an", an(n))
        put(d, "type", opt(typ))
        put(d, "uses", lst(uses))
        put(d, "seeds", opt(disp))
        put(d, "why", opt(why))
        put(d, "none", "n" in flags)
        put(d, "pic", pic(n) if n != "coconut" else "palm")
        plants.append(d)
    out["plants"] = plants

    foods = []
    for n, form, fv, src, part, nut, notnut, cook, method, health, taste in FOODS:
        d = {"n": n, "form": form}
        put(d, "an", form == "s" and an(n))
        put(d, "fv", opt(fv))
        put(d, "src", opt(src))
        put(d, "part", opt(part))
        put(d, "rich", lst(nut))
        put(d, "poor", lst(notnut))
        put(d, "cook", opt(cook))
        put(d, "method", opt(method))
        put(d, "health", {"h": "healthy", "j": "junk"}.get(health))
        put(d, "taste", lst(taste))
        put(d, "pic", pic(n))
        foods.append(d)
    out["foods"] = foods

    objs = []
    for n, form, mat, mag, see, fl, waste, nat, hs in OBJECTS:
        d = {"n": n, "form": form}
        put(d, "an", form == "s" and an(n))
        put(d, "made", lst(mat))
        for k, v in (("magnetic", mag), ("seeThrough", see), ("floats", fl), ("natural", nat)):
            if v != "-":
                d[k] = v == "y"
        put(d, "waste", opt(waste))
        put(d, "feel", {"h": "hard", "s": "soft"}.get(hs))
        put(d, "pic", pic(n))
        objs.append(d)
    out["objects"] = objs
    out["nonlivingTricky"] = [dict(n=n, why=w, **({"pic": pic(n)} if pic(n) else {})) for n, w in NONLIVING_TRICKY]

    out["helpers"] = [
        {k: v for k, v in dict(n=n, an=an(n), tools=lst(t), places=lst(p), does=lst(d), makes=opt(m), pic=pic(n)).items()
         if v not in (None, [], False)}
        for n, t, p, d, m in HELPERS]
    out["toolPics"] = {t: pic(t) for h in HELPERS for t in lst(h[1]) if pic(t)}
    out["placePics"] = {pl: pic(pl) for h in HELPERS for pl in lst(h[2]) if pic(pl)}
    out["youngPics"] = {a["young"]: pic(a["young"]) for a in animals if a.get("young") and pic(a["young"])}
    out["wearPics"] = {t: pic(t.replace("a ", "", 1)) or pic(t) for t, _ in WEAR if pic(t.replace("a ", "", 1)) or pic(t)}
    out["transport"] = [
        {k: v for k, v in dict(n=n, an=an(n), mode=m, wheels=int(w) if w != "-" else None, power=opt(pw), pic=pic(n)).items()
         if v not in (None, False)}
        for n, m, w, pw in TRANSPORT]
    out["bodyParts"] = [{k: v for k, v in dict(n=n, count=int(c) if c != "-" else None, ask=opt(q), pic=pic(n)).items() if v is not None}
                        for n, c, q in BODY_PARTS]
    out["bodyUses"] = [dict(verb=v, parts=lst(p)) for v, p in BODY_USES]
    out["wear"] = [dict(thing=t, part=p) for t, p in WEAR]
    out["houses"] = [{k: v for k, v in dict(n=n, an=an(n), kind=opt(kd), made=lst(m), features=lst(f), pic=pic(n)).items()
                      if v not in (None, [], False)} for n, kd, m, f in HOUSES]
    out["houseFeatures"] = [dict(key=k, text=t, why=w) for k, t, w in HOUSE_FEATURES]
    out["houseMaterials"] = HOUSE_MATERIALS
    out["kutchaPucca"] = [dict(n=n, kind=k) for n, k in KUTCHA_PUCCA]
    out["india"] = [{k: v for k, v in dict(n=n, kind=kd, capital=opt(c), languages=lst(l), dances=lst(dn), festivals=lst(f)).items()
                     if v not in (None, [])} for n, kd, c, l, dn, f in INDIA]
    out["classicalDances"] = CLASSICAL_DANCES
    fpic = {"Diwali": "diya", "Holi": "pichkari", "Makar Sankranti": "kite", "Raksha Bandhan": None}
    out["festivals"] = [{k: v for k, v in dict(n=n, month=opt(mo), date=opt(dt), foods=lst(fo), features=lst(fe), maybe=lst(mb),
                                                pic=fpic.get(n)).items() if v not in (None, [])}
                        for n, mo, dt, fo, fe, mb in FESTIVALS]
    out["festivalFeatures"] = [dict(key=k, text=t) for k, t in FESTIVAL_FEATURES]
    out["seasonItems"] = [dict(we=w, seasons=lst(s)) for w, s in SEASON_ITEMS]
    out["weather"] = [{k: v for k, v in dict(n=n, days=lst(d), never=lst(nv), worn=w == "y", pic=pic(n)).items() if v not in (None, [], False)}
                      for n, d, nv, w in WEATHER]
    out["weatherWords"] = WEATHER_WORDS
    out["months"] = [dict(n=n, days=d) for n, d in MONTHS]
    out["days"] = DAYS
    out["waterSources"] = [{k: v for k, v in dict(n=n, natural=nat == "y", salty=sal == "y", pic=pic(n)).items() if v is not None}
                           for n, nat, sal in WATER_SOURCES]
    out["safeWater"] = [dict(n=n, safe=s == "y") for n, s in SAFE_WATER]
    out["saveWater"] = [dict(n=n, saves=s == "save") for n, s in SAVE_WATER]
    out["habits"] = [dict(n=n, good=g == "good") for n, g in HABITS]
    out["safety"] = [dict(n=n, safe=s == "safe") for n, s in SAFETY]
    out["signals"] = [dict(colour=c, means=m) for c, m in SIGNALS]
    out["dayNight"] = [dict(n=n, when=w) for n, w in DAY_NIGHT]
    out["sequences"] = [dict(key=k, ask=a, steps=lst(s)) for k, a, s in SEQUENCES]
    out["thenNow"] = [dict(old=o, new=n, use=u) for o, n, u in THEN_NOW]
    out["keepFood"] = [dict(n=n, ways=lst(w)) for n, w in KEEP_FOOD]
    out["keepWays"] = KEEP_WAYS
    out["spoils"] = [dict(n=n, fast=f == "fast") for n, f in SPOILS]
    out["waterChanges"] = [dict(n=n, change=c) for n, c in WATER_CHANGES]
    out["waterCycle"] = WATER_CYCLE
    out["eats"] = [dict(n=n, food=lst(f)) for n, f in EATS]
    out["producers"] = PRODUCERS
    out["herbivores"] = HERBIVORES
    out["carnivores"] = CARNIVORES
    out["planets"] = [dict(n=n, facts=lst(f), pic=pic(n.lower()) or "planet") for n, f in PLANETS]
    out["lifeCycles"] = [dict(n=n, steps=lst(s)) for n, s in LIFE_CYCLES]
    out["stepPics"] = {st: pic(st) for _, s in LIFE_CYCLES for st in lst(s) if pic(st)}
    out["organs"] = [{k: v for k, v in dict(n=n, form=f, jobs=lst(j), count=int(c) if c != "-" else None, pic=pic(n)).items()
                      if v not in (None, [])} for n, f, j, c in ORGANS]
    out["digestion"] = DIGESTION
    out["breathing"] = BREATHING
    out["energy"] = [dict(n=n, renewable=k == "renewable") for n, k in ENERGY]
    out["energyUses"] = [dict(n=n, uses=u, pic=pic(n)) if pic(n) else dict(n=n, uses=u) for n, u in ENERGY_USES]
    out["saveEnergy"] = [dict(n=n, saves=s == "save") for n, s in SAVE_ENERGY]
    out["diseases"] = [dict(n=n, by=b) for n, b in DISEASES]
    out["spread"] = SPREAD
    out["germs"] = [dict(n=n, stops=s == "stop") for n, s in GERMS]
    out["names"] = [dict(n=n, girl=g == "f") for n, g in NAMES]
    return out


def _all_pics(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "pic" and isinstance(v, str):
                yield v
            elif k in ("toolPics", "placePics", "stepPics", "youngPics", "wearPics"):
                yield from v.values()
            else:
                yield from _all_pics(v)
    elif isinstance(o, list):
        for x in o:
            yield from _all_pics(x)


DOC = (
    "EVS fact tables (KG-5), built by boretube-learn/tools/content/data/evs_data.py; edit there, not here. "
    "A missing field means unknown or arguable, so generators never use it. "
    "animals: n, an (article 'an'), pl (plural), group (mammal/bird/reptile/fish/insect/amphibian/other), contested "
    "(never in group, birth or flying questions: bat, whale, dolphin, penguin, spider...), kg (familiar to small children), "
    "both (lives on land and in water), hab (forest/grassland/desert/snow/sea/fresh/farm/house/mountain/soil), home "
    "(first is the main one; all true ones listed), food (herbivore/carnivore/omnivore), cover (fur/hair/wool/feathers/"
    "scales/shell/skin), young, legs, birth (eggs/live), kind (pet/farm/wild), size (1 tiny..7 huge), flies, sound/noise, "
    "beak/feet (birds), moves/cannot (fly/swim/hop/crawl), pic (picture id). "
    "plants: type (tree/shrub/herb/climber/creeper), uses (products), seeds (wind/water/animal/burst) and why, none "
    "(gives no special product, a safe wrong option). foods: form (s 'a mango', pl 'grapes', m 'rice'), fv (fruit/veg), "
    "src (plant/animal), part (root/stem/leaf/flower/fruit/seed), rich/poor (c carbohydrates, p proteins, f fats, "
    "v vitamins and minerals), cook (raw/cooked/both), method (steam/fry/bake/boil/roast), health (healthy/junk), taste. "
    "objects: made (materials), magnetic, seeThrough, floats, waste (wet/dry), natural, feel (hard/soft). "
    "helpers: tools, places, does, makes. transport: mode (land/water/air), wheels, power. india: 28 states and 8 UTs "
    "(since 2020) with capital, languages, dances, festivals only where unambiguous. festivals: month/date only when "
    "fixed; features (true) and maybe (partly true, never a wrong option). The rest are small scenario tables."
)


if __name__ == "__main__":
    data = build()
    unknown = [p for p in _all_pics(data) if p not in PICS]
    assert not unknown, unknown
    with open(OUT, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(OUT, {k: len(v) for k, v in data.items() if isinstance(v, list)})
