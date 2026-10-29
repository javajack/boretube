"""Curated English tables, KG to Class 3 (see english_data.py for the JSON shape)."""

GIRLS = "Riya Meera Ananya Diya Isha Zoya Tara Anika Sara Priya".split()
BOYS = "Aarav Kabir Arjun Rohan Ishaan Dev Vivaan Sameer Kunal Rahul".split()

# KG colours: (thing, colour). Only things with one clear colour.
COLOUR_THINGS = [
    ("a crow", "black"), ("coal", "black"), ("milk", "white"), ("snow", "white"), ("salt", "white"),
    ("cotton", "white"), ("grass", "green"), ("a parrot", "green"), ("a leaf", "green"), ("peas", "green"),
    ("the sky", "blue"), ("a ripe banana", "yellow"), ("turmeric", "yellow"), ("a sunflower", "yellow"),
    ("a ripe tomato", "red"), ("blood", "red"), ("a strawberry", "red"), ("a fire engine", "red"),
    ("an orange", "orange"), ("an elephant", "grey"), ("chocolate", "brown"), ("a tree trunk", "brown"),
    ("a flamingo", "pink"), ("an egg yolk", "yellow"), ("a lime", "green"),
    ("a polar bear", "white"), ("a coconut shell", "brown"), ("a cucumber", "green"), ("ash", "grey"),
    ("a duck's beak", "orange"), ("a cloud on a sunny day", "white"), ("a chick", "yellow"),
    ("a ripe chilli", "red"), ("a frog", "green"), ("a donkey", "grey"), ("tea leaves", "green"),
    ("a lemon", "yellow"), ("charcoal", "black"), ("a rose petal", "pink"),
]
COLOUR_MIX = [("red", "yellow", "orange"), ("blue", "yellow", "green"), ("red", "white", "pink"),
              ("black", "white", "grey"), ("red", "blue", "purple")]

# KG opposites: (a, b, two_way). one-way pairs only ask "opposite of a".
OPP_KG = [
    ("big", "small", 1), ("hot", "cold", 1), ("up", "down", 1), ("in", "out", 1), ("day", "night", 1),
    ("happy", "sad", 1), ("fast", "slow", 1), ("open", "shut", 1), ("tall", "short", 0), ("long", "short", 0),
    ("wet", "dry", 1), ("full", "empty", 1), ("new", "old", 0), ("young", "old", 0), ("clean", "dirty", 1),
    ("soft", "hard", 0), ("heavy", "light", 0), ("push", "pull", 1), ("give", "take", 1), ("come", "go", 1),
    ("yes", "no", 1), ("top", "bottom", 1), ("front", "back", 0), ("inside", "outside", 1),
    ("laugh", "cry", 1), ("near", "far", 1), ("high", "low", 1), ("thick", "thin", 0), ("fat", "thin", 0),
    ("rich", "poor", 1), ("good", "bad", 1), ("first", "last", 1), ("early", "late", 1), ("loud", "quiet", 0),
    ("awake", "asleep", 1), ("on", "off", 1), ("win", "lose", 1), ("before", "after", 1), ("above", "below", 1),
    ("sweet", "sour", 0), ("left", "right", 0), ("boy", "girl", 1), ("king", "queen", 1), ("sit", "stand", 1),
]

# Dolch pre-primer + primer (KG) and first + second grade (Class 1).
SIGHT_KG = ("a and away big blue can come down find for funny go help here I in is it jump little look make "
            "me my not one play red run said see the three to two up we where yellow you all am are at ate be "
            "black brown but came did do eat four get good have he into like must new no now on our out "
            "please pretty ran ride saw say she so soon that there they this too under want was well went "
            "what white who will with yes").split()
SIGHT_1 = ("after again an any as ask by could every fly from give going had has her him his how just know "
           "let live may of old once open over put round some stop take thank them then think walk were when "
           "always around because been before best both buy call cold does don't fast first five found gave "
           "goes green its made many off or pull read right sing sit sleep tell their these those upon us use "
           "very wash which why wish work would write your").split()

# KG actions: (frame, answer, other verbs that also fit).
ACTION_FRAMES = [
    ("We ___ a book.", "read", ""), ("We ___ milk.", "drink", ""), ("We ___ a song.", "sing", ""),
    ("We ___ a kite.", "fly", ""), ("We ___ a bicycle.", "ride", ""), ("We ___ a mango.", "eat", ""),
    ("We ___ a shirt.", "wear", ""), ("We ___ our teeth.", "brush", "clean"), ("We ___ our hair.", "comb", "brush wash"),
    ("We ___ our hands.", "wash", "clap clean"), ("We ___ a letter.", "write", "read"), ("We ___ a ball.", "kick", "throw catch"),
    ("We ___ the door.", "open", "shut"), ("We ___ a picture.", "draw", "paint"), ("We ___ water.", "drink", ""),
    ("We ___ a tree.", "climb", "plant"), ("We ___ the bell.", "ring", ""), ("We ___ a seed.", "plant", "sow"),
    ("We ___ rice.", "eat", "cook"), ("We ___ a cap.", "wear", ""), ("We ___ the floor.", "sweep", "clean wash"),
    ("We ___ a horse.", "ride", ""), ("We ___ with our eyes.", "see", "look"), ("We ___ with our ears.", "hear", "listen"),
    ("We ___ with our nose.", "smell", ""), ("We ___ a story.", "read", "tell"), ("We ___ juice.", "drink", ""),
    ("We ___ a boat.", "row", "sail"), ("We ___ a roti.", "eat", "make"), ("We ___ shoes.", "wear", ""),
    ("We ___ in a pool.", "swim", ""), ("We ___ on a bed.", "sleep", "sit"), ("We ___ a gift.", "give", "open"),
    ("We ___ a cake.", "bake", "eat cut"), ("We ___ the drum.", "beat", ""), ("We ___ a flute.", "play", ""),
    ("We ___ a ladder.", "climb", ""), ("We ___ a swing.", "swing", "ride"), ("We ___ an idli.", "eat", "make"),
    ("We ___ a coat.", "wear", ""), ("We ___ a newspaper.", "read", ""), ("We ___ tea.", "drink", "make"),
]
ACTION_VERBS = "read drink sing fly ride eat wear brush comb wash write kick open draw climb ring plant sweep " \
               "see hear smell row sleep give bake beat play swim".split()
