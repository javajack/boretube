#!/usr/bin/env python3
"""Authors boretube Learn's written banks (spec §4) and their review pages.

Every item: (id, question, [right answer FIRST, then wrong options], why, picture?).
The app shuffles options, so writing the answer first is only for review.
Rules (checked again by learn-core's PackValidator):
  * the why is ONE sentence, at most 12 words, plain words for that class;
  * options are "pic:<id>" pictures for KG (they can't read yet);
  * NCERT learning-outcome codes are our own index (content/outcomes.md).

    python3 tools/content/packs.py      # writes assets/content/** and content/review/*.html
"""
import html
import json
import os

HERE = os.path.dirname(__file__)
ASSETS = os.path.join(HERE, "..", "..", "app", "src", "main", "assets", "content")
REVIEW = os.path.join(HERE, "..", "..", "content", "review")
REVIEWED = os.path.join(HERE, "reviewed.json")  # {"english-1": {"by": "...", "at": "..."}}


from packs_lib import first_letter, it, pic_q, picture_word, skill  # noqa: E402


# ── English ──────────────────────────────────────────────────────────────

ENGLISH = {
    0: [
        skill("en0.letters", "First letters", "EN-0.01", "A", ["quickfire"], [
            first_letter("cat", "cat", ["B", "D", "S"]), first_letter("ball", "ball", ["C", "P", "D"]),
            first_letter("apple", "apple", ["E", "O", "B"]), first_letter("dog", "dog", ["B", "G", "P"]),
            first_letter("sun", "sun", ["C", "Z", "M"]), first_letter("fish", "fish", ["V", "H", "S"]),
            first_letter("egg", "egg", ["A", "I", "G"]), first_letter("house", "house", ["M", "N", "B"]),
            first_letter("moon", "moon", ["N", "W", "B"]), first_letter("tree", "tree", ["D", "F", "R"]),
            first_letter("bus", "bus", ["D", "P", "V"]), first_letter("nose", "nose", ["M", "U", "S"]),
        ]),
        skill("en0.words", "Picture words", "EN-0.02", "Aa", ["quickfire"], [
            picture_word("cup", ["cap", "cut", "pup"]), picture_word("car", ["cat", "jar", "bar"]),
            picture_word("book", ["look", "cook", "boat"]), picture_word("cow", ["how", "cot", "owl"]),
            picture_word("bird", ["bed", "bud", "card"]), picture_word("star", ["stop", "car", "jar"]),
            picture_word("hand", ["band", "sand", "head"]), picture_word("boat", ["coat", "goat", "book"]),
            picture_word("ant", ["and", "cat", "hat"]), picture_word("mango", ["melon", "man", "banana"]),
            picture_word("leaf", ["loaf", "leg", "lamp"]), picture_word("fire", ["five", "tire", "fish"]),
        ]),
    ],
    1: [
        skill("en1.naming", "Naming words", "EN-1.07", "Aa", ["quickfire", "catch"], [
            it(w, "Which one is a naming word?", [w] + other, f"A naming word names a thing: {w}.")
            for w, other in [
                ("cat", ["run", "big", "soft"]), ("book", ["read", "red", "fast"]), ("tree", ["tall", "grow", "very"]),
                ("ball", ["kick", "round", "high"]), ("mango", ["sweet", "eat", "ripe"]), ("school", ["go", "early", "happy"]),
                ("chair", ["sit", "soft", "down"]), ("river", ["flow", "cold", "deep"]), ("pencil", ["write", "sharp", "long"]),
                ("bird", ["fly", "small", "up"]), ("cup", ["drink", "hot", "full"]), ("bus", ["ride", "slow", "yellow"]),
            ]
        ]),
        skill("en1.rhyme", "Rhyming words", "EN-1.03", "-at", ["quickfire", "catch"], [
            it(f"{a}-{b}", f"Which word rhymes with {a}?", [b] + other, f"{a.capitalize()} and {b} end with the same sound.")
            for a, b, other in [
                ("cat", "hat", ["cup", "dog", "sun"]), ("sun", "fun", ["sit", "cat", "pen"]), ("ball", "tall", ["bell", "book", "fish"]),
                ("pen", "hen", ["pin", "cup", "box"]), ("cake", "lake", ["cook", "kite", "milk"]), ("star", "car", ["stop", "sun", "tree"]),
                ("bee", "tree", ["bat", "box", "cow"]), ("king", "ring", ["kite", "rain", "cup"]), ("frog", "log", ["fish", "leg", "fan"]),
                ("bed", "red", ["bad", "bus", "map"]), ("goat", "boat", ["gate", "bean", "pot"]), ("mouse", "house", ["mouth", "moon", "horse"]),
            ]
        ]),
    ],
    2: [
        skill("en2.opposite", "Opposites", "EN-2.04", "↔", ["quickfire", "catch"], [
            it(f"{a}-{b}", f"What is the opposite of {a}?", [b] + other, f"{a.capitalize()} and {b} are opposites.")
            for a, b, other in [
                ("big", "small", ["tall", "long", "wide"]), ("hot", "cold", ["warm", "wet", "dry"]), ("up", "down", ["over", "top", "high"]),
                ("happy", "sad", ["glad", "kind", "funny"]), ("fast", "slow", ["quick", "far", "late"]), ("day", "night", ["noon", "sun", "light"]),
                ("open", "close", ["push", "pull", "lock"]), ("full", "empty", ["half", "heavy", "big"]), ("old", "new", ["tall", "kind", "nice"]),
                ("in", "out", ["on", "at", "by"]), ("wet", "dry", ["cold", "hot", "soft"]), ("hard", "soft", ["tough", "big", "loud"]),
            ]
        ]),
        skill("en2.plural", "One and many", "EN-2.06", "s", ["quickfire", "catch"], [
            it(one, f"One {one}, two ___?", [many] + other, why)
            for one, many, other, why in [
                ("cat", "cats", ["cat", "cates", "catz"], "For more than one, add s: cats."),
                ("book", "books", ["book", "bookes", "bookz"], "For more than one, add s: books."),
                ("pen", "pens", ["pen", "penes", "penz"], "For more than one, add s: pens."),
                ("tree", "trees", ["tree", "treees", "treez"], "For more than one, add s: trees."),
                ("ball", "balls", ["ball", "balles", "ballz"], "For more than one, add s: balls."),
                ("girl", "girls", ["girl", "girles", "girlz"], "For more than one, add s: girls."),
                ("box", "boxes", ["boxs", "box", "boxies"], "Words ending in x add es: boxes."),
                ("bus", "buses", ["buss", "bus", "busies"], "Words ending in s add es: buses."),
                ("dish", "dishes", ["dishs", "dish", "dishies"], "Words ending in sh add es: dishes."),
                ("watch", "watches", ["watchs", "watch", "watchies"], "Words ending in ch add es: watches."),
                ("dog", "dogs", ["dog", "doges", "dogz"], "For more than one, add s: dogs."),
                ("cup", "cups", ["cup", "cupes", "cupz"], "For more than one, add s: cups."),
            ]
        ]),
    ],
    3: [
        skill("en3.article", "A or an", "EN-3.05", "an", ["quickfire"], [
            it(w, f"___ {w}", [art, "a" if art == "an" else "an"], why)
            for w, art, why in [
                ("apple", "an", "Apple starts with a vowel sound, so we say an apple."),
                ("egg", "an", "Egg starts with a vowel sound, so we say an egg."),
                ("orange", "an", "Orange starts with a vowel sound, so we say an orange."),
                ("umbrella", "an", "Umbrella starts with a vowel sound, so we say an umbrella."),
                ("ice cream", "an", "Ice starts with a vowel sound, so we say an ice cream."),
                ("owl", "an", "Owl starts with a vowel sound, so we say an owl."),
                ("ball", "a", "Ball starts with a b sound, so we say a ball."),
                ("cat", "a", "Cat starts with a c sound, so we say a cat."),
                ("dog", "a", "Dog starts with a d sound, so we say a dog."),
                ("tree", "a", "Tree starts with a t sound, so we say a tree."),
                ("kite", "a", "Kite starts with a k sound, so we say a kite."),
                ("mango", "a", "Mango starts with an m sound, so we say a mango."),
            ]
        ]),
        skill("en3.action", "Action words", "EN-3.07", "run", ["quickfire", "catch"], [
            it(w, "Which one is an action word?", [w] + other, f"An action word tells what we do: {w}.")
            for w, other in [
                ("run", ["ball", "red", "park"]), ("jump", ["rope", "high", "boy"]), ("eat", ["food", "plate", "hot"]),
                ("swim", ["pool", "fish", "cold"]), ("sing", ["song", "loud", "bird"]), ("write", ["pen", "page", "neat"]),
                ("read", ["book", "story", "good"]), ("dance", ["music", "girl", "happy"]), ("sleep", ["bed", "night", "tired"]),
                ("climb", ["tree", "tall", "hill"]), ("cook", ["food", "kitchen", "tasty"]), ("throw", ["ball", "far", "boy"]),
            ]
        ]),
    ],
    4: [
        skill("en4.past", "Past tense", "EN-4.06", "-ed", ["quickfire", "catch"], [
            it(f"{now}-{past}", f"Yesterday, I ___ {rest}.", [past] + other, why)
            for now, past, rest, other, why in [
                ("go", "went", "to school", ["go", "goes", "going"], "Yesterday is the past: go becomes went."),
                ("play", "played", "football", ["play", "plays", "playing"], "Yesterday is the past: play becomes played."),
                ("eat", "ate", "a mango", ["eat", "eats", "eating"], "Yesterday is the past: eat becomes ate."),
                ("see", "saw", "a rainbow", ["see", "sees", "seeing"], "Yesterday is the past: see becomes saw."),
                ("write", "wrote", "a letter", ["write", "writes", "writing"], "Yesterday is the past: write becomes wrote."),
                ("walk", "walked", "to the park", ["walk", "walks", "walking"], "Yesterday is the past: walk becomes walked."),
                ("drink", "drank", "milk", ["drink", "drinks", "drinking"], "Yesterday is the past: drink becomes drank."),
                ("jump", "jumped", "very high", ["jump", "jumps", "jumping"], "Yesterday is the past: jump becomes jumped."),
                ("make", "made", "a kite", ["make", "makes", "making"], "Yesterday is the past: make becomes made."),
                ("run", "ran", "a race", ["run", "runs", "running"], "Yesterday is the past: run becomes ran."),
                ("cook", "cooked", "rice", ["cook", "cooks", "cooking"], "Yesterday is the past: cook becomes cooked."),
                ("sing", "sang", "a song", ["sing", "sings", "singing"], "Yesterday is the past: sing becomes sang."),
            ]
        ]),
        skill("en4.describe", "Describing words", "EN-4.08", "red", ["quickfire", "catch"], [
            it(adj, f"Which word describes? \"{phrase}\"", [adj] + other, f"{adj.capitalize()} tells us more about the {noun}.")
            for phrase, adj, noun, other in [
                ("the red ball", "red", "ball", ["the", "ball"]), ("a tall tree", "tall", "tree", ["a", "tree"]),
                ("the hot tea", "hot", "tea", ["the", "tea"]), ("a happy girl", "happy", "girl", ["a", "girl"]),
                ("the soft pillow", "soft", "pillow", ["the", "pillow"]), ("a big elephant", "big", "elephant", ["a", "elephant"]),
                ("the sweet mango", "sweet", "mango", ["the", "mango"]), ("a cold drink", "cold", "drink", ["a", "drink"]),
                ("the noisy class", "noisy", "class", ["the", "class"]), ("a little kitten", "little", "kitten", ["a", "kitten"]),
                ("the old house", "old", "house", ["the", "house"]), ("a bright star", "bright", "star", ["a", "star"]),
            ]
        ]),
    ],
    5: [
        skill("en5.synonym", "Same meaning", "EN-5.04", "=", ["quickfire", "catch"], [
            it(f"{a}-{b}", f"Which word means the same as {a}?", [b] + other, f"{a.capitalize()} and {b} mean the same.")
            for a, b, other in [
                ("happy", "glad", ["sad", "angry", "tired"]), ("big", "large", ["tiny", "thin", "short"]), ("fast", "quick", ["slow", "late", "lazy"]),
                ("begin", "start", ["end", "stop", "close"]), ("small", "little", ["huge", "wide", "tall"]), ("shut", "close", ["open", "break", "push"]),
                ("smart", "clever", ["silly", "slow", "weak"]), ("angry", "cross", ["calm", "happy", "kind"]), ("gift", "present", ["price", "letter", "party"]),
                ("shout", "yell", ["whisper", "sing", "hum"]), ("scared", "afraid", ["brave", "bold", "proud"]), ("look", "see", ["hear", "taste", "smell"]),
            ]
        ]),
        skill("en5.punct", "Full stop or question mark", "EN-5.07", "?", ["quickfire"], [
            it(f"p{i}", f"Which mark ends this? \"{s}\"", [m] + [x for x in ["?", ".", "!"] if x != m], why)
            for i, (s, m, why) in enumerate([
                ("Where are you going", "?", "It asks something, so it ends with a question mark."),
                ("I like mangoes", ".", "It tells something, so it ends with a full stop."),
                ("What is your name", "?", "It asks something, so it ends with a question mark."),
                ("The sky is blue", ".", "It tells something, so it ends with a full stop."),
                ("How old are you", "?", "It asks something, so it ends with a question mark."),
                ("We play after school", ".", "It tells something, so it ends with a full stop."),
                ("Can you swim", "?", "It asks something, so it ends with a question mark."),
                ("My sister reads books", ".", "It tells something, so it ends with a full stop."),
                ("Wow, what a goal", "!", "It shows a strong feeling, so it ends with an exclamation mark."),
                ("Did you eat lunch", "?", "It asks something, so it ends with a question mark."),
                ("The train is late", ".", "It tells something, so it ends with a full stop."),
                ("Ouch, that hurts", "!", "It shows a strong feeling, so it ends with an exclamation mark."),
            ])
        ]),
    ],
    6: [
        skill("en6.prep", "Where things are", "EN-6.05", "in", ["quickfire", "catch"], [
            it(f"pr{i}", f"The {thing} is ___ the {place}. ({hint})", [right] + other, why)
            for i, (thing, place, hint, right, other, why) in enumerate([
                ("ball", "box", "inside it", "in", ["on", "under", "behind"], "Inside something means in."),
                ("cat", "table", "below it", "under", ["on", "in", "above"], "Below something means under."),
                ("book", "desk", "on top of it", "on", ["under", "in", "behind"], "On top of something means on."),
                ("boy", "tree", "at its back", "behind", ["in", "on", "under"], "At the back of something means behind."),
                ("bird", "house", "higher than it", "above", ["under", "in", "behind"], "Higher than something means above."),
                ("shop", "school", "close to it", "near", ["under", "in", "on"], "Close to something means near."),
                ("dog", "two chairs", "in the middle", "between", ["on", "under", "above"], "In the middle of two things means between."),
                ("car", "garage", "inside it", "in", ["on", "above", "behind"], "Inside something means in."),
                ("shoes", "bed", "below it", "under", ["on", "in", "above"], "Below something means under."),
                ("cup", "plate", "on top of it", "on", ["under", "in", "behind"], "On top of something means on."),
                ("girl", "door", "at its back", "behind", ["in", "on", "above"], "At the back of something means behind."),
                ("moon", "hills", "higher than them", "above", ["under", "in", "behind"], "Higher than something means above."),
            ])
        ]),
        skill("en6.pronoun", "Pronouns", "EN-6.06", "she", ["quickfire", "catch"], [
            it(f"pn{i}", f"{first} ___ {rest}.", [right] + other, why)
            for i, (first, rest, right, other, why) in enumerate([
                ("Riya is my friend.", "lives near me", "She", ["He", "It", "They"], "Riya is a girl, so we use she."),
                ("Arjun likes cricket.", "plays every day", "He", ["She", "It", "They"], "Arjun is a boy, so we use he."),
                ("The dog is hungry.", "wants food", "It", ["He", "She", "We"], "A dog is an animal, so we use it."),
                ("Meena and Ravi are here.", "are my cousins", "They", ["He", "She", "It"], "Two people means they."),
                ("My mother is a doctor.", "works at a hospital", "She", ["He", "It", "They"], "Mother is a woman, so we use she."),
                ("Grandpa tells stories.", "is very funny", "He", ["She", "It", "They"], "Grandpa is a man, so we use he."),
                ("The kite is in the sky.", "is very high", "It", ["He", "She", "They"], "A kite is a thing, so we use it."),
                ("Tom and I play chess.", "play after school", "We", ["They", "He", "It"], "Tom and I means we."),
                ("The birds sing at dawn.", "wake me up", "They", ["It", "He", "She"], "Many birds means they."),
                ("Aunt Lata makes ladoos.", "makes them for Diwali", "She", ["He", "It", "We"], "Aunt Lata is a woman, so we use she."),
                ("The bus is late.", "will come soon", "It", ["He", "She", "They"], "A bus is a thing, so we use it."),
                ("My brothers love football.", "play every evening", "They", ["He", "It", "She"], "Many brothers means they."),
            ])
        ]),
    ],
    7: [
        skill("en7.tense", "Now, then, later", "EN-7.04", "-ing", ["quickfire"], [
            it(f"t{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("She ___ a book now.", "is reading", ["read", "will read", "was reading"], "Now means it is happening: is reading."),
                ("Yesterday, we ___ a film.", "watched", ["watch", "will watch", "are watching"], "Yesterday means the past: watched."),
                ("Tomorrow, I ___ my aunt.", "will visit", ["visited", "visit", "am visiting"], "Tomorrow means later: will visit."),
                ("They ___ cricket right now.", "are playing", ["played", "will play", "play"], "Right now means it is happening: are playing."),
                ("Last week, he ___ a letter.", "wrote", ["writes", "will write", "is writing"], "Last week means the past: wrote."),
                ("Next year, we ___ to Goa.", "will go", ["went", "go", "are going"], "Next year means later: will go."),
                ("Look, the baby ___!", "is sleeping", ["slept", "will sleep", "sleep"], "Look means it is happening now: is sleeping."),
                ("Last night, it ___ heavily.", "rained", ["rains", "will rain", "is raining"], "Last night means the past: rained."),
                ("Soon, the train ___.", "will arrive", ["arrived", "arrives", "was arriving"], "Soon means later: will arrive."),
                ("Listen, the birds ___.", "are singing", ["sang", "will sing", "sing"], "Listen means it is happening now: are singing."),
                ("Two days ago, I ___ a cake.", "baked", ["bake", "will bake", "am baking"], "Two days ago means the past: baked."),
                ("This evening, Mom ___ dal.", "will cook", ["cooked", "cooks", "was cooking"], "This evening is later today: will cook."),
            ])
        ]),
        skill("en7.agree", "Is or are", "EN-7.06", "are", ["quickfire"], [
            it(f"a{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("The boys ___ playing.", "are", ["is", "am"], "Boys means many, so we use are."),
                ("My sister ___ singing.", "is", ["are", "am"], "Sister is one person, so we use is."),
                ("I ___ ready.", "am", ["is", "are"], "With I, we always use am."),
                ("The flowers ___ pretty.", "are", ["is", "am"], "Flowers means many, so we use are."),
                ("The sun ___ hot.", "is", ["are", "am"], "The sun is one thing, so we use is."),
                ("We ___ friends.", "are", ["is", "am"], "We means more than one, so we use are."),
                ("He ___ my teacher.", "is", ["are", "am"], "He is one person, so we use is."),
                ("The children ___ in the park.", "are", ["is", "am"], "Children means many, so we use are."),
                ("This mango ___ sweet.", "is", ["are", "am"], "One mango, so we use is."),
                ("You ___ kind.", "are", ["is", "am"], "With you, we always use are."),
                ("The dogs ___ barking.", "are", ["is", "am"], "Dogs means many, so we use are."),
                ("My bag ___ heavy.", "is", ["are", "am"], "One bag, so we use is."),
            ])
        ]),
    ],
}

