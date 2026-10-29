"""More questions per skill (2026-10-29: "make the corpus big enough for real
randomness"). Same rules as packs.py: answer first, one-sentence why of at
most 12 words. Merged into the skills by id."""
from packs_lib import it, first_letter, picture_word, pic_q

EXTRA = {
    # ── English ──
    "en0.letters": [
        first_letter(w, w, wrong) for w, wrong in [
            ("moon", ["N", "B", "S"]), ("star", ["T", "C", "Z"]), ("cloud", ["K", "G", "D"]), ("leaf", ["I", "T", "F"]),
            ("cow", ["K", "G", "O"]), ("bird", ["D", "P", "R"]), ("ant", ["E", "N", "U"]), ("cup", ["K", "P", "G"]),
            ("book", ["D", "P", "K"]), ("car", ["K", "R", "G"]), ("boat", ["D", "P", "T"]), ("hand", ["N", "A", "M"]),
            ("ear", ["A", "R", "I"]), ("eye", ["A", "Y", "I"]), ("tooth", ["D", "H", "F"]), ("drop", ["B", "P", "T"]),
            ("fire", ["V", "R", "P"]), ("pencil", ["B", "S", "Q"]), ("mango", ["N", "W", "G"]), ("banana", ["D", "P", "N"]),
            ("carrot", ["K", "R", "G"]), ("seed", ["C", "Z", "D"]), ("rain", ["N", "W", "L"]), ("flower", ["V", "L", "P"]),
        ]
    ],
    "en0.words": [
        picture_word(w, wrong) for w, wrong in [
            ("sun", ["son", "bun", "sit"]), ("moon", ["moo", "noon", "mud"]), ("tree", ["three", "free", "tea"]),
            ("fish", ["dish", "fist", "wish"]), ("cat", ["cot", "bat", "hat"]), ("dog", ["log", "dig", "fog"]),
            ("ball", ["bell", "wall", "tall"]), ("apple", ["ankle", "maple", "able"]), ("house", ["mouse", "horse", "hose"]),
            ("bus", ["bun", "box", "bud"]), ("egg", ["leg", "peg", "bag"]), ("eye", ["dye", "ear", "pie"]),
            ("ear", ["eat", "car", "egg"]), ("nose", ["rose", "note", "nest"]), ("tooth", ["truth", "teeth", "boot"]),
            ("cloud", ["clown", "loud", "cold"]), ("banana", ["bandana", "cabana", "panama"]), ("carrot", ["parrot", "card", "cart"]),
            ("seed", ["need", "weed", "sea"]), ("flower", ["tower", "flour", "power"]), ("pencil", ["stencil", "penny", "parcel"]),
            ("drop", ["drip", "crop", "door"]), ("rain", ["train", "ran", "rail"]), ("star", ["scar", "stay", "jar"]),
        ]
    ],
    "en1.naming": [
        it(w, "Which one is a naming word?", [w] + other, f"A naming word names a thing: {w}.")
        for w, other in [
            ("door", ["open", "tall", "slowly"]), ("apple", ["bite", "red", "juicy"]), ("train", ["go", "fast", "long"]),
            ("table", ["sit", "wooden", "near"]), ("shoe", ["walk", "new", "tight"]), ("flower", ["smell", "pretty", "bloom"]),
            ("milk", ["drink", "white", "cold"]), ("kite", ["fly", "high", "colourful"]), ("box", ["pack", "heavy", "open"]),
            ("lamp", ["glow", "bright", "on"]), ("doll", ["play", "cute", "small"]), ("boat", ["row", "wet", "float"]),
            ("clock", ["tick", "round", "late"]), ("cake", ["bake", "sweet", "soft"]), ("fan", ["spin", "fast", "cool"]),
            ("star", ["shine", "bright", "far"]), ("hat", ["wear", "big", "funny"]), ("bag", ["carry", "full", "heavy"]),
        ]
    ],
    "en1.rhyme": [
        it(f"{a}-{b}", f"Which word rhymes with {a}?", [b] + other, f"{a.capitalize()} and {b} end with the same sound.")
        for a, b, other in [
            ("hen", "ten", ["hat", "hot", "hug"]), ("pig", "wig", ["pin", "pot", "peg"]), ("rat", "mat", ["rug", "rip", "red"]),
            ("bug", "rug", ["bag", "bed", "big"]), ("pot", "dot", ["pit", "pet", "put"]), ("fan", "can", ["fin", "fun", "fog"]),
            ("cap", "map", ["cup", "cop", "cub"]), ("hop", "top", ["hip", "hat", "hen"]), ("sock", "rock", ["sack", "sick", "suck"]),
            ("cook", "book", ["cake", "kick", "cool"]), ("light", "night", ["late", "lot", "lit"]), ("rain", "train", ["run", "ring", "road"]),
            ("boat", "coat", ["boot", "bat", "bit"]), ("wall", "fall", ["well", "will", "wool"]), ("fun", "run", ["fan", "fin", "fog"]),
            ("jam", "ham", ["jug", "jet", "jog"]), ("nose", "rose", ["nest", "nut", "nap"]), ("bake", "cake", ["bike", "book", "bark"]),
        ]
    ],
    "en2.opposite": [
        it(f"{a}-{b}", f"What is the opposite of {a}?", [b] + other, f"{a.capitalize()} and {b} are opposites.")
        for a, b, other in [
            ("tall", "short", ["big", "long", "high"]), ("near", "far", ["close", "next", "by"]), ("early", "late", ["soon", "first", "now"]),
            ("heavy", "light", ["big", "full", "hard"]), ("clean", "dirty", ["neat", "fresh", "wet"]), ("rich", "poor", ["kind", "good", "big"]),
            ("thick", "thin", ["fat", "wide", "big"]), ("loud", "quiet", ["noisy", "high", "big"]), ("sweet", "sour", ["nice", "sugar", "good"]),
            ("push", "pull", ["press", "shove", "hit"]), ("give", "take", ["send", "hand", "share"]), ("laugh", "cry", ["smile", "grin", "joke"]),
            ("win", "lose", ["play", "score", "beat"]), ("first", "last", ["one", "start", "top"]), ("good", "bad", ["nice", "kind", "fine"]),
            ("young", "old", ["small", "little", "new"]), ("come", "go", ["walk", "run", "arrive"]), ("inside", "outside", ["within", "into", "in"]),
        ]
    ],
    "en2.plural": [
        it(one, f"One {one}, two ___?", [many] + other, why)
        for one, many, other, why in [
            ("bird", "birds", ["bird", "birdes", "birdz"], "For more than one, add s: birds."),
            ("cow", "cows", ["cow", "cowes", "cowz"], "For more than one, add s: cows."),
            ("car", "cars", ["car", "cares", "carz"], "For more than one, add s: cars."),
            ("bag", "bags", ["bag", "bages", "bagz"], "For more than one, add s: bags."),
            ("hat", "hats", ["hat", "hates", "hatz"], "For more than one, add s: hats."),
            ("toy", "toys", ["toy", "toies", "toyz"], "For more than one, add s: toys."),
            ("fox", "foxes", ["foxs", "fox", "foxies"], "Words ending in x add es: foxes."),
            ("glass", "glasses", ["glasss", "glass", "glassies"], "Words ending in s add es: glasses."),
            ("bench", "benches", ["benchs", "bench", "benchies"], "Words ending in ch add es: benches."),
            ("brush", "brushes", ["brushs", "brush", "brushies"], "Words ending in sh add es: brushes."),
            ("baby", "babies", ["babys", "baby", "babyes"], "Change y to i and add es: babies."),
            ("lady", "ladies", ["ladys", "lady", "ladyes"], "Change y to i and add es: ladies."),
            ("child", "children", ["childs", "child", "childes"], "One child, many children."),
            ("man", "men", ["mans", "man", "manes"], "One man, many men."),
            ("tooth", "teeth", ["tooths", "tooth", "toothes"], "One tooth, many teeth."),
            ("foot", "feet", ["foots", "foot", "footes"], "One foot, two feet."),
        ]
    ],
    "en3.article": [
        it(w, f"___ {w}", [art, "a" if art == "an" else "an"], why)
        for w, art, why in [
            ("ant", "an", "Ant starts with a vowel sound, so we say an ant."),
            ("elephant", "an", "Elephant starts with a vowel sound, so we say an elephant."),
            ("onion", "an", "Onion starts with a vowel sound, so we say an onion."),
            ("ink pen", "an", "Ink starts with a vowel sound, so we say an ink pen."),
            ("eagle", "an", "Eagle starts with a vowel sound, so we say an eagle."),
            ("igloo", "an", "Igloo starts with a vowel sound, so we say an igloo."),
            ("arm", "an", "Arm starts with a vowel sound, so we say an arm."),
            ("hour", "an", "Hour starts with an o sound, so we say an hour."),
            ("box", "a", "Box starts with a b sound, so we say a box."),
            ("pen", "a", "Pen starts with a p sound, so we say a pen."),
            ("lion", "a", "Lion starts with an l sound, so we say a lion."),
            ("rose", "a", "Rose starts with an r sound, so we say a rose."),
            ("uniform", "a", "Uniform starts with a y sound, so we say a uniform."),
            ("school", "a", "School starts with an s sound, so we say a school."),
            ("girl", "a", "Girl starts with a g sound, so we say a girl."),
            ("van", "a", "Van starts with a v sound, so we say a van."),
        ]
    ],
    "en3.action": [
        it(w, "Which one is an action word?", [w] + other, f"An action word tells what we do: {w}.")
        for w, other in [
            ("kick", ["ball", "goal", "fast"]), ("draw", ["paper", "colour", "nice"]), ("wash", ["soap", "clean", "hands"]),
            ("clap", ["hands", "loud", "song"]), ("laugh", ["joke", "funny", "friend"]), ("cry", ["baby", "tears", "sad"]),
            ("push", ["door", "heavy", "cart"]), ("dig", ["soil", "deep", "garden"]), ("bake", ["cake", "oven", "warm"]),
            ("paint", ["wall", "brush", "blue"]), ("catch", ["ball", "quick", "net"]), ("fly", ["bird", "sky", "high"]),
            ("ride", ["bicycle", "road", "fast"]), ("carry", ["bag", "heavy", "box"]), ("listen", ["music", "ears", "quiet"]),
            ("shout", ["loud", "voice", "angry"]), ("hug", ["mother", "warm", "arms"]), ("drink", ["water", "glass", "cold"]),
        ]
    ],
    "en4.past": [
        it(f"{now}-{past}", f"Yesterday, I ___ {rest}.", [past] + other, f"Yesterday is the past: {now} becomes {past}.")
        for now, past, rest, other in [
            ("swim", "swam", "in the pool", ["swim", "swims", "swimming"]), ("read", "read", "a story", ["reads", "reading", "readed"]),
            ("buy", "bought", "a pencil", ["buy", "buys", "buyed"]), ("sleep", "slept", "early", ["sleep", "sleeps", "sleeped"]),
            ("climb", "climbed", "a tree", ["climb", "climbs", "climbing"]), ("draw", "drew", "a cat", ["draw", "draws", "drawed"]),
            ("take", "took", "a photo", ["take", "takes", "taked"]), ("give", "gave", "a gift", ["give", "gives", "gived"]),
            ("come", "came", "home late", ["come", "comes", "comed"]), ("help", "helped", "my mother", ["help", "helps", "helping"]),
            ("find", "found", "a coin", ["find", "finds", "finded"]), ("fly", "flew", "a kite", ["fly", "flies", "flyed"]),
            ("throw", "threw", "a ball", ["throw", "throws", "throwed"]), ("dance", "danced", "at a party", ["dance", "dances", "dancing"]),
            ("ride", "rode", "a bicycle", ["ride", "rides", "rided"]), ("catch", "caught", "a fish", ["catch", "catches", "catched"]),
        ]
    ],
    "en4.describe": [
        it(adj, f"Which word describes? \"{phrase}\"", [adj] + other, f"{adj.capitalize()} tells us more about the {noun}.")
        for phrase, adj, noun, other in [
            ("a green leaf", "green", "leaf", ["a", "leaf"]), ("the fast car", "fast", "car", ["the", "car"]),
            ("a round plate", "round", "plate", ["a", "plate"]), ("the loud drum", "loud", "drum", ["the", "drum"]),
            ("a kind teacher", "kind", "teacher", ["a", "teacher"]), ("the dark night", "dark", "night", ["the", "night"]),
            ("a heavy bag", "heavy", "bag", ["a", "bag"]), ("the shiny coin", "shiny", "coin", ["the", "coin"]),
            ("a brave soldier", "brave", "soldier", ["a", "soldier"]), ("the long road", "long", "road", ["the", "road"]),
            ("a sour lemon", "sour", "lemon", ["a", "lemon"]), ("the clean room", "clean", "room", ["the", "room"]),
            ("a tiny ant", "tiny", "ant", ["a", "ant"]), ("the wet towel", "wet", "towel", ["the", "towel"]),
            ("a busy market", "busy", "market", ["a", "market"]), ("the funny clown", "funny", "clown", ["the", "clown"]),
        ]
    ],
    "en5.synonym": [
        it(f"{a}-{b}", f"Which word means the same as {a}?", [b] + other, f"{a.capitalize()} and {b} mean the same.")
        for a, b, other in [
            ("end", "finish", ["start", "open", "begin"]), ("tired", "sleepy", ["fresh", "awake", "lively"]), ("rich", "wealthy", ["poor", "needy", "weak"]),
            ("quiet", "silent", ["noisy", "loud", "busy"]), ("easy", "simple", ["hard", "tough", "tricky"]), ("near", "close", ["far", "away", "distant"]),
            ("sick", "ill", ["well", "fit", "strong"]), ("pretty", "lovely", ["ugly", "plain", "dull"]), ("speak", "talk", ["listen", "hear", "write"]),
            ("jump", "leap", ["sit", "rest", "stand"]), ("buy", "purchase", ["sell", "lend", "give"]), ("huge", "giant", ["tiny", "small", "short"]),
            ("cold", "chilly", ["hot", "warm", "sunny"]), ("story", "tale", ["song", "poem", "game"]), ("road", "street", ["river", "field", "hill"]),
            ("wet", "damp", ["dry", "warm", "clean"]),
        ]
    ],
    "en5.punct": [
        it(f"q{i}", f"Which mark ends this? \"{s}\"", [m] + [x for x in ["?", ".", "!"] if x != m], why)
        for i, (s, m, why) in enumerate([
            ("Is it raining", "?", "It asks something, so it ends with a question mark."),
            ("The cat is sleeping", ".", "It tells something, so it ends with a full stop."),
            ("Who is your best friend", "?", "It asks something, so it ends with a question mark."),
            ("We went to the zoo", ".", "It tells something, so it ends with a full stop."),
            ("Why is the sky blue", "?", "It asks something, so it ends with a question mark."),
            ("Hurray, we won", "!", "It shows a strong feeling, so it ends with an exclamation mark."),
            ("Mangoes grow on trees", ".", "It tells something, so it ends with a full stop."),
            ("When does school start", "?", "It asks something, so it ends with a question mark."),
            ("Look out, a snake", "!", "It shows a strong feeling, so it ends with an exclamation mark."),
            ("I have two brothers", ".", "It tells something, so it ends with a full stop."),
            ("Do you like rice", "?", "It asks something, so it ends with a question mark."),
            ("Grandma tells us stories", ".", "It tells something, so it ends with a full stop."),
        ])
    ],
    "en6.prep": [
        it(f"pq{i}", f"The {thing} is ___ the {place}. ({hint})", [right] + other, why)
        for i, (thing, place, hint, right, other, why) in enumerate([
            ("milk", "glass", "inside it", "in", ["on", "under", "behind"], "Inside something means in."),
            ("fan", "bed", "higher than it", "above", ["under", "in", "behind"], "Higher than something means above."),
            ("bag", "chair", "below it", "under", ["on", "in", "above"], "Below something means under."),
            ("clock", "wall", "on its surface", "on", ["under", "in", "behind"], "On the surface of something means on."),
            ("tree", "house", "at its back", "behind", ["in", "on", "under"], "At the back of something means behind."),
            ("park", "home", "close to it", "near", ["under", "in", "on"], "Close to something means near."),
            ("baby", "mother and father", "in the middle", "between", ["on", "under", "above"], "In the middle of two means between."),
            ("fish", "pond", "inside it", "in", ["on", "above", "behind"], "Inside something means in."),
            ("cat", "sofa", "on top of it", "on", ["under", "in", "behind"], "On top of something means on."),
            ("plane", "clouds", "higher than them", "above", ["under", "in", "behind"], "Higher than something means above."),
            ("mouse", "cupboard", "below it", "under", ["on", "in", "above"], "Below something means under."),
            ("car", "bus", "at its back", "behind", ["in", "on", "above"], "At the back of something means behind."),
        ])
    ],
    "en6.pronoun": [
        it(f"pp{i}", f"{first} ___ {rest}.", [right] + other, why)
        for i, (first, rest, right, other, why) in enumerate([
            ("Sita has a cat.", "feeds it daily", "She", ["He", "It", "They"], "Sita is a girl, so we use she."),
            ("Raju is in Class 6.", "likes maths", "He", ["She", "It", "They"], "Raju is a boy, so we use he."),
            ("The cat has kittens.", "is a good mother", "It", ["He", "She", "We"], "A cat is an animal, so we use it."),
            ("Amit and Neha are twins.", "were born together", "They", ["He", "She", "It"], "Two people means they."),
            ("Mina and I are friends.", "walk to school", "We", ["They", "She", "It"], "Mina and I means we."),
            ("My father is a farmer.", "grows wheat", "He", ["She", "It", "They"], "Father is a man, so we use he."),
            ("The book is new.", "has many pictures", "It", ["He", "She", "They"], "A book is a thing, so we use it."),
            ("The girls are singing.", "sing very well", "They", ["She", "It", "He"], "Many girls means they."),
            ("Grandma is visiting.", "brings sweets", "She", ["He", "It", "They"], "Grandma is a woman, so we use she."),
            ("The river is wide.", "flows to the sea", "It", ["He", "She", "They"], "A river is a thing, so we use it."),
            ("You and I won.", "are the champions", "We", ["They", "He", "It"], "You and I means we."),
            ("Uncle Ravi drives a bus.", "is a careful driver", "He", ["She", "It", "They"], "Uncle Ravi is a man, so we use he."),
        ])
    ],
    "en7.tense": [
        it(f"u{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Right now, Ravi ___ his homework.", "is doing", ["did", "will do", "does"], "Right now means it is happening: is doing."),
            ("Last Sunday, we ___ a picnic.", "had", ["have", "will have", "are having"], "Last Sunday means the past: had."),
            ("Next week, the school ___.", "will reopen", ["reopened", "reopens", "was reopening"], "Next week means later: will reopen."),
            ("Look, the kite ___ high!", "is flying", ["flew", "will fly", "flies"], "Look means it is happening now: is flying."),
            ("Long ago, kings ___ in forts.", "lived", ["live", "will live", "are living"], "Long ago means the past: lived."),
            ("Tomorrow, it ___ cold.", "will be", ["was", "is", "were"], "Tomorrow means later: will be."),
            ("At the moment, she ___ tea.", "is drinking", ["drank", "will drink", "drinks"], "At the moment means now: is drinking."),
            ("In 2020, I ___ five.", "was", ["am", "will be", "is"], "In 2020 is the past: was."),
            ("Later today, we ___ cricket.", "will play", ["played", "play", "were playing"], "Later today means the future: will play."),
            ("Hush, the baby ___!", "is sleeping", ["slept", "will sleep", "sleeps"], "Hush means it is happening now: is sleeping."),
            ("Yesterday, the shop ___ early.", "closed", ["closes", "will close", "is closing"], "Yesterday means the past: closed."),
            ("Soon, the mangoes ___ ripe.", "will be", ["were", "was", "are being"], "Soon means later: will be."),
        ])
    ],
    "en7.agree": [
        it(f"b{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("The birds ___ flying.", "are", ["is", "am"], "Birds means many, so we use are."),
            ("My father ___ tall.", "is", ["are", "am"], "Father is one person, so we use is."),
            ("They ___ my cousins.", "are", ["is", "am"], "They means many, so we use are."),
            ("The tea ___ hot.", "is", ["are", "am"], "Tea is one thing, so we use is."),
            ("I ___ in Class 7.", "am", ["is", "are"], "With I, we always use am."),
            ("These books ___ new.", "are", ["is", "am"], "These books means many, so we use are."),
            ("She ___ a good dancer.", "is", ["are", "am"], "She is one person, so we use is."),
            ("The cows ___ in the field.", "are", ["is", "am"], "Cows means many, so we use are."),
            ("Our school ___ big.", "is", ["are", "am"], "One school, so we use is."),
            ("You and Riya ___ late.", "are", ["is", "am"], "Two people means we use are."),
            ("The window ___ open.", "is", ["are", "am"], "One window, so we use is."),
            ("My shoes ___ dirty.", "are", ["is", "am"], "Shoes means many, so we use are."),
        ])
    ],
    # ── EVS and Science ──
    "ev0.animals": [
        pic_q("bone", "Which one loves a bone?", "dog", ["fish", "bird", "ant"], "A dog loves to chew a bone."),
        pic_q("nest", "Which one builds a nest?", "bird", ["cow", "dog", "fish"], "Birds build nests for their eggs."),
        pic_q("sugar", "Which one loves sugar?", "ant", ["cow", "fish", "dog"], "Ants love sweet things like sugar."),
        pic_q("tail-swim", "Which one swims with its tail?", "fish", ["cat", "dog", "cow"], "A fish swims by moving its tail."),
        pic_q("whiskers", "Which one has whiskers and says meow?", "cat", ["fish", "cow", "bird"], "A cat has whiskers and says meow."),
        pic_q("horns", "Which one has horns?", "cow", ["cat", "fish", "bird"], "A cow has two horns."),
        pic_q("wings", "Which one has wings?", "bird", ["dog", "fish", "cow"], "A bird has wings to fly."),
        pic_q("small-line", "Which one walks in a line?", "ant", ["cow", "cat", "dog"], "Ants walk one behind the other."),
        pic_q("wag", "Which one wags its tail when happy?", "dog", ["fish", "bird", "ant"], "A happy dog wags its tail."),
        pic_q("pond", "Which one lives in a pond?", "fish", ["cat", "cow", "dog"], "Fish live in ponds and rivers."),
        pic_q("mouse", "Which one chases mice?", "cat", ["cow", "fish", "bird"], "Cats like to chase mice."),
        pic_q("bell", "Which one may wear a bell on its neck?", "cow", ["fish", "ant", "bird"], "Many cows wear bells on their necks."),
    ],
    "ev0.body": [
        pic_q("glasses", "Which one may need glasses?", "eye", ["ear", "nose", "hand"], "Glasses help our eyes see clearly."),
        pic_q("listen", "Which one listens to a story?", "ear", ["eye", "hand", "tooth"], "We listen with our ears."),
        pic_q("sneeze", "Which one sneezes?", "nose", ["ear", "eye", "hand"], "We sneeze through our nose."),
        pic_q("clap", "Which one do we clap with?", "hand", ["nose", "eye", "ear"], "We clap with our hands."),
        pic_q("milk-teeth", "Which one falls out and grows again?", "tooth", ["eye", "ear", "hand"], "Milk teeth fall out and new teeth grow."),
        pic_q("write", "Which one do we write with?", "hand", ["ear", "nose", "tooth"], "We hold a pencil in our hand to write."),
        pic_q("read", "Which one do we read with?", "eye", ["ear", "nose", "hand"], "We read with our eyes."),
        pic_q("bell", "Which one hears the school bell?", "ear", ["eye", "nose", "tooth"], "Our ears hear the bell ring."),
        pic_q("food-smell", "Which one tells us food smells nice?", "nose", ["eye", "hand", "ear"], "Our nose smells food."),
        pic_q("bite", "Which one bites an apple?", "tooth", ["hand", "ear", "eye"], "Our teeth bite food."),
        pic_q("shake", "Which one do we shake to say hello?", "hand", ["ear", "nose", "tooth"], "We shake hands to say hello."),
        pic_q("sleep", "Which one do we close to sleep?", "eye", ["ear", "nose", "hand"], "We close our eyes to sleep."),
    ],
    "ev1.fruits": [
        it(f"g{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Which one is a fruit?", "banana", ["potato", "onion", "spinach"], "A banana is a fruit."),
            ("Which one is a vegetable?", "potato", ["mango", "grapes", "apple"], "A potato is a vegetable."),
            ("Which one is a fruit?", "grapes", ["carrot", "peas", "onion"], "Grapes are small, sweet fruits."),
            ("Which one is a vegetable?", "peas", ["banana", "orange", "mango"], "Peas are a green vegetable."),
            ("Which fruit is green outside and red inside?", "watermelon", ["banana", "mango", "lemon"], "A watermelon is green outside and red inside."),
            ("Which vegetable is red and round?", "tomato", ["potato", "peas", "onion"], "A tomato is red and round."),
            ("Which fruit grows in bunches?", "grapes", ["mango", "apple", "orange"], "Grapes grow in bunches."),
            ("Which vegetable is long and green?", "cucumber", ["tomato", "potato", "onion"], "A cucumber is long and green."),
            ("Which fruit has a hard shell and white inside?", "coconut", ["banana", "apple", "grapes"], "A coconut has a hard shell."),
            ("Which one is a fruit?", "guava", ["cabbage", "radish", "onion"], "A guava is a fruit."),
            ("Which vegetable has many layers?", "cabbage", ["mango", "apple", "grapes"], "A cabbage has many leafy layers."),
            ("Which one is orange in colour?", "carrot", ["peas", "cabbage", "spinach"], "A carrot is orange."),
        ])
    ],
    "ev1.senses": [
        it(f"t{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("We smell a flower with our ___.", "nose", ["ears", "eyes", "hands"], "Our nose smells flowers."),
            ("We see colours with our ___.", "eyes", ["ears", "nose", "tongue"], "Our eyes see colours."),
            ("We hear a bell with our ___.", "ears", ["eyes", "nose", "skin"], "Our ears hear sounds."),
            ("Honey tastes ___.", "sweet", ["sour", "salty", "bitter"], "Honey tastes sweet."),
            ("Bitter gourd tastes ___.", "bitter", ["sweet", "salty", "sour"], "Bitter gourd tastes bitter."),
            ("A stone feels ___.", "hard", ["soft", "wet", "hot"], "A stone feels hard."),
            ("Hot tea feels ___.", "hot", ["cold", "soft", "wet"], "Tea fresh from the stove feels hot."),
            ("A whistle sounds ___.", "loud", ["soft", "sweet", "sour"], "A whistle makes a loud sound."),
            ("Cotton feels ___.", "soft", ["hard", "rough", "sharp"], "Cotton feels soft."),
            ("We feel touch with our ___.", "skin", ["ears", "eyes", "nose"], "Our skin feels touch."),
            ("Lemon pickle tastes ___.", "sour", ["sweet", "plain", "bitter"], "Lemon pickle tastes sour."),
            ("Chilli tastes ___.", "spicy", ["sweet", "sour", "plain"], "Chilli tastes spicy hot."),
        ])
    ],
    "ev2.homes": [
        it(f"k{i}", f"Where does a {a} live?", [home] + other, f"A {a} lives in a {home}.")
        for i, (a, home, other) in enumerate([
            ("tiger", "den", ["nest", "hive", "web"]), ("snake", "hole", ["nest", "hive", "stable"]),
            ("frog", "pond", ["nest", "hive", "stable"]), ("monkey", "tree", ["hive", "web", "kennel"]),
            ("parrot", "nest", ["kennel", "hive", "sty"]), ("duck", "pond", ["hive", "web", "den"]),
            ("camel", "desert", ["sea", "pond", "hive"]), ("whale", "sea", ["desert", "nest", "den"]),
            ("mouse", "hole", ["nest", "hive", "web"]), ("sparrow", "nest", ["stable", "den", "sty"]),
            ("buffalo", "shed", ["nest", "hive", "web"]), ("goat", "shed", ["nest", "web", "hive"]),
        ])
    ],
    "ev2.plants": [
        it(f"q{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("We eat the leaves of ___.", "cabbage", ["carrot", "potato", "mango"], "Cabbage leaves are eaten as a vegetable."),
            ("We eat the root of ___.", "radish", ["spinach", "mango", "peas"], "A radish is a root we eat."),
            ("We eat the seeds of ___.", "peas", ["carrot", "spinach", "radish"], "We eat the seeds of the pea plant."),
            ("We eat the flower of ___.", "cauliflower", ["carrot", "potato", "mango"], "Cauliflower is a flower we eat."),
            ("Which part carries water up the plant?", "stem", ["flower", "fruit", "seed"], "The stem carries water up to the leaves."),
            ("Which part has seeds inside?", "fruit", ["root", "stem", "leaf"], "Fruits keep the seeds inside."),
            ("Which plant has thorns?", "rose", ["mango", "grass", "banana"], "A rose plant has thorns on its stem."),
            ("Which plant is very big and strong?", "tree", ["grass", "herb", "creeper"], "A tree is big with a hard trunk."),
            ("Which plant climbs on a wall?", "creeper", ["tree", "shrub", "grass"], "A creeper needs support to climb."),
            ("Which plant grows in water?", "lotus", ["cactus", "mango", "rose"], "A lotus grows in ponds."),
            ("Which plant grows in the desert?", "cactus", ["lotus", "rice", "rose"], "A cactus can live with little water."),
            ("Which part of a plant smells sweet?", "flower", ["root", "stem", "seed"], "Many flowers smell sweet."),
        ])
    ],
    "ev3.water": [
        it(f"x{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Water from a well is ___ water.", "ground", ["sea", "rain", "salt"], "Well water comes from under the ground."),
            ("Ice is water that has become ___.", "solid", ["gas", "steam", "air"], "Ice is frozen, solid water."),
            ("We should boil water to make it ___.", "safe", ["salty", "cold", "sweet"], "Boiling kills germs in water."),
            ("Puddles dry up because of the ___.", "sun", ["moon", "stars", "wind chime"], "The sun's heat dries puddles."),
            ("Which one holds the most water?", "sea", ["pond", "well", "bucket"], "The sea holds a huge amount of water."),
            ("Fish breathe the air in ___.", "water", ["soil", "sand", "rocks"], "Fish take air from water."),
            ("A leaking tap wastes ___.", "water", ["air", "light", "soil"], "A dripping tap wastes water."),
            ("Rain is collected in ___ harvesting.", "rainwater", ["sunlight", "wind", "soil"], "Rainwater harvesting saves rain for later."),
            ("Water is needed to grow ___.", "crops", ["rocks", "metals", "plastic"], "Farmers need water to grow crops."),
            ("Which season brings the most rain?", "monsoon", ["winter", "spring", "summer"], "The monsoon brings heavy rain."),
            ("Muddy water can be cleaned by ___.", "filtering", ["freezing", "shaking", "colouring"], "A filter traps the mud."),
            ("Clouds are made of tiny drops of ___.", "water", ["milk", "oil", "sand"], "Clouds are tiny water drops floating in air."),
        ])
    ],
    "ev3.food": [
        it(f"fe{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Which one comes from plants?", "wheat", ["egg", "fish", "milk"], "Wheat grows in fields."),
            ("Which one comes from animals?", "egg", ["rice", "apple", "dal"], "Eggs come from hens."),
            ("Sugar comes from ___.", "sugarcane", ["milk", "salt", "rice"], "Sugar is made from sugarcane."),
            ("Ghee is made from ___.", "milk", ["wheat", "oil", "rice"], "Ghee is made from milk."),
            ("Which one is a spice?", "turmeric", ["rice", "milk", "bread"], "Turmeric is a yellow spice."),
            ("Tea leaves grow on a ___.", "plant", ["cow", "rock", "hen"], "Tea leaves come from tea plants."),
            ("Which food is made from rice?", "idli", ["roti", "omelette", "paneer"], "Idli batter is made from rice."),
            ("Which one is a dry fruit?", "almond", ["mango", "banana", "melon"], "Almonds are dry fruits."),
            ("Which grain makes popcorn?", "corn", ["rice", "wheat", "dal"], "Popcorn is made from corn."),
            ("Which one should we eat less of?", "sweets", ["fruits", "vegetables", "dal"], "Too many sweets harm our teeth."),
            ("Jaggery is made from ___.", "sugarcane", ["milk", "wheat", "rice"], "Jaggery is made from sugarcane juice."),
            ("Which oil is made from coconuts?", "coconut oil", ["mustard oil", "ghee", "butter"], "Coconut oil is pressed from coconuts."),
        ])
    ],
    "ev4.travel": [
        it(f"tv{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Which one has two wheels?", "bicycle", ["bus", "car", "truck"], "A bicycle has two wheels."),
            ("Which one carries many goods by road?", "truck", ["kite", "boat", "cycle"], "A truck carries heavy goods by road."),
            ("Which one runs on electricity under cities?", "metro", ["boat", "cart", "plane"], "A metro train runs under many cities."),
            ("Which one is the fastest?", "plane", ["bus", "cycle", "cart"], "A plane is the fastest of these."),
            ("Which one is rowed with oars?", "boat", ["bus", "car", "train"], "A small boat is rowed with oars."),
            ("Which one carries sick people quickly?", "ambulance", ["truck", "tractor", "cart"], "An ambulance rushes sick people to hospital."),
            ("Which one helps farmers in fields?", "tractor", ["plane", "ship", "metro"], "A tractor pulls tools in the fields."),
            ("We should wear a ___ on a bike.", "helmet", ["cap", "scarf", "crown"], "A helmet keeps our head safe."),
            ("In a car, we should wear a ___.", "seat belt", ["necklace", "watch", "ring"], "A seat belt keeps us safe."),
            ("Yellow traffic light means ___.", "wait", ["run", "go fast", "turn"], "Yellow means wait and get ready."),
            ("Which one does not need roads?", "plane", ["bus", "car", "truck"], "A plane flies through the sky."),
            ("Which one is pulled by horses?", "tonga", ["metro", "scooter", "van"], "A tonga is a cart pulled by a horse."),
        ])
    ],
    "ev4.animals": [
        it(f"ag{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Which animal lays eggs?", "duck", ["dog", "goat", "horse"], "A duck lays eggs."),
            ("Which animal lays eggs?", "snake", ["cow", "cat", "lion"], "Most snakes lay eggs."),
            ("Which animal feeds milk to its babies?", "dog", ["hen", "fish", "frog"], "A dog feeds its puppies milk."),
            ("Which animal eats only plants?", "deer", ["tiger", "lion", "eagle"], "A deer eats grass and leaves."),
            ("Which animal eats only plants?", "elephant", ["lion", "wolf", "shark"], "An elephant eats plants only."),
            ("Which animal hunts other animals?", "tiger", ["cow", "rabbit", "deer"], "A tiger hunts for its food."),
            ("Which animal eats both plants and animals?", "bear", ["cow", "goat", "deer"], "A bear eats fruits and fish."),
            ("Which one is an insect?", "butterfly", ["crow", "frog", "fish"], "A butterfly is an insect with six legs."),
            ("Which one is an insect?", "bee", ["bat", "snake", "rat"], "A bee is an insect."),
            ("How many legs does a spider have?", "eight", ["six", "four", "two"], "A spider has eight legs."),
            ("Which animal has a pouch?", "kangaroo", ["cow", "dog", "cat"], "A kangaroo carries its baby in a pouch."),
            ("Which animal sleeps hanging upside down?", "bat", ["cow", "hen", "dog"], "A bat sleeps hanging upside down."),
        ])
    ],
    "ev5.states": [
        it(f"sx{i}", f"{thing} is a ___.", [right] + [x for x in ["solid", "liquid", "gas"] if x != right], why)
        for i, (thing, right, why) in enumerate([
            ("A brick", "solid", "A brick keeps its shape, so it is a solid."),
            ("Honey", "liquid", "Honey flows slowly, so it is a liquid."),
            ("Oxygen", "gas", "Oxygen spreads in the air, so it is a gas."),
            ("A spoon", "solid", "A spoon keeps its shape, so it is a solid."),
            ("Rain water", "liquid", "Rain water flows, so it is a liquid."),
            ("The smell of food", "gas", "Smells spread through air as a gas."),
            ("Butter in the fridge", "solid", "Cold butter keeps its shape, so it is a solid."),
            ("Coconut water", "liquid", "Coconut water can be poured, so it is a liquid."),
            ("Air in a tyre", "gas", "Air fills the whole tyre, so it is a gas."),
            ("Sugar", "solid", "Each grain of sugar keeps its shape, so it is a solid."),
            ("Kerosene", "liquid", "Kerosene flows, so it is a liquid."),
            ("Water vapour", "gas", "Water vapour spreads into the air, so it is a gas."),
        ])
    ],
    "ev5.seeds": [
        it(f"sg{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Which seed do we use to make oil?", "mustard", ["mango", "apple", "guava"], "Mustard seeds give us oil."),
            ("Which seed is a spice?", "cumin", ["rice", "wheat", "peas"], "Cumin seeds are used as a spice."),
            ("Seeds of the drumstick tree spread by ___.", "wind", ["water", "birds", "cows"], "Winged drumstick seeds fly on the wind."),
            ("Coconuts can spread by floating on ___.", "water", ["air", "sand", "rocks"], "A coconut can float across water."),
            ("Some seeds stick to animals' ___.", "fur", ["teeth", "eyes", "horns"], "Prickly seeds cling to animal fur."),
            ("A young plant grows ___ first.", "roots", ["fruits", "flowers", "seeds"], "A sprout pushes its root down first."),
            ("Rice is grown in fields full of ___.", "water", ["sand", "snow", "stones"], "Rice grows in flooded fields."),
            ("Which part of a peanut do we eat?", "seed", ["root", "leaf", "flower"], "A peanut is a seed."),
            ("Which part of wheat makes flour?", "grain", ["leaf", "root", "stem"], "Wheat grains are ground into flour."),
            ("Seeds need ___ to sprout.", "air", ["darkness", "salt", "sugar"], "Seeds need air, water and warmth to sprout."),
            ("A seed kept in a dry box will ___.", "not sprout", ["sprout", "melt", "flower"], "Without water, a seed will not sprout."),
            ("Which fruit has one big seed?", "mango", ["papaya", "watermelon", "guava"], "A mango has one big seed inside."),
        ])
    ],
    "sc6.living": [
        it(f"lw{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Which one is living?", "earthworm", ["stone", "pencil", "glass"], "An earthworm moves, eats and grows."),
            ("Which one is non-living?", "bicycle", ["cow", "rose", "ant"], "A bicycle does not grow or eat."),
            ("Living things get rid of ___.", "waste", ["paint", "metal", "plastic"], "Living things remove waste from their bodies."),
            ("Which one is living?", "grass", ["sand", "cloud", "brick"], "Grass grows and needs water."),
            ("Which one is non-living?", "fire", ["bird", "tree", "snake"], "Fire moves but does not grow or breathe."),
            ("Plants make their own ___.", "food", ["water", "soil", "air"], "Plants make food using sunlight."),
            ("A hen's egg can become a ___.", "chick", ["stone", "seed", "plant"], "A chick hatches from a hen's egg."),
            ("Which one can breathe?", "frog", ["chair", "cup", "stone"], "A frog breathes, so it is living."),
            ("Which one is non-living?", "cloud", ["fish", "tree", "cat"], "A cloud moves but is not alive."),
            ("Living things die after their ___.", "lifespan", ["painting", "washing", "cooking"], "Every living thing has a lifespan."),
            ("A tadpole grows into a ___.", "frog", ["fish", "snake", "bird"], "A tadpole slowly changes into a frog."),
            ("Which one feels hungry?", "puppy", ["robot", "doll", "car"], "A puppy is living, so it gets hungry."),
        ])
    ],
    "sc6.food": [
        it(f"nf{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Fish and meat are rich in ___.", "protein", ["sugar", "fibre", "salt"], "Fish and meat have lots of protein."),
            ("Bread and potatoes give us ___.", "energy", ["bones", "nails", "hair"], "Bread and potatoes are rich in carbohydrates."),
            ("Lemons and amla are rich in vitamin ___.", "C", ["A", "D", "K"], "Citrus fruits and amla have vitamin C."),
            ("Sunlight helps our body make vitamin ___.", "D", ["A", "B", "C"], "Our skin makes vitamin D in sunlight."),
            ("Leafy vegetables are rich in ___.", "iron", ["fat", "sugar", "salt"], "Spinach and greens have iron."),
            ("Which food has a lot of fibre?", "fruits", ["sugar", "butter", "oil"], "Fruits and vegetables are rich in fibre."),
            ("Too little vitamin C can cause ___.", "scurvy", ["cold", "fever", "cough"], "Scurvy makes gums bleed without vitamin C."),
            ("Nuts and oils are rich in ___.", "fat", ["fibre", "water", "starch"], "Nuts and oils give us fats."),
            ("Milk and curd give us ___.", "calcium", ["iron", "sugar", "fibre"], "Milk products are rich in calcium."),
            ("Which meal is the most balanced?", "a thali", ["chips", "sweets", "cola"], "A thali of dal, rice and sabzi has many nutrients."),
            ("Water helps our body remove ___.", "waste", ["bones", "muscles", "teeth"], "Water carries waste out of the body."),
            ("Fried food has too much ___.", "fat", ["fibre", "vitamin", "water"], "Frying adds lots of fat to food."),
        ])
    ],
    "sc7.plants": [
        it(f"pz{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Plants take in water through their ___.", "roots", ["leaves", "flowers", "fruits"], "Roots soak up water from the soil."),
            ("Which gas do we breathe out that plants use?", "carbon dioxide", ["oxygen", "nitrogen", "steam"], "Plants use the carbon dioxide we breathe out."),
            ("Leaves of most plants are ___.", "green", ["blue", "black", "white"], "Chlorophyll makes leaves green."),
            ("Plants that make their own food are ___.", "autotrophs", ["parasites", "insects", "animals"], "Autotrophs make their own food."),
            ("Animals that cannot make food are ___.", "heterotrophs", ["autotrophs", "plants", "algae"], "Heterotrophs depend on others for food."),
            ("Lichen is a partnership of algae and ___.", "fungus", ["fish", "rock", "insect"], "Algae and fungus live together as lichen."),
            ("Bean plants add ___ to the soil.", "nitrogen", ["plastic", "salt", "oil"], "Bacteria in bean roots add nitrogen."),
            ("Which one is a parasite plant?", "cuscuta", ["mango", "rose", "wheat"], "Cuscuta takes food from other plants."),
            ("Bread mould is a kind of ___.", "fungus", ["plant", "insect", "seed"], "Mould on bread is a fungus."),
            ("Desert plants have spines instead of ___.", "leaves", ["roots", "stems", "seeds"], "Spines save water in the desert."),
            ("Plants make food mostly during the ___.", "day", ["night", "evening", "dawn"], "Plants need sunlight to make food."),
            ("Starch turns blue-black with ___.", "iodine", ["water", "salt", "milk"], "Iodine shows that starch is present."),
        ])
    ],
    "sc7.heat": [
        it(f"hx{i}", q, [right] + other, why)
        for i, (q, right, other, why) in enumerate([
            ("Which one is a good conductor of heat?", "copper", ["rubber", "wood", "paper"], "Copper passes heat very quickly."),
            ("Which one is an insulator?", "plastic", ["iron", "copper", "steel"], "Plastic does not pass heat easily."),
            ("Heat moves through a metal spoon by ___.", "conduction", ["radiation", "convection", "magic"], "Heat passes along solids by conduction."),
            ("Hot water rising in a pot is ___.", "convection", ["conduction", "radiation", "freezing"], "Warm water rises in convection currents."),
            ("We feel the sun's heat by ___.", "radiation", ["conduction", "convection", "touch"], "The sun's heat reaches us by radiation."),
            ("At night, a land breeze blows from ___.", "land to sea", ["sea to land", "hill to hill", "town to town"], "At night land cools faster, so air moves out."),
            ("Water boils at ___.", "100 °C", ["50 °C", "0 °C", "37 °C"], "Water boils at 100 degrees Celsius."),
            ("Water freezes at ___.", "0 °C", ["100 °C", "37 °C", "50 °C"], "Water freezes at 0 degrees Celsius."),
            ("Dark clothes take in ___ heat.", "more", ["less", "no", "cold"], "Dark colours soak up more heat."),
            ("A clinical thermometer checks ___.", "body temperature", ["room size", "weight", "height"], "A clinical thermometer measures body temperature."),
            ("Cooking pots have metal bottoms to ___ heat.", "conduct", ["block", "freeze", "waste"], "Metal passes the stove's heat to the food."),
            ("A woollen blanket keeps us ___.", "warm", ["wet", "cold", "sticky"], "Wool traps warm air close to us."),
        ])
    ],
}