CAN_DO = {
    "eat": "mango rice roti banana idli apple cake biscuit dosa grapes ladoo samosa",
    "drink": "milk water juice tea lassi coconut water",
    "wear": "shirt cap frock shoes socks sari kurta coat sweater scarf",
    "read": "book newspaper letter comic",
    "ride": "bicycle horse scooter camel",
}

# Rhyme / word families (onset is the word minus the rime).
FAMILIES = {
    "at": "cat hat mat bat rat sat fat", "an": "pan can fan man van ran", "ig": "pig dig big wig fig",
    "op": "hop top mop pop shop stop", "en": "hen pen ten men", "ug": "bug hug jug mug rug",
    "ed": "bed red fed", "et": "jet net wet pet vet get", "in": "pin tin bin win fin chin",
    "ot": "pot hot dot cot not", "un": "sun fun run bun", "ip": "lip hip dip ship zip tip",
    "ake": "cake lake make bake rake take", "all": "ball tall wall call fall", "ay": "day play say may way pay",
    "ing": "ring king sing wing", "ap": "cap map tap nap", "ell": "bell well tell shell",
    "ock": "sock rock lock clock", "ill": "hill mill pill fill", "ail": "tail nail mail sail rail",
    "oat": "boat coat goat", "ar": "car star far jar", "ee": "bee see tree three",
    "ight": "night light right fight", "ack": "back sack pack black",
}
# Family pairs for the Class 1 sort.
FAMILY_PAIRS = [("at", "an"), ("ig", "ip"), ("op", "ot"), ("en", "et"), ("ug", "un"), ("ill", "ell"),
                ("ake", "ail"), ("ap", "at"), ("in", "ip"), ("ock", "ack")]

# KG sequences: four steps each, strictly in order.
SEQ_KG = [
    ["Wake up.", "Brush your teeth.", "Eat breakfast.", "Go to school."],
    ["Dig a hole.", "Put in a seed.", "Water it.", "A plant grows."],
    ["Peel the banana.", "Take a bite.", "Chew it.", "Throw the peel away."],
    ["Open the tap.", "Wet your hands.", "Rub on soap.", "Dry your hands."],
    ["Fill the bucket.", "Pour water on the plant.", "The plant drinks.", "The plant grows tall."],
    ["The hen lays an egg.", "The egg cracks.", "A chick comes out.", "The chick grows big."],
    ["Put on your socks.", "Put on your shoes.", "Tie the laces.", "Go out to play."],
    ["Get into bed.", "Close your eyes.", "Fall asleep.", "Wake up in the morning."],
    ["Take out a book.", "Open the book.", "Read the story.", "Close the book."],
    ["Get the paper.", "Draw a sun.", "Colour it yellow.", "Show it to Mum."],
    ["Clouds come.", "It starts to rain.", "The rain stops.", "A rainbow comes out."],
    ["Mix the flour and water.", "Roll the dough.", "Cook it on the tawa.", "Eat the hot roti."],
    ["Blow up the balloon.", "Tie a knot.", "Play with it.", "It bursts with a pop."],
    ["Stand in a line.", "Get on the bus.", "Ride to the zoo.", "See the animals."],
    ["Pick up the brush.", "Put on toothpaste.", "Brush your teeth.", "Rinse your mouth."],
    ["The caterpillar eats.", "It makes a cocoon.", "It sleeps inside.", "A butterfly comes out."],
    ["Take a glass.", "Pour the milk.", "Drink the milk.", "Wash the glass."],
    ["Put on your cap.", "Walk to the park.", "Play on the swing.", "Walk back home."],
    ["Wrap the gift.", "Give it to Riya.", "Riya opens it.", "Riya says thank you."],
    ["Make a snowball.", "Make a bigger ball.", "Put one on top.", "Add eyes and a nose."],
    ["Cut the paper.", "Fold it in half.", "Draw a card.", "Give the card away."],
    ["The bell rings.", "Pack your bag.", "Walk out of class.", "Go home."],
    ["Sow the seed.", "A shoot comes up.", "Leaves grow.", "A flower blooms."],
    ["Fill the pot with water.", "Put it on the stove.", "The water gets hot.", "The water boils."],
    ["Pick a mango.", "Wash the mango.", "Cut the mango.", "Eat the mango."],
    ["Run to the sea.", "Build a sand castle.", "A wave comes.", "The castle falls down."],
    ["Open the box.", "Take out the toys.", "Play with the toys.", "Put the toys back."],
    ["Take a bath.", "Dry with a towel.", "Put on clean clothes.", "Comb your hair."],
    ["Get on the swing.", "Push with your feet.", "Go up high.", "Slow down and stop."],
    ["The sun comes up.", "We eat lunch.", "The sun goes down.", "The moon comes out."],
]

# Class 1: CVC words for the missing letter skill.
CVC = ("cat hat mat bat rat sat fan pan van man can map cap tap bag rag jam ham dad pad bad sad "
       "hen pen ten net wet jet pet bed red leg peg web yes men vet "
       "pig wig dig fig big pin tin bin fin win sit kit lip hip dip zip six mix fix lid "
       "dog log hog fog cot pot hot dot box fox mop top hop rod job "
       "bug hug jug mug rug bus sun bun run fun cup pup tub cub nut hut cut gum mud").split()

DIGRAPHS = {
    "sh": "ship shop shell sheep shoe fish dish wish brush bush shirt shark shut push cash shine",
    "ch": "chin chip chair cheese chick church rich much lunch bench peach watch catch chalk teach chop",
    "th": "thin thick three thumb bath path moth teeth mouth tooth cloth both earth throw",
    "ck": "duck sock lock rock clock sick neck back pack kick black truck stick brick chick",
    "wh": "whale wheel white when what where which while whip whisper",
}