# ── EVS (KG–5) and Science (6–7) ─────────────────────────────────────────

EVS = {
    0: [
        skill("ev0.animals", "Animals around us", "EV-0.01", "cow", ["quickfire"], [
            pic_q("fly", "Which one can fly?", "bird", ["cat", "cow", "fish"], "A bird has wings, so it can fly."),
            pic_q("swim", "Which one lives in water?", "fish", ["dog", "cat", "cow"], "A fish lives and swims in water."),
            pic_q("milk", "Which one gives us milk?", "cow", ["dog", "fish", "ant"], "We get milk from the cow."),
            pic_q("bark", "Which one says woof?", "dog", ["cat", "cow", "bird"], "A dog barks: woof woof."),
            pic_q("meow", "Which one says meow?", "cat", ["dog", "cow", "fish"], "A cat says meow."),
            pic_q("moo", "Which one says moo?", "cow", ["cat", "dog", "bird"], "A cow says moo."),
            pic_q("tiny", "Which one is very tiny?", "ant", ["cow", "dog", "cat"], "An ant is very tiny."),
            pic_q("egg", "Which one comes from a hen?", "egg", ["apple", "ball", "cup"], "A hen lays eggs."),
            pic_q("tweet", "Which one sings tweet tweet?", "bird", ["fish", "cow", "ant"], "A bird sings tweet tweet."),
            pic_q("fins", "Which one has fins?", "fish", ["bird", "cat", "dog"], "A fish has fins to swim."),
            pic_q("pet", "Which one guards the house?", "dog", ["fish", "ant", "bird"], "A dog guards the house."),
            pic_q("grass", "Which one eats grass?", "cow", ["cat", "fish", "bird"], "A cow eats grass."),
        ]),
        skill("ev0.body", "My body", "EV-0.02", "eye", ["quickfire"], [
            pic_q("see", "Which one do we see with?", "eye", ["ear", "nose", "hand"], "We see with our eyes."),
            pic_q("hear", "Which one do we hear with?", "ear", ["eye", "nose", "tooth"], "We hear with our ears."),
            pic_q("smell", "Which one do we smell with?", "nose", ["ear", "eye", "hand"], "We smell with our nose."),
            pic_q("hold", "Which one do we hold things with?", "hand", ["nose", "ear", "eye"], "We hold things with our hands."),
            pic_q("chew", "Which one helps us chew?", "tooth", ["ear", "eye", "nose"], "Our teeth help us chew food."),
            pic_q("brush", "Which one do we brush every day?", "tooth", ["hand", "ear", "eye"], "We brush our teeth every day."),
            pic_q("flower", "Which one smells a flower?", "nose", ["hand", "tooth", "ear"], "We smell flowers with our nose."),
            pic_q("music", "Which one hears music?", "ear", ["nose", "hand", "eye"], "We hear music with our ears."),
            pic_q("colours", "Which one sees colours?", "eye", ["ear", "tooth", "hand"], "Our eyes see colours."),
            pic_q("wave", "Which one do we wave with?", "hand", ["eye", "nose", "tooth"], "We wave with our hand."),
            pic_q("wash", "Which one do we wash before eating?", "hand", ["ear", "nose", "eye"], "We wash our hands before eating."),
            pic_q("blink", "Which one can blink?", "eye", ["ear", "nose", "tooth"], "Our eyes blink."),
        ]),
    ],
    1: [
        skill("ev1.fruits", "Fruits and vegetables", "EV-1.03", "apple", ["quickfire", "catch"], [
            it(f"f{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Which one is a fruit?", "mango", ["carrot", "potato", "onion"], "A mango is a sweet fruit."),
                ("Which one is a vegetable?", "carrot", ["apple", "banana", "grapes"], "A carrot is a vegetable that grows in soil."),
                ("Which fruit is yellow?", "banana", ["apple", "grapes", "plum"], "A ripe banana is yellow."),
                ("Which one grows under the soil?", "potato", ["mango", "apple", "banana"], "A potato grows under the soil."),
                ("Which fruit is red?", "apple", ["banana", "lemon", "pear"], "An apple can be red."),
                ("Which one is sour?", "lemon", ["mango", "banana", "apple"], "A lemon tastes sour."),
                ("Which vegetable makes us cry?", "onion", ["carrot", "pea", "corn"], "Cutting an onion can make our eyes water."),
                ("Which fruit has many seeds inside?", "melon", ["mango", "plum", "cherry"], "A melon has many seeds inside."),
                ("Which one is green?", "peas", ["carrot", "apple", "orange"], "Peas are small and green."),
                ("Which fruit do we peel?", "orange", ["grapes", "cherry", "plum"], "We peel an orange before eating."),
                ("Which one is the king of fruits?", "mango", ["carrot", "onion", "potato"], "The mango is called the king of fruits."),
                ("Which one is a leafy vegetable?", "spinach", ["apple", "mango", "banana"], "Spinach has big green leaves we eat."),
            ])
        ]),
        skill("ev1.senses", "Our senses", "EV-1.01", "ear", ["quickfire", "catch"], [
            it(f"s{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("We hear with our ___.", "ears", ["eyes", "nose", "hands"], "Our ears help us hear."),
                ("We see with our ___.", "eyes", ["ears", "tongue", "skin"], "Our eyes help us see."),
                ("We taste with our ___.", "tongue", ["nose", "ears", "eyes"], "Our tongue tells us the taste."),
                ("We smell with our ___.", "nose", ["tongue", "ears", "eyes"], "Our nose helps us smell."),
                ("We feel hot and cold with our ___.", "skin", ["ears", "nose", "teeth"], "Our skin feels hot and cold."),
                ("Sugar tastes ___.", "sweet", ["sour", "salty", "bitter"], "Sugar tastes sweet."),
                ("A lemon tastes ___.", "sour", ["sweet", "salty", "spicy"], "A lemon tastes sour."),
                ("A drum sounds ___.", "loud", ["soft", "sweet", "sour"], "A drum makes a loud sound."),
                ("Ice feels ___.", "cold", ["hot", "warm", "soft"], "Ice feels cold."),
                ("A pillow feels ___.", "soft", ["hard", "hot", "sharp"], "A pillow feels soft."),
                ("How many senses do we have?", "five", ["two", "three", "ten"], "We have five senses."),
                ("Salt tastes ___.", "salty", ["sweet", "sour", "bitter"], "Salt tastes salty."),
            ])
        ]),
    ],
    2: [
        skill("ev2.homes", "Animal homes", "EV-2.04", "bird", ["quickfire", "catch"], [
            it(f"h{i}", f"Where does a {a} live?", [home] + other, f"A {a} lives in a {home}.")
            for i, (a, home, other) in enumerate([
                ("bird", "nest", ["kennel", "hive", "stable"]), ("bee", "hive", ["nest", "den", "web"]),
                ("dog", "kennel", ["hive", "nest", "web"]), ("horse", "stable", ["nest", "hive", "burrow"]),
                ("spider", "web", ["stable", "kennel", "den"]), ("lion", "den", ["nest", "web", "hive"]),
                ("rabbit", "burrow", ["nest", "hive", "web"]), ("cow", "shed", ["nest", "web", "hive"]),
                ("fish", "pond", ["nest", "hive", "den"]), ("hen", "coop", ["web", "den", "hive"]),
                ("ant", "anthill", ["stable", "nest", "kennel"]), ("pig", "sty", ["hive", "web", "nest"]),
            ])
        ]),
        skill("ev2.plants", "Parts of a plant", "EV-2.02", "leaf", ["quickfire", "catch"], [
            it(f"p{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Which part is under the soil?", "roots", ["leaves", "flower", "fruit"], "Roots grow under the soil."),
                ("Which part makes food for the plant?", "leaves", ["roots", "stem", "seeds"], "Green leaves make food for the plant."),
                ("Which part holds the plant up?", "stem", ["leaves", "flower", "fruit"], "The stem holds the plant up."),
                ("Which part drinks water from the soil?", "roots", ["flower", "fruit", "leaves"], "Roots take in water from the soil."),
                ("What grows into a new plant?", "seed", ["leaf", "stem", "root"], "A seed grows into a new plant."),
                ("What colour are most leaves?", "green", ["blue", "black", "white"], "Most leaves are green."),
                ("Which part is often colourful and smells nice?", "flower", ["root", "stem", "seed"], "Flowers are colourful and smell nice."),
                ("A mango is which part of the tree?", "fruit", ["root", "leaf", "stem"], "A mango is the fruit of the mango tree."),
                ("A carrot is which part of the plant?", "root", ["leaf", "fruit", "flower"], "We eat the root of the carrot plant."),
                ("Spinach is which part of the plant?", "leaves", ["roots", "fruit", "seeds"], "We eat the leaves of spinach."),
                ("What does a plant need to grow?", "water", ["sugar", "salt", "milk"], "Plants need water to grow."),
                ("The trunk of a tree is its ___.", "stem", ["root", "leaf", "fruit"], "A tree trunk is a big, hard stem."),
            ])
        ]),
    ],
    3: [
        skill("ev3.water", "Water around us", "EV-3.05", "drop", ["quickfire", "catch"], [
            it(f"w{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Where does rain fall from?", "clouds", ["trees", "rivers", "hills"], "Rain falls from the clouds."),
                ("Water turns into ice when it is very ___.", "cold", ["hot", "dry", "windy"], "Very cold water freezes into ice."),
                ("Which of these needs water every day?", "plants", ["stones", "chairs", "toys"], "All plants need water to live."),
                ("We should not ___ water.", "waste", ["drink", "save", "boil"], "Water is precious, so we should not waste it."),
                ("Rivers flow into the ___.", "sea", ["sky", "forest", "desert"], "Rivers carry their water to the sea."),
                ("Boiling water makes ___.", "steam", ["ice", "sand", "smoke"], "Hot boiling water turns into steam."),
                ("Clean water to drink is ___ water.", "safe", ["dirty", "salty", "muddy"], "Clean water is safe to drink."),
                ("Sea water tastes ___.", "salty", ["sweet", "sour", "bitter"], "Sea water has salt in it."),
                ("What do we use to collect rain water?", "tank", ["basket", "net", "sieve"], "A tank can store rain water."),
                ("A dry place with little rain is a ___.", "desert", ["river", "lake", "sea"], "Deserts get very little rain."),
                ("Which animal lives in water?", "fish", ["camel", "goat", "lion"], "Fish live in water."),
                ("Turning off the tap ___ water.", "saves", ["wastes", "dirties", "heats"], "Closing the tap saves water."),
            ])
        ]),
        skill("ev3.food", "Food we eat", "EV-3.03", "carrot", ["quickfire", "catch"], [
            it(f"fd{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Which one comes from plants?", "rice", ["egg", "milk", "honey"], "Rice grows on rice plants."),
                ("Which one comes from animals?", "milk", ["rice", "wheat", "dal"], "We get milk from cows and buffaloes."),
                ("Bees give us ___.", "honey", ["milk", "eggs", "wool"], "Bees make honey."),
                ("Roti is made from ___.", "wheat", ["rice", "corn", "sugar"], "Roti is made from wheat flour."),
                ("Which food is a pulse?", "dal", ["rice", "bread", "milk"], "Dal is made from pulses."),
                ("We should wash fruits before ___.", "eating", ["buying", "growing", "selling"], "Washing removes dirt and germs before eating."),
                ("Too many sweets are bad for our ___.", "teeth", ["hair", "nails", "eyes"], "Too much sugar harms our teeth."),
                ("Which one is a healthy snack?", "fruit", ["chips", "candy", "cola"], "Fruit is a healthy snack."),
                ("Curd is made from ___.", "milk", ["water", "rice", "eggs"], "Curd is made from milk."),
                ("Which one gives us oil?", "mustard", ["rice", "milk", "tea"], "Mustard seeds give us oil."),
                ("Paneer is made from ___.", "milk", ["wheat", "rice", "dal"], "Paneer is made from milk."),
                ("Hens give us ___.", "eggs", ["milk", "honey", "wool"], "Hens lay eggs."),
            ])
        ]),
    ],
    4: [
        skill("ev4.travel", "Ways we travel", "EV-4.06", "bus", ["quickfire"], [
            it(f"tr{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Which one travels on water?", "boat", ["bus", "train", "car"], "A boat moves on water."),
                ("Which one flies in the sky?", "plane", ["ship", "bus", "cart"], "A plane flies in the sky."),
                ("Which one runs on rails?", "train", ["bus", "boat", "kite"], "A train runs on rails."),
                ("Which one needs no fuel?", "cycle", ["car", "bus", "plane"], "We pedal a cycle, so it needs no fuel."),
                ("A big boat that carries many people is a ___.", "ship", ["kite", "cart", "bike"], "A ship is a very big boat."),
                ("Which one is pulled by a bullock?", "cart", ["car", "train", "ship"], "A bullock cart is pulled by bullocks."),
                ("Where do planes land?", "airport", ["station", "port", "garage"], "Planes land at an airport."),
                ("Where do trains stop?", "station", ["airport", "port", "garden"], "Trains stop at a railway station."),
                ("Where do ships stop?", "port", ["station", "airport", "garage"], "Ships stop at a port."),
                ("Red traffic light means ___.", "stop", ["go", "run", "turn"], "Red means stop."),
                ("Green traffic light means ___.", "go", ["stop", "wait", "sit"], "Green means go."),
                ("We cross the road at the ___.", "zebra crossing", ["middle", "corner", "bridge"], "The zebra crossing is the safe place to cross."),
            ])
        ]),
        skill("ev4.animals", "Animal groups", "EV-4.03", "ant", ["quickfire", "catch"], [
            it(f"an{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Which animal lays eggs?", "hen", ["cow", "dog", "cat"], "A hen lays eggs."),
                ("Which animal gives birth to babies?", "cow", ["hen", "duck", "snake"], "A cow gives birth to calves."),
                ("Which animal eats only plants?", "goat", ["lion", "tiger", "wolf"], "A goat eats only plants."),
                ("Which animal eats other animals?", "lion", ["cow", "goat", "deer"], "A lion hunts other animals for food."),
                ("Which animal has feathers?", "parrot", ["cat", "fish", "frog"], "A parrot has feathers."),
                ("Which animal has scales?", "fish", ["dog", "hen", "cow"], "A fish has scales on its body."),
                ("Which animal can live on land and in water?", "frog", ["cat", "cow", "hen"], "A frog lives on land and in water."),
                ("Which one is an insect?", "ant", ["cat", "fish", "crow"], "An ant is an insect with six legs."),
                ("How many legs does an insect have?", "six", ["two", "four", "eight"], "Insects have six legs."),
                ("Which animal keeps awake at night?", "owl", ["hen", "cow", "crow"], "An owl is awake at night."),
                ("Which animal carries its home?", "snail", ["dog", "lion", "crow"], "A snail carries its shell on its back."),
                ("Which bird cannot fly?", "ostrich", ["crow", "parrot", "sparrow"], "An ostrich is a bird that cannot fly."),
            ])
        ]),
    ],
    5: [
        skill("ev5.states", "Solid, liquid, gas", "EV-5.06", "cup", ["quickfire"], [
            it(f"st{i}", f"{thing} is a ___.", [right] + [x for x in ["solid", "liquid", "gas"] if x != right], why)
            for i, (thing, right, why) in enumerate([
                ("Ice", "solid", "Ice keeps its shape, so it is a solid."),
                ("Water", "liquid", "Water flows and takes the shape of its pot."),
                ("Steam", "gas", "Steam spreads out into the air, so it is a gas."),
                ("A stone", "solid", "A stone keeps its shape, so it is a solid."),
                ("Milk", "liquid", "Milk flows and takes the shape of its glass."),
                ("Air", "gas", "Air spreads out everywhere, so it is a gas."),
                ("Juice", "liquid", "Juice flows and can be poured, so it is a liquid."),
                ("A wooden table", "solid", "A table keeps its shape, so it is a solid."),
                ("Oil", "liquid", "Oil flows and can be poured, so it is a liquid."),
                ("Smoke", "gas", "Smoke spreads out into the air, so it is a gas."),
                ("A coin", "solid", "A coin keeps its shape, so it is a solid."),
                ("The air in a balloon", "gas", "Air fills the whole balloon, so it is a gas."),
            ])
        ]),
        skill("ev5.seeds", "Seeds and growing", "EV-5.03", "seed", ["quickfire", "catch"], [
            it(f"sd{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("What does a seed need to sprout?", "water", ["sugar", "salt", "plastic"], "Seeds need water to sprout."),
                ("A baby plant coming out of a seed is a ___.", "sprout", ["root", "flower", "fruit"], "A tiny new plant from a seed is a sprout."),
                ("Which seeds do we eat as dal?", "lentils", ["mango", "apple", "neem"], "Dal is made from lentil seeds."),
                ("How are some seeds carried far away?", "wind", ["roots", "rocks", "soil"], "Light seeds fly away on the wind."),
                ("What do plants need to make food?", "sunlight", ["darkness", "sand", "smoke"], "Plants use sunlight to make food."),
                ("Which part of a mango is the seed?", "stone", ["skin", "pulp", "juice"], "The hard stone inside a mango is its seed."),
                ("Farmers sow seeds in the ___.", "field", ["river", "road", "sky"], "Farmers sow seeds in fields."),
                ("Which fruit has its seeds outside?", "strawberry", ["mango", "apple", "orange"], "A strawberry has tiny seeds on the outside."),
                ("Moong seeds kept in wet cloth will ___.", "sprout", ["melt", "burn", "break"], "Wet moong seeds sprout in a day or two."),
                ("A plant without sunlight turns ___.", "yellow", ["blue", "red", "black"], "Without sunlight, plants become pale and yellow."),
                ("Which one helps spread seeds?", "birds", ["stones", "chairs", "clouds"], "Birds eat fruit and drop the seeds."),
                ("A seed grows best in ___ soil.", "wet", ["dry", "burnt", "frozen"], "Seeds grow best in soil that is wet."),
            ])
        ]),
    ],
    6: [
        skill("sc6.living", "Living and non-living", "SC-6.09", "tree", ["quickfire", "catch"], [
            it(f"lv{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Which one is living?", "tree", ["rock", "chair", "pen"], "A tree grows and needs food, so it is living."),
                ("Which one is non-living?", "stone", ["dog", "plant", "bird"], "A stone does not grow or breathe."),
                ("All living things need ___.", "food", ["toys", "paint", "money"], "All living things need food to live."),
                ("Living things can ___.", "grow", ["melt", "shine", "rust"], "Living things grow over time."),
                ("Plants breathe through their ___.", "leaves", ["roots", "fruits", "seeds"], "Leaves have tiny pores for breathing."),
                ("Which one is living?", "mushroom", ["cloud", "river", "sand"], "A mushroom grows, so it is living."),
                ("Which one is non-living?", "car", ["cat", "tree", "fish"], "A car moves but does not grow."),
                ("A seed is ___.", "living", ["non-living", "a stone", "a toy"], "A seed is alive and can grow into a plant."),
                ("Living things make more of their own ___.", "kind", ["toys", "houses", "roads"], "Living things have young ones of their kind."),
                ("Which one responds to touch?", "touch-me-not", ["rock", "table", "pen"], "A touch-me-not plant closes its leaves when touched."),
                ("Which one needs air to live?", "fish", ["stone", "book", "chair"], "Fish take air from the water."),
                ("Which one is non-living?", "water", ["frog", "grass", "ant"], "Water is needed by living things but is not alive."),
            ])
        ]),
        skill("sc6.food", "Food and nutrients", "SC-6.02", "egg", ["quickfire", "catch"], [
            it(f"nu{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Rice and roti mostly give us ___.", "energy", ["bones", "teeth", "hair"], "Rice and roti are full of carbohydrates for energy."),
                ("Which nutrient helps our body grow?", "protein", ["sugar", "fat", "water"], "Protein builds and repairs our body."),
                ("Dal and eggs are rich in ___.", "protein", ["sugar", "fat", "salt"], "Dal and eggs have lots of protein."),
                ("Milk helps make our ___ strong.", "bones", ["hair", "nails", "eyes"], "Milk has calcium for strong bones."),
                ("Which fruit has lots of vitamin C?", "orange", ["bread", "rice", "butter"], "Oranges are rich in vitamin C."),
                ("Ghee and butter are rich in ___.", "fat", ["protein", "fibre", "water"], "Ghee and butter are mostly fat."),
                ("Fibre in food helps our ___.", "stomach", ["hair", "eyes", "ears"], "Fibre helps our stomach and digestion."),
                ("Eating many kinds of food is a ___ diet.", "balanced", ["sweet", "small", "fast"], "A balanced diet has all the nutrients we need."),
                ("Too little iron can make us ___.", "tired", ["taller", "faster", "louder"], "Iron carries oxygen in our blood."),
                ("Carrots are good for our ___.", "eyes", ["ears", "nails", "hair"], "Carrots have vitamin A for our eyes."),
                ("Which test shows starch in food?", "iodine", ["salt", "sugar", "oil"], "Iodine turns blue-black when starch is present."),
                ("We should drink plenty of ___.", "water", ["cola", "syrup", "oil"], "Our body needs lots of water."),
            ])
        ]),
    ],
    7: [
        skill("sc7.plants", "How plants make food", "SC-7.01", "leaf", ["quickfire"], [
            it(f"ps{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Plants make food using ___.", "sunlight", ["moonlight", "smoke", "sand"], "Plants use sunlight to make their food."),
                ("The green colour in leaves is ___.", "chlorophyll", ["starch", "sugar", "oxygen"], "Chlorophyll makes leaves green and traps sunlight."),
                ("Plants take in which gas to make food?", "carbon dioxide", ["oxygen", "helium", "smoke"], "Plants take in carbon dioxide from the air."),
                ("Plants give out which gas?", "oxygen", ["carbon dioxide", "steam", "smoke"], "Plants give out oxygen that we breathe."),
                ("Leaves store food as ___.", "starch", ["salt", "oil", "sand"], "Plants store their food as starch."),
                ("Water reaches the leaves through the ___.", "stem", ["flower", "fruit", "seed"], "The stem carries water up from the roots."),
                ("Tiny pores on leaves are ___.", "stomata", ["roots", "petals", "seeds"], "Stomata are tiny pores that let gases in and out."),
                ("Making food with sunlight is called ___.", "photosynthesis", ["digestion", "breathing", "melting"], "Photosynthesis means making food using light."),
                ("Which plant eats insects?", "pitcher plant", ["mango tree", "rose", "grass"], "A pitcher plant traps and eats insects."),
                ("Cuscuta takes food from other plants. It is a ___.", "parasite", ["seed", "fruit", "root"], "A parasite lives on another plant for food."),
                ("Fungi like mushrooms get food from ___.", "dead matter", ["sunlight", "rocks", "air"], "Mushrooms feed on dead and rotting things."),
                ("Which part of the plant makes most food?", "leaves", ["roots", "stem", "flower"], "Leaves are the plant's food factories."),
            ])
        ]),
        skill("sc7.heat", "Heat", "SC-7.04", "fire", ["quickfire"], [
            it(f"ht{i}", q, [right] + other, why)
            for i, (q, right, other, why) in enumerate([
                ("Which one lets heat pass easily?", "iron", ["wood", "plastic", "cloth"], "Metals like iron let heat pass through quickly."),
                ("Which one is a poor conductor of heat?", "wood", ["iron", "copper", "steel"], "Wood does not let heat pass easily."),
                ("We measure temperature with a ___.", "thermometer", ["ruler", "scale", "clock"], "A thermometer measures how hot or cold something is."),
                ("Normal body temperature is about ___.", "37 °C", ["10 °C", "60 °C", "100 °C"], "Our body is usually about 37 degrees Celsius."),
                ("Heat from the sun reaches us by ___.", "radiation", ["conduction", "water", "wires"], "Sunlight's heat travels to us by radiation."),
                ("Warm air ___.", "rises", ["sinks", "freezes", "stops"], "Warm air is lighter, so it rises."),
                ("In summer, we wear ___ clothes.", "light", ["dark", "woollen", "thick"], "Light colours and thin cloth keep us cool."),
                ("Woollen clothes keep us warm by trapping ___.", "air", ["water", "light", "dust"], "Wool traps air, which keeps the heat in."),
                ("A pan handle is made of plastic because plastic is a ___.", "poor conductor", ["good conductor", "metal", "liquid"], "Plastic stops the heat reaching our hand."),
                ("Heat moves from a ___ object to a cooler one.", "hotter", ["colder", "heavier", "smaller"], "Heat always flows from hot to cold."),
                ("A sea breeze blows from sea to land in the ___.", "day", ["night", "winter", "rain"], "In the day, land heats faster, so air moves in."),
                ("Ice melts when we ___ it.", "heat", ["cool", "freeze", "shake"], "Heating ice turns it into water."),
            ])
        ]),
    ],
}