# Class 1: short sentences for capitals and full stops (<= 22 chars each).
CAP_PRED = ["has a red kite", "is at school", "can swim", "likes mangoes", "sat on a mat", "has a pet dog",
            "is my friend", "can sing", "ate a banana", "is very happy", "has a blue bag", "can run fast",
            "likes to draw", "drank some milk", "is in the park", "has a new cap", "fed the cat",
            "went to the mela", "has two pens", "is not well", "can read", "sat on the bus",
            "likes rain", "made a card", "has a big ball", "lost a shoe"]
CAP_I = ["I like my mum.", "I can jump.", "I am six.", "I have a cat.", "I see a bird.", "I am happy.",
         "I like rice.", "I can draw.", "I am at home.", "I have a kite.", "I like rain.", "I can hop.",
         "My dad and I sing.", "I play with Tara.", "I met Kabir.", "I can see Dev."]
CAP_NAME = ["I met {n} today.", "We saw {n}.", "This is {n}.", "I like {n}.", "Let us call {n}.",
            "Give it to {n}.", "We played with {n}."]

# Class 1: days and months.
DAYS = "Monday Tuesday Wednesday Thursday Friday Saturday Sunday".split()
MONTHS = "January February March April May June July August September October November December".split()

# Class 2: magic e pairs, with optional frames for each word.
MAGIC_E = [
    ("cap", "cape", "A king wears a long ___.", "Kabir wears a blue ___ on his head."),
    ("tap", "tape", "Stick the paper with ___.", "Turn off the ___ to save water."),
    ("pin", "pine", "A ___ tree grows on hills.", "Use a ___ to hold the papers."),
    ("kit", "kite", "Riya flies a ___.", "The doctor opened her first-aid ___."),
    ("hop", "hope", "I ___ you get well soon.", "Frogs ___ from rock to rock."),
    ("cub", "cube", "An ice ___ melts fast.", "A lion ___ plays with its mother."),
    ("not", "note", "Write a ___ to your friend.", "I am ___ sleepy."),
    ("can", "cane", "Grandpa walks with a ___.", "I ___ swim well."),
    ("mad", "made", "Mum ___ hot rotis.", ""), ("rat", "rate", "", "A ___ ran into the hole."),
    ("hat", "hate", "I ___ cold food.", "He wears a straw ___ in the sun."),
    ("bit", "bite", "Do not ___ your nails.", "Can I have a ___ of the cake?"),
    ("rid", "ride", "Let us ___ a bicycle.", ""), ("rip", "ripe", "The mango is ___ and sweet.", "Do not ___ the page."),
    ("tub", "tube", "Squeeze the ___ of toothpaste.", "The baby sits in a ___ of water."),
    ("cut", "cute", "The puppy is so ___.", "Please ___ the cake."),
    ("rob", "robe", "", ""), ("rod", "rode", "Riya ___ her bicycle to school.", "He holds a fishing ___."),
    ("cod", "code", "Type the secret ___.", ""), ("fin", "fine", "I am ___, thank you.", "A fish swims with its ___."),
    ("dim", "dime", "", ""), ("mop", "mope", "Use a ___ to clean the floor.", ""),
    ("pal", "pale", "She looks ___ and ill.", ""), ("van", "vane", "", "We went in a ___."),
    ("plan", "plane", "The ___ flies high.", "Let us make a ___."),
    ("slid", "slide", "Children go down the ___.", ""), ("spin", "spine", "", "Watch the top ___."),
    ("twin", "twine", "", "Aarav has a ___ sister."), ("glob", "globe", "Find India on the ___.", ""),
    ("star", "stare", "Do not ___ at people.", "A ___ twinkles at night."),
    ("hid", "hide", "Let us play ___ and seek.", "The cat ___ under the bed."),
    ("man", "mane", "A lion has a thick ___.", "The old ___ sat on a bench."),
    ("tim", "time", "", ""), ("not", "note", "", ""), ("us", "use", "Please ___ a pencil.", ""),
    ("at", "ate", "Kabir ___ two idlis.", ""), ("fat", "fate", "", ""), ("bath", "bathe", "", ""),
    ("pet", "pete", "", ""), ("cop", "cope", "", ""), ("dot", "dote", "", ""), ("fir", "fire", "", ""),
    ("shin", "shine", "The sun will ___ today.", ""), ("strip", "stripe", "A zebra has many a ___.", ""),
    ("gap", "gape", "", ""), ("wag", "wage", "", "Dogs ___ their tails."), ("sit", "site", "", "Please ___ down."),
]

# Class 2: pronouns. (noun phrase, subject pronoun, kind) kind: f, m, it, pl
PRON_NP = [
    ("My mother", "she", "f"), ("My aunt", "she", "f"), ("My sister", "she", "f"), ("Grandma", "she", "f"),
    ("The queen", "she", "f"), ("The girl", "she", "f"), ("Riya", "she", "f"), ("Meera", "she", "f"),
    ("My father", "he", "m"), ("My uncle", "he", "m"), ("My brother", "he", "m"), ("Grandpa", "he", "m"),
    ("The king", "he", "m"), ("The boy", "he", "m"), ("Kabir", "he", "m"), ("Aarav", "he", "m"),
    ("My friends", "they", "pl"), ("The children", "they", "pl"), ("Riya and Kabir", "they", "pl"),
    ("My cousins", "they", "pl"), ("The players", "they", "pl"), ("The twins", "they", "pl"),
]
PRON_THING = [("The kite", "it"), ("The bus", "it"), ("The tree", "it"), ("The box", "it"), ("The clock", "it"),
              ("The ball", "it"), ("The cake", "it"), ("The bag", "it"), ("The mangoes", "they"),
              ("The shoes", "they"), ("The books", "they"), ("The balloons", "they")]
PRON_PERSON_FRAMES_SG = ["___ is very kind.", "___ went to the market.", "___ made tea for us.", "___ sang a song.",
                         "___ likes to read.", "___ is at home today.", "___ can swim well.", "___ helped me."]
PRON_PERSON_FRAMES_PL = ["___ are very kind.", "___ went to the market.", "___ made tea for us.", "___ sang a song.",
                         "___ like to read.", "___ are at home today.", "___ can swim well.", "___ helped me."]
PRON_THING_FRAMES_SG = ["___ is new.", "___ is on the floor.", "___ fell down.", "___ is very big."]
PRON_THING_FRAMES_PL = ["___ are new.", "___ are on the floor.", "___ fell down.", "___ are very big."]
PRON_OBJ_FRAMES = ["I gave ___ a pen.", "We met ___ at the mela.", "I called ___ today.", "Please help ___.",
                   "We waved to ___."]

# Class 2: be verbs. Subjects: (text, kind) kind: I, you, 3s, pl
BE_SUBJ = [("I", "I"), ("You", "you"), ("We", "pl"), ("They", "pl"), ("He", "3s"), ("She", "3s"),
           ("Riya", "3s"), ("Kabir", "3s"), ("My mother", "3s"), ("The teacher", "3s"), ("The baby", "3s"),
           ("The children", "pl"), ("My friends", "pl"), ("Riya and Kabir", "pl"), ("The boys", "pl"),
           ("The girls", "pl"), ("Grandpa", "3s"), ("My sister", "3s"), ("The players", "pl"),
           ("My parents", "pl")]
BE_THING = [("The mango", "3s", "sweet ripe yellow big juicy"), ("The mangoes", "pl", "sweet ripe yellow big juicy"),
            ("The sky", "3s", "blue clear grey"), ("The box", "3s", "heavy empty big small"),
            ("The boxes", "pl", "heavy empty big small"), ("The tea", "3s", "hot sweet ready"),
            ("The flowers", "pl", "red pretty fresh"), ("The flower", "3s", "red pretty fresh"),
            ("The bus", "3s", "late full new"), ("The buses", "pl", "late full new"),
            ("The road", "3s", "wet long busy"), ("The shoes", "pl", "new dirty wet"),
            ("The cat", "3s", "hungry asleep black"), ("The cats", "pl", "hungry asleep black"),
            ("This book", "3s", "funny new old"), ("These books", "pl", "funny new old")]
BE_PEOPLE_COMP = "happy at school in the garden tired ready late hungry at home sleepy busy in the park kind " \
                 "on the bus".split(" ")
BE_PEOPLE_COMP = ["happy", "at school", "in the garden", "tired", "ready", "late", "hungry", "at home",
                  "sleepy", "busy", "in the park", "kind", "on the bus"]

# Class 2: question words. (frame, answer, wrong choices) with {slots}.
QW_FRAMES = [
    ("___ is at the door? It is {person}.", "Who", "Where When How"),
    ("___ made this cake? {Person} did.", "Who", "Where When What"),
    ("___ is your best friend? It is {name}.", "Who", "Where When How"),
    ("___ is in the box? A {thing}.", "What", "Who Where When"),
    ("___ is your name? My name is {name}.", "What", "Who Where When"),
    ("___ did you buy? I bought a {thing}.", "What", "Who Where When"),
    ("___ is the cat? It is {place}.", "Where", "Who When What"),
    ("___ do you live? I live in {town}.", "Where", "Who When What"),
    ("___ is the mela? It is on {day}.", "When", "Who What Where"),
    ("___ is your birthday? It is in {month}.", "When", "Who What Where"),
    ("___ did you come? By {transport}.", "How", "Who What When"),
    ("___ are you? I am fine.", "How", "Who When Where"),
    ("___ old is {name}? Seven years old.", "How", "Who When Where"),
    ("___ are you crying? Because I am hurt.", "Why", "Who Where What"),
    ("___ is {name} sad? Because the kite tore.", "Why", "Who Where What"),
    ("___ is {name} happy? Because it is a holiday.", "Why", "Who Where What"),
    ("___ colour is the sky? It is blue.", "What", "Who Where When"),
    ("___ pen is this? It is {name}'s pen.", "Whose", "Who Where When"),
    ("___ bag is red? It is {name}'s bag.", "Whose", "Who Where When"),
    ("___ one do you want, the red or the blue?", "Which", "Who Where When"),
    ("___ many mangoes are there? Five.", "How", "Who What Where"),
]
QW_SLOTS = {
    "person": ["my uncle", "the postman", "Grandma", "my friend", "the milkman", "our neighbour", "my aunt"],
    "thing": ["pen", "ball", "doll", "cake", "kite", "toy car", "book", "watch"],
    "place": ["under the bed", "on the roof", "in the box", "near the door", "on the sofa", "in the garden"],
    "town": ["Delhi", "Pune", "Jaipur", "Chennai", "Kochi", "Patna", "Shillong", "a village"],
    "day": ["Monday", "Tuesday", "Friday", "Saturday", "Sunday"],
    "month": ["May", "June", "July", "March", "October", "December"],
    "transport": ["bus", "train", "auto", "car", "boat", "bicycle"],
}

# Class 2: compound words (first, second).
COMPOUNDS = [
    ("sun", "flower"), ("rain", "bow"), ("butter", "fly"), ("foot", "ball"), ("tooth", "brush"),
    ("class", "room"), ("bed", "room"), ("black", "board"), ("news", "paper"), ("pan", "cake"),
    ("cup", "board"), ("fire", "fly"), ("sea", "shell"), ("star", "fish"), ("snow", "man"),
    ("birth", "day"), ("home", "work"), ("play", "ground"), ("air", "port"), ("grand", "mother"),
    ("sun", "rise"), ("sun", "set"), ("rain", "coat"), ("door", "bell"), ("gold", "fish"),
    ("honey", "bee"), ("hand", "bag"), ("pop", "corn"), ("water", "melon"), ("foot", "path"),
    ("eye", "brow"), ("week", "end"), ("note", "book"), ("text", "book"), ("tea", "pot"),
    ("egg", "shell"), ("lady", "bird"), ("moon", "light"), ("sun", "light"), ("bath", "room"),
    ("wheel", "chair"), ("sand", "castle"), ("ear", "ring"), ("tooth", "paste"), ("out", "side"),
    ("in", "side"), ("some", "thing"), ("every", "one"), ("grand", "father"), ("rain", "drop"),
    ("snow", "flake"), ("hair", "brush"), ("book", "shelf"), ("pine", "apple"), 
    ("head", "light"), ("rail", "way"), ("sea", "side"), ("bird", "cage"),
    ("fish", "bowl"), ("milk", "man"), ("hill", "top"), ("finger", "nail"), ("arm", "chair"),
    ("tooth", "pick"), ("sun", "shine"), ("day", "time"), ("night", "time"), ("lunch", "box"),
]
NOT_COMPOUND = "apple tiger pencil rabbit doctor monkey water yellow sister paper finger mother table " \
               "garden window letter lemon flower river candle basket button parrot tomato potato teacher " \
               "orange happy little camel zebra market cherry carrot spider".split()