GRADE_FILE = {0: "kg", **{g: str(g) for g in range(1, 8)}}


def merge_extra():
    from more import EXTRA
    known = set()
    for by_grade in (ENGLISH, EVS):
        for skills in by_grade.values():
            for s in skills:
                known.add(s["id"])
                for item in EXTRA.get(s["id"], []):
                    if all(item["id"] != o["id"] for o in s["items"]):
                        s["items"].append(item)
    unknown = set(EXTRA) - known
    assert not unknown, f"EXTRA names unknown skills: {unknown}"


def write_packs():
    merge_extra()
    reviewed = json.load(open(REVIEWED)) if os.path.exists(REVIEWED) else {}
    written = []
    for subject, by_grade in (("english", ENGLISH), ("evs", EVS)):
        os.makedirs(os.path.join(ASSETS, subject), exist_ok=True)
        for grade, skills in sorted(by_grade.items()):
            pid = f"{subject}-{GRADE_FILE[grade]}"
            pack = dict(id=pid, subject=subject, grade=grade, version=1,
                        reviewed=reviewed.get(pid, {"by": "", "at": ""}), skills=skills)
            path = os.path.join(ASSETS, subject, f"{GRADE_FILE[grade]}.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(pack, f, ensure_ascii=False, indent=1)
            written.append(pack)
    return written


def write_review(packs):
    os.makedirs(REVIEW, exist_ok=True)
    esc = html.escape
    rows = []
    for p in packs:
        n = sum(len(s["items"]) for s in p["skills"])
        status = "Reviewed by " + esc(p["reviewed"]["by"]) if p["reviewed"]["by"] else "Not reviewed yet"
        rows.append(f'<h2 id="{p["id"]}">{esc(p["id"])} · {n} questions · <span class="s">{status}</span></h2>')
        for s in p["skills"]:
            rows.append(f'<h3>{esc(s["title"])} <span class="m">{esc(s["id"])} · {esc(s["outcome"])} · {", ".join(s["formats"])}</span></h3><ol>')
            for i in s["items"]:
                right = i["options"][0]
                wrong = ", ".join(esc(o) for o in i["options"][1:])
                pic = f' <span class="m">[picture: {esc(i["picture"])}]</span>' if i.get("picture") else ""
                rows.append(f'<li><b>{esc(i["q"])}</b>{pic}<br>✓ <span class="ok">{esc(right)}</span> · ✗ {wrong}<br><i>{esc(i["explain"])}</i></li>')
            rows.append("</ol>")
    page = f"""<!doctype html><meta charset="utf-8"><title>Tubby's Town question review</title>
<style>body{{font:16px/1.5 system-ui,sans-serif;max-width:860px;margin:2rem auto;padding:0 1rem;color:#1C1D3A;background:#FFF8F1}}
h2{{margin-top:2.5rem;border-top:1px solid #EADFD1;padding-top:1rem}}.m{{color:#5B5C78;font-weight:400;font-size:.85em}}
.ok{{color:#0E7C5B;font-weight:600}}.s{{color:#8A5A00;font-weight:400}}li{{margin:.6rem 0}}</style>
<h1>Tubby's Town: questions to review</h1>
<p>Each question shows the right answer (✓), the wrong options (✗) and the one-line why. Tell Claude which packs look right; only reviewed packs reach the TV.</p>
{''.join(rows)}"""
    with open(os.path.join(REVIEW, "index.html"), "w", encoding="utf-8") as f:
        f.write(page)


if __name__ == "__main__":
    packs = write_packs()
    write_review(packs)
    total = sum(len(s["items"]) for p in packs for s in p["skills"])
    print(f"{len(packs)} packs, {sum(len(p['skills']) for p in packs)} skills, {total} questions")