# Class 2: easy synonyms (groups) and opposites (pairs), with levels.
SYN_EASY = [("big", "large", 2), ("small", "little", 2), ("happy", "glad", 2), ("begin", "start", 2),
            ("shut", "close", 2), ("quick", "fast", 2), ("sick", "ill", 2), ("end", "finish", 2),
            ("gift", "present", 2), ("rock", "stone", 2), ("shout", "yell", 2), ("sad", "unhappy", 2),
            ("rich", "wealthy", 4), ("jump", "leap", 3),
            ("mum", "mother", 1), ("dad", "father", 1), ("kind", "nice", 2), ("pretty", "lovely", 2),
            ("tiny", "small", 2), ("huge", "big", 2), ("cry", "weep", 3), ("smile", "grin", 3),
            ("street", "road", 2), ("buy", "purchase", 4), ("talk", "speak", 2), ("hurry", "rush", 3),
            ("silent", "quiet", 3), ("scared", "afraid", 3), ("enough", "plenty", 4), ("cold", "chilly", 3),
            ("mend", "repair", 3), ("unwell", "ill", 3),
            ("noisy", "loud", 3), ("damp", "wet", 3), ("sleepy", "drowsy", 4), ("brave", "bold", 3),
            ("clever", "smart", 3), ("answer", "reply", 3), ("idea", "thought", 4),
            ("shy", "timid", 4), ("angry", "cross", 3), ("throw", "toss", 3), ("chat", "talk", 3),
            ("mistake", "error", 4), ("journey", "trip", 4), ("glad", "pleased", 3), ("easy", "simple", 3),
            ("strange", "odd", 4), ("famous", "well-known", 4), ("enemy", "foe", 5), ("happy", "cheerful", 3),
            ("ancient", "old", 5), ("view", "sight", 5), ("collect", "gather", 4)]
OPP_PAIRS = [("big", "small", 0), ("hot", "cold", 0), ("happy", "sad", 0), ("fast", "slow", 1),
             ("wet", "dry", 1), ("full", "empty", 1), ("clean", "dirty", 1), ("push", "pull", 1),
             ("open", "shut", 1), ("give", "take", 1), ("rich", "poor", 2), ("strong", "weak", 2),
             ("high", "low", 2), ("near", "far", 2), ("early", "late", 2), ("first", "last", 1),
             ("asleep", "awake", 2), ("win", "lose", 2), ("buy", "sell", 2), ("question", "answer", 3),
             ("arrive", "leave", 3), ("brave", "cowardly", 4), ("friend", "enemy", 3), ("polite", "rude", 3),
             ("remember", "forget", 3), ("always", "never", 3), ("inside", "outside", 1),
             ("above", "below", 2), ("before", "after", 2), ("sweet", "sour", 3), ("cheap", "costly", 3),
             ("deep", "shallow", 4), ("wide", "narrow", 3), ("thick", "thin", 2), ("rough", "smooth", 3),
             ("noisy", "quiet", 3), ("laugh", "cry", 1), ("sharp", "blunt", 4), ("heavy", "light", 3),
             ("tall", "short", 1), ("young", "old", 1), ("love", "hate", 2), ("borrow", "lend", 4),
             ("accept", "refuse", 4), ("success", "failure", 5), ("victory", "defeat", 5),
             ("ancient", "modern", 5), ("increase", "decrease", 5), ("include", "exclude", 6),
             ("generous", "selfish", 5), ("present", "absent", 4), ("true", "false", 3), ("alive", "dead", 3),
             ("enter", "exit", 4), ("arrival", "departure", 5), ("float", "sink", 3), ("lazy", "busy", 3),
             ("loose", "tight", 4), ("same", "different", 3), ("wise", "foolish", 4),
             ("find", "lose", 3), ("start", "finish", 2), ("day", "night", 0), ("up", "down", 0),
             ("come", "go", 0), ("east", "west", 3), ("north", "south", 3), ("max", "min", 9)]

# Class 2: sentence building. Subjects and verb phrases (3, 4 or 5 tiles).
SB_SUBJ = [("Riya", "3s"), ("Kabir", "3s"), ("Meera", "3s"), ("Aarav", "3s"), ("My mum", "3s"),
           ("Grandpa", "3s"), ("Dev", "3s"), ("Tara", "3s"), ("My dad", "3s")]
SB_VP3 = ["eats mangoes", "likes rain", "drinks milk", "reads books", "sings songs", "plays cricket",
          "flies kites", "loves dogs", "drinks tea", "draws pictures", "rides bicycles", "grows roses"]
SB_VP4 = ["eats a mango", "reads a book", "flies a kite", "rides a bicycle", "drinks hot milk",
          "sings a song", "has a cat", "makes a card", "likes red apples",
          "draws a tree", "climbs a hill", "waters the plants", "feeds the cat", "sweeps the floor"]
SB_VP5 = ["eats a ripe mango", "reads a funny book", "flies a red kite", "rides a new bicycle",
          "sings a happy song", "has a black cat", "makes a pretty card", "draws a tall tree",
          "wears a blue cap", "plays in the park", "goes to the market", "sits under a tree",
          "drinks a glass of milk", "waters the green plants"]

# Class 3: proper nouns (name, the common word it names).
PROPER = [
    ("Delhi", "city"), ("Mumbai", "city"), ("Kolkata", "city"), ("Chennai", "city"), ("Jaipur", "city"),
    ("Lucknow", "city"), ("Patna", "city"), ("Bhopal", "city"), ("Pune", "city"), ("Kochi", "city"),
    ("Ganga", "river"), ("Yamuna", "river"), ("Godavari", "river"), ("Kaveri", "river"), ("Narmada", "river"),
    ("India", "country"), ("Nepal", "country"), ("Bhutan", "country"), ("Japan", "country"), ("China", "country"),
    ("Monday", "day"), ("Tuesday", "day"), ("Friday", "day"), ("Sunday", "day"), ("Saturday", "day"),
    ("January", "month"), ("April", "month"), ("June", "month"), ("August", "month"), ("November", "month"),
    ("Diwali", "festival"), ("Holi", "festival"), ("Eid", "festival"), ("Christmas", "festival"),
    ("Pongal", "festival"), ("Onam", "festival"), ("Baisakhi", "festival"), ("Bihu", "festival"),
    ("Kerala", "state"), ("Punjab", "state"), ("Assam", "state"), ("Gujarat", "state"), ("Goa", "state"),
    ("Odisha", "state"), ("Bihar", "state"), ("Sikkim", "state"),
    ("Riya", "girl"), ("Meera", "girl"), ("Ananya", "girl"), ("Kabir", "boy"), ("Arjun", "boy"), ("Rohan", "boy"),
    ("Everest", "mountain"), ("Kanchenjunga", "mountain"),
]
COMMON_KINDS = ["city", "river", "country", "day", "month", "festival", "state", "girl", "boy", "mountain"]
COMMON_EXTRA = "city river country day month festival state girl boy mountain town village school " \
               "teacher park doctor shop".split()

# Class 3: adjectives in sentences. (category, adjectives, nouns, endings)
ADJ_SETS = [
    ("fruit", "ripe sweet juicy big small", "mango banana apple guava papaya", ["fell from the tree", "was on the plate"]),
    ("animal", "big small fat thin old lazy", "dog cat cow horse goat elephant", ["sat under the tree", "drank some water", "ran away"]),
    ("person", "tall kind happy brave clever old", "girl boy man woman teacher farmer", ["helped me", "sang a song", "waved at us"]),
    ("thing", "new old red heavy round shiny", "box ball bag kite pot clock", ["was on the table", "fell down", "was in the room"]),
    ("place", "busy quiet small big noisy clean", "market park street village shop", ["was near the river", "had many trees"]),
]
ADJ_PRED = [("mango", "sweet ripe juicy"), ("tea", "hot sweet"), ("sky", "blue clear"), ("box", "heavy empty"),
            ("kitten", "soft tiny"), ("road", "long wet"), ("room", "dark clean"), ("rope", "long thick"),
            ("baby", "happy sleepy"), ("lemon", "sour"), ("ice", "cold"), ("fire", "hot"), ("feather", "light"),
            ("stone", "hard"), ("elephant", "huge"), ("ant", "tiny"), ("well", "deep"), ("knife", "sharp"),
            ("pillow", "soft"), ("river", "wide"), ("glass", "empty full"), ("bag", "heavy new")]

# Class 3: homophones with frames. Each set: [[word, frame, frame...], ...]
HOMOPHONES = [
    [["sea", "Fish swim in the ___.", "We went to the ___ for a holiday."], ["see", "I can ___ a bird.", "Can you ___ the moon?"]],
    [["son", "Mr Rao has a ___ and a daughter.", "Her ___ is ten years old."], ["sun", "The ___ is very hot today.", "The ___ rises in the east."]],
    [["hear", "I can ___ the birds sing.", "Did you ___ the bell?"], ["here", "Come ___ and sit with me.", "My house is near ___."]],
    [["two", "I have ___ hands.", "A bicycle has ___ wheels."], ["to", "We go ___ school.", "Give the book ___ Riya."]],
    [["eight", "A spider has ___ legs.", "Four and four make ___."], ["ate", "Kabir ___ two bananas.", "The cat ___ the fish."]],
    [["flower", "A rose is a ___.", "The bee sat on the ___."], ["flour", "Roti is made from ___.", "Mum mixed the ___ with water."]],
    [["night", "Stars shine at ___.", "Owls hunt at ___."], ["knight", "The ___ rode a horse.", "The brave ___ had a sword."]],
    [["tail", "A dog wags its ___.", "The monkey has a long ___."], ["tale", "Grandma told us a ___.", "It is a fairy ___."]],
    [["blue", "The sky is ___.", "Riya has a ___ bag."], ["blew", "The wind ___ hard.", "He ___ out the candles."]],
    [["meat", "A lion eats ___.", "Tigers eat ___."], ["meet", "Let us ___ at the park.", "Nice to ___ you."]],
    [["road", "Look both ways before you cross the ___.", "The ___ was full of cars."], ["rode", "Meera ___ a horse.", "We ___ our bicycles."]],
    [["pair", "I have a new ___ of shoes.", "A ___ of socks."], ["pear", "A ___ is a fruit.", "She ate a juicy ___."]],
    [["sail", "Boats ___ on the sea.", "Let us ___ the boat."], ["sale", "The shop has a ___ today.", "The house is for ___."]],
    [["week", "There are seven days in a ___.", "See you next ___."], ["weak", "The sick puppy was ___.", "The old bridge is ___."]],
    [["write", "I ___ with a pencil.", "Please ___ your name."], ["right", "Raise your ___ hand.", "Your answer is ___."]],
    [["bear", "A ___ lives in the forest.", "The brown ___ ate honey."], ["bare", "Do not walk with ___ feet.", "The tree is ___ in winter."]],
    [["hole", "The rat ran into a ___.", "There is a ___ in my sock."], ["whole", "He ate the ___ cake.", "The ___ class came."]],
    [["new", "I have a ___ bag.", "We got a ___ car."], ["knew", "I ___ the answer.", "She ___ my name."]],
    [["no", "There is ___ milk left.", "___, thank you."], ["know", "I ___ how to swim.", "Do you ___ her?"]],
    [["one", "I have ___ nose.", "Only ___ child came."], ["won", "Our team ___ the match.", "She ___ a prize."]],
    [["plane", "The ___ flew in the sky.", "We went to Goa by ___."], ["plain", "She wore a ___ white shirt.", "Cows graze on the ___."]],
    [["tea", "Grandpa drinks hot ___.", "Mum made ___ for us."], ["tee", "", ""]],
    [["wait", "Please ___ for me.", "We ___ for the bus."], ["weight", "What is your ___?", "The ___ of the bag is 2 kg."]],
    [["made", "Mum ___ a cake.", "I ___ a paper boat."], ["maid", "", ""]],
    [["hair", "She has long ___.", "Comb your ___."], ["hare", "The ___ ran fast.", "The tortoise and the ___."]],
    [["dear", "My ___ friend.", "___ Grandma, I miss you."], ["deer", "A ___ ran into the forest.", "The ___ has big horns."]],
    [["piece", "Can I have a ___ of cake?", "A ___ of paper."], ["peace", "We want ___, not war.", "The park is full of ___ and quiet."]],
    [["sell", "They ___ fruit at the market.", "I will ___ my old cycle."], ["cell", "", ""]],
    [["by", "Stand ___ the door.", "We came ___ bus."], ["buy", "I want to ___ a pen.", "Let us ___ some mangoes."]],
    [["for", "This gift is ___ you.", "Wait ___ me."], ["four", "A cow has ___ legs.", "Two and two make ___."]],
    [["our", "This is ___ school.", "We love ___ teacher."], ["hour", "An ___ has sixty minutes.", "I waited for an ___."]],
    [["sore", "My throat is ___.", "I have a ___ knee."], ["saw", "I ___ a tiger at the zoo.", "We ___ a rainbow."]],
    [["stair", "", ""], ["stare", "It is rude to ___.", "Do not ___ at the sun."]],
    [["steel", "The spoon is made of ___.", "A ___ plate."], ["steal", "Do not ___.", "The crow tried to ___ the roti."]],
    [["wood", "The table is made of ___.", "We burnt ___ in the fire."], ["would", "___ you like some tea?", "I ___ like to go."]],
    [["red", "A ripe tomato is ___.", "She has a ___ ribbon."], ["read", "Yesterday I ___ a story.", "He ___ the whole book last night."]],
    [["mail", "The postman brings the ___.", "Did you get any ___?"], ["male", "A ___ lion has a mane.", "The ___ peacock has a long tail."]],
    [["sent", "I ___ a letter to Grandma.", "She ___ me a gift."], ["scent", "The rose has a sweet ___.", "The dog followed the ___."]],
    [["toe", "I hurt my big ___.", "Stand on your ___."], ["tow", "The truck will ___ the car.", ""]],
    [["bee", "A ___ makes honey.", "The ___ buzzed."], ["be", "Please ___ quiet.", "I want to ___ a doctor."]],
    [["eye", "Close one ___.", "Dust went into my ___."], ["I", "___ am happy.", "Riya and ___ are friends."]],
    [["flew", "The bird ___ away.", "The kite ___ high."], ["flu", "He has the ___ and a fever.", ""]],
    [["sea", "", ""], ["see", "", ""]],
]

# Class 3: prefixes. (word, prefix, base, meaning)
PREFIX = [
    ("unhappy", "un", "happy", "not happy"), ("unkind", "un", "kind", "not kind"), ("unsafe", "un", "safe", "not safe"),
    ("unwell", "un", "well", "not well"), ("untrue", "un", "true", "not true"), ("unfair", "un", "fair", "not fair"),
    ("unable", "un", "able", "not able"), ("unclean", "un", "clean", "not clean"), ("unlucky", "un", "lucky", "not lucky"),
    ("untidy", "un", "tidy", "not tidy"), ("unknown", "un", "known", "not known"), ("unseen", "un", "seen", "not seen"),
    ("unlock", "un", "lock", "open the lock"), ("untie", "un", "tie", "open a knot"), ("unpack", "un", "pack", "take things out"),
    ("unzip", "un", "zip", "open the zip"), ("unload", "un", "load", "take the load off"), ("undo", "un", "do", "reverse what was done"),
    ("unwrap", "un", "wrap", "take the wrapper off"), ("uncover", "un", "cover", "take the cover off"),
    ("unafraid", "un", "afraid", "not afraid"), ("unequal", "un", "equal", "not equal"), ("unhealthy", "un", "healthy", "not healthy"),
    ("unusual", "un", "usual", "not usual"), ("unpaid", "un", "paid", "not paid"), ("unripe", "un", "ripe", "not ripe"),
    ("redo", "re", "do", "do again"), ("rewrite", "re", "write", "write again"), ("refill", "re", "fill", "fill again"),
    ("replay", "re", "play", "play again"), ("reread", "re", "read", "read again"), ("rebuild", "re", "build", "build again"),
    ("reuse", "re", "use", "use again"), ("repaint", "re", "paint", "paint again"), ("retell", "re", "tell", "tell again"),
    ("reheat", "re", "heat", "heat again"), ("reopen", "re", "open", "open again"), ("recount", "re", "count", "count again"),
    ("rejoin", "re", "join", "join again"), ("restart", "re", "start", "start again"), ("revisit", "re", "visit", "visit again"),
    ("dislike", "dis", "like", "not like"), ("disagree", "dis", "agree", "not agree"), ("disobey", "dis", "obey", "not obey"),
    ("dishonest", "dis", "honest", "not honest"), ("disappear", "dis", "appear", "go out of sight"),
    ("disconnect", "dis", "connect", "break the link"), ("distrust", "dis", "trust", "not trust"),
    ("misspell", "mis", "spell", "spell wrongly"), ("misread", "mis", "read", "read wrongly"), ("misplace", "mis", "place", "put in the wrong place"),
    ("misbehave", "mis", "behave", "behave badly"), ("mislead", "mis", "lead", "lead the wrong way"),
    ("prepay", "pre", "pay", "pay before"), ("preview", "pre", "view", "see before"),
    ("impolite", "im", "polite", "not polite"), ("impossible", "im", "possible", "not possible"), ("impatient", "im", "patient", "not patient"),
    ("incorrect", "in", "correct", "not correct"), ("incomplete", "in", "complete", "not complete"), ("invisible", "in", "visible", "not visible"),
]

# Class 3: suffixes -ful/-less (base) and -er (verb, doer).
FUL_LESS = ("care hope help use pain colour fear harm thank power cheer play joy rest home end sleep "
            "spot taste mercy duty beauty wonder skill truth faith forget").split()
ER_DOER = [("teach", "teacher"), ("sing", "singer"), ("dance", "dancer"), ("paint", "painter"), ("farm", "farmer"),
           ("bake", "baker"), ("drive", "driver"), ("play", "player"), ("write", "writer"), ("swim", "swimmer"),
           ("run", "runner"), ("read", "reader"), ("garden", "gardener"), ("help", "helper"), ("clean", "cleaner"),
           ("lead", "leader"), ("win", "winner"), ("rob", "robber"), ("speak", "speaker"), ("jump", "jumper"),
           ("climb", "climber"), ("fight", "fighter"), ("build", "builder"), ("hunt", "hunter"), ("work", "worker"),
           ("shop", "shopper"), ("visit", "visitor"), ("act", "actor"), ("sail", "sailor"), ("direct", "director")]
FUL_FRAMES = [
    ("Be ___ with the hot tea.", "careful", "careless"), ("He lost his pen. He is so ___.", "careless", "careful"),
    ("A cut finger is ___.", "painful", "painless"), ("The pills made the test ___.", "painless", "painful"),
    ("The brave girl was ___ in the dark.", "fearless", "fearful"), ("Thank you! You are very ___.", "helpful", "helpless"),
    ("The broken pen is ___.", "useless", "useful"), ("A knife is ___ in the kitchen.", "useful", "useless"),
    ("The puppy was lost and ___.", "homeless", "homeful"), ("This snake is ___. It does not bite.", "harmless", "harmful"),
    ("Smoke is ___ to our lungs.", "harmful", "harmless"), ("The garden is full of ___ flowers.", "colourful", "colourless"),
    ("Water has no colour. It is ___.", "colourless", "colourful"), ("I could not sleep. It was a ___ night.", "sleepless", "sleepful"),
    ("The kitten is ___ and loves to jump.", "playful", "playless"), ("Her room is clean and ___.", "spotless", "spotful"),
    ("We are ___ for your help.", "thankful", "thankless"), ("The food has no taste. It is ___.", "tasteless", "tasteful"),
    ("The sea looks ___. It has no end.", "endless", "endful"), ("I feel ___ that we will win.", "hopeful", "hopeless"),
    ("The tired dog was ___ after a run.", "restless", "restful"), ("A ___ song made us smile.", "cheerful", "cheerless"),
    ("The king was rich and ___.", "powerful", "powerless"), ("The stray cat was ___ in the rain.", "helpless", "helpful"),
    ("Diwali is a ___ festival.", "joyful", "joyless"),
]

# Class 3: gender pairs (male, female).
GENDER = [("king", "queen"), ("prince", "princess"), ("actor", "actress"), ("lion", "lioness"), ("tiger", "tigress"),
          ("host", "hostess"), ("waiter", "waitress"), ("uncle", "aunt"), ("nephew", "niece"), ("son", "daughter"),
          ("father", "mother"), ("brother", "sister"), ("husband", "wife"), ("boy", "girl"), ("man", "woman"),
          ("gentleman", "lady"), ("grandfather", "grandmother"), ("bull", "cow"), ("cock", "hen"),
          ("drake", "duck"), ("peacock", "peahen"), ("ram", "ewe"), ("monk", "nun"), ("hero", "heroine"),
          ("emperor", "empress"), ("god", "goddess"), ("headmaster", "headmistress"), ("landlord", "landlady"),
          ("duke", "duchess"), ("bridegroom", "bride"), ("sir", "madam"), ("stallion", "mare"), ("gander", "goose"),
          ("fox", "vixen"), ("dog", "bitch"), ("wizard", "witch"), ("grandson", "granddaughter"), ("schoolboy", "schoolgirl"),
          ("policeman", "policewoman"), ("stepfather", "stepmother"), ("father-in-law", "mother-in-law")]
GENDER_SKIP = {"dog", "bitch"}

# Class 3: collective nouns. (collective, noun, other collectives that also work)
COLLECTIVE = [
    ("herd", "cows", "group"), ("herd", "elephants", "group"), ("herd", "deer", "group"), ("flock", "sheep", "herd"),
    ("flock", "birds", "flight"), ("swarm", "bees", "hive"), ("pride", "lions", ""), ("pack", "wolves", ""),
    ("school", "fish", "shoal"), ("bunch", "grapes", ""), ("bunch", "bananas", "hand"), ("bunch", "keys", ""),
    ("bouquet", "flowers", "bunch"), ("team", "players", "squad"), ("crowd", "people", ""), ("army", "soldiers", ""),
    ("fleet", "ships", ""), ("class", "students", ""), ("choir", "singers", ""), ("band", "musicians", ""),
    ("gang", "thieves", "band"), ("pair", "shoes", ""), ("pile", "books", "stack"), ("bundle", "sticks", ""),
    ("string", "pearls", ""), ("cluster", "stars", "galaxy"), ("range", "mountains", "chain"),
    ("litter", "puppies", ""), ("troop", "monkeys", ""), ("colony", "ants", "army"), ("flight", "steps", ""),
    ("pack", "cards", "deck"), ("crew", "sailors", ""), ("staff", "teachers", ""), ("panel", "judges", ""),
    ("audience", "listeners", ""), ("bunch", "flowers", "bouquet"), ("library", "books", ""), ("garland", "flowers", ""),
    ("basket", "fruits", ""), ("swarm", "locusts", ""), ("shoal", "fish", "school"), ("brood", "chicks", ""),
    ("pod", "dolphins", ""), ("parliament", "owls", ""), ("murder", "crows", ""), ("team", "oxen", ""),
    ("caravan", "camels", ""), ("set", "tools", "kit"), ("grove", "trees", ""), ("orchard", "trees", ""),
    ("forest", "trees", ""), ("heap", "stones", "pile"), ("album", "photos", ""), ("collection", "stamps", ""),
]
COLLECTIVE_SKIP = {"murder", "parliament", "pod", "grove", "orchard", "forest", "basket", "album", "garland"}
