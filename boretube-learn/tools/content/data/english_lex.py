"""The English lexicon (headwords) for Tubby's Town, as compact Python literals.

english_data.py expands these into lexicon.json. Token formats:

  nouns   "word:lvl[:flags]"   flags: v (also a verb), a (also an adjective),
                               u (uncountable), x (no plural questions),
                               P=<plural> (irregular plural)
  verbs   "base:lvl[:past[:pp]][:flags]"  flags: D (double the last letter),
                               n (also a noun), a (also an adjective)
  adjs    "base:lvl[:rule]"    rule: D (double: big, bigger), M (more/most),
                               X (no comparison), I=<comp>/<sup> (irregular),
                               B (both -er and more are used: skip in degree questions)
                               flags after rule with '+': n, v (other senses)

Levels are CBSE classes, 0 = KG. Every POS a child might meet is listed, so
questions that tag one POS only use words with a single POS.
"""

NOUNS = {
    "fruit": "apple:0 mango:0:x banana:0 orange:0:a grapes:0:x guava:1 papaya:1 pear:1 cherry:2 lemon:1 coconut:1 "
             "watermelon:1 pineapple:2 jackfruit:3 lychee:3 plum:2 peach:2 fig:2 litchi:4:x pomegranate:3 chikoo:3:x "
             "strawberry:2 apricot:4 melon:2",
    "vegetable": "potato:0 onion:0 carrot:1 cabbage:1 cauliflower:2 pea:1 radish:2 spinach:2:u brinjal:2 "
                 "pumpkin:1 beetroot:3:x garlic:2:u ladyfinger:3 capsicum:3 bean:1 corn:1:u",
    "animal": "cat:0 dog:0:v cow:0 lion:0 tiger:0 elephant:0 monkey:0 horse:0 goat:0 sheep:0:P=sheep camel:1 rabbit:0 "
              "deer:1:P=deer bear:1:v zebra:1 giraffe:1 fox:1 pig:0 donkey:1 mouse:0:P=mice rat:0 squirrel:1 "
              "buffalo:2:x snake:1 lizard:2 crocodile:2 tortoise:2 frog:1 kangaroo:2 rhino:3 leopard:2 wolf:2:P=wolves "
              "cheetah:3 panda:2 hippo:3 yak:3 calf:2:P=calves ox:2:P=oxen goose:2:P=geese",
    "bird": "parrot:0 crow:0:v sparrow:1 peacock:1 pigeon:1 duck:0:v hen:0 owl:1 eagle:2 swan:2 kingfisher:3 "
            "ostrich:3 vulture:3 woodpecker:3 cuckoo:2 myna:2",
    "sea": "fish:0:P=fish:v crab:2 shark:3 octopus:3 starfish:3 jellyfish:3 prawn:3",
    "insect": "ant:0 bee:0 butterfly:1 mosquito:2 ladybird:3 grasshopper:3 housefly:2 cockroach:3 dragonfly:3 beetle:3",
    "vehicle": "bus:0 car:0 train:0:v bicycle:1 cycle:0:v aeroplane:1 ship:1:v boat:0 auto:1 scooter:2 truck:1 "
               "tractor:2 rickshaw:2 tram:3 helicopter:2 jeep:2 van:1 ambulance:2 taxi:1",
    "body": "hand:0:v nose:0 ear:0 eye:0:v leg:0 head:0:v mouth:0 hair:0:u foot:0:P=feet tooth:1:P=teeth arm:0:v "
            "finger:1 toe:1 knee:1 neck:1 shoulder:2:v elbow:2 chin:2 cheek:2 lip:1 tongue:2 thumb:2 stomach:3:P=stomachs",
    "clothes": "shirt:0 frock:0 cap:0 sock:1 coat:1 skirt:2 sari:2 kurta:2 sweater:1 scarf:2:P=scarves glove:2 "
               "jacket:2 shoe:0 belt:2 tie:2:v dress:1:v uniform:2:a raincoat:2 pyjamas:2:x",
    "furniture": "chair:0 table:0 bed:0 sofa:1 cupboard:2 desk:1 stool:2 shelf:2:P=shelves bench:2 almirah:3",
    "food": "rice:0:u roti:0 bread:0:u milk:0:u:v dal:1:u egg:0 idli:1 dosa:1 cake:0 sugar:1:u salt:1:u butter:1:u "
            "cheese:2:u honey:1:u curd:1:u jam:1:u biscuit:1 sandwich:2 soup:2:u ladoo:2 jalebi:2 halwa:3:u "
            "samosa:2 paratha:2 khichdi:3:u poha:3:u pizza:1 juice:1:u tea:1:u water:0:u:v oil:2:u flour:2:u "
            "chapati:2 puri:2 upma:3:u kheer:3:u",
    "school": "pencil:0 pen:0 book:0:v bag:0:v box:0:v crayon:1 ruler:2 sharpener:2 notebook:1 slate:1 "
              "chalk:1:u board:1 teacher:0 student:2 classroom:1 school:0 desk:1 paper:1:u map:1 globe:2 "
              "library:2 lesson:2 rubber:2",
    "home": "door:0 window:0 house:0:v room:0 kitchen:1 roof:1 wall:0 floor:1 lamp:0 fan:0 clock:0:v cup:0 "
            "plate:0 spoon:0 bowl:1 glass:1 bottle:1:v pot:1 key:0 bucket:1 mirror:1 broom:2 pillow:1 "
            "blanket:2 soap:1:u towel:2 comb:1:v brush:1:v tap:1 bell:1 fridge:2 umbrella:1 candle:2 "
            "basket:1 tumbler:3 kettle:2 knife:2:P=knives",
    "nature": "sun:0 moon:0 star:0:v sky:0 tree:0 flower:0 leaf:0:P=leaves grass:0:u river:1 sea:1 hill:1 "
              "mountain:1 rain:0:v cloud:1 rock:1 stone:1 sand:1:u lake:1 pond:1 forest:2 island:2 desert:3 "
              "wind:1 storm:2 rainbow:1 seed:1 root:2 branch:2 plant:0:v garden:0 field:1 cave:2 beach:2 "
              "valley:3 earth:2 ocean:2 thunder:3:u",
    "people": "baby:0 boy:0 girl:0 man:0:P=men woman:1:P=women child:0:P=children mother:0 father:0 sister:0 "
              "brother:0 uncle:1 aunt:1 friend:0 king:1 queen:1 grandmother:1 grandfather:1 doctor:0 farmer:1 "
              "cook:1:v nurse:1 driver:1 tailor:2 pilot:2 baker:2 potter:2 carpenter:3 dentist:3 postman:2:P=postmen "
              "police:1:x soldier:2 artist:2 singer:1 dancer:2 player:2 person:2:P=people prince:2 princess:2",
    "place": "park:1 shop:0:v market:1 zoo:0 hospital:1 village:1 city:1 temple:1 bank:2 station:2 airport:2 "
             "museum:3 town:1 school:0 farm:1 garden:0 playground:1 cinema:3 mela:1 fort:2",
    "toy": "ball:0 doll:0 kite:0 toy:0 top:1 bat:1:v balloon:0 drum:1 swing:1:v puzzle:2 robot:2 teddy:1:x "
           "marble:2 flute:2 whistle:2:v",
    "time": "day:0 night:0 week:1 month:1 year:1 morning:1 evening:1 hour:1 minute:2 birthday:1 holiday:2 "
            "festival:2 season:2 summer:2 winter:2 monsoon:2 spring:3",
    "thing": "house:0 picture:1 letter:1 gift:1 coin:1 money:1:u game:1 song:1 story:1 idea:3 egg:0 nest:1 "
             "tail:1 wing:1 feather:1 shell:2 horn:2 web:2 rope:2 ladder:2 wheel:2 tent:2 flag:1 "
             "photo:2 parcel:3 ticket:2 lunch:1 dinner:1 breakfast:1 homework:2:u music:2:u news:3:u "
             "furniture:3:u luggage:3:u advice:4:u information:4:u traffic:3:u weather:3:u",
}

# Animals and things that are not what children guess (kept out of category questions).
CONTESTED = "tomato cucumber bat whale dolphin spider penguin octopus starfish jellyfish seahorse peanut " \
            "coconut corn pea bean".split()

VERBS = [
    # base:lvl[:past[:pp]][:flags]
    "go:0:went:gone", "come:0:came:come", "eat:0:ate:eaten", "see:0:saw:seen", "sit:0:sat:sat:D",
    "run:0:ran:run:Dn", "give:1:gave:given", "take:1:took:taken", "make:1:made:made:n", "sing:0:sang:sung",
    "drink:0:drank:drunk:n", "swim:1:swam:swum:Dn", "write:1:wrote:written", "read:1:read:read",
    "sleep:0:slept:slept:n", "fly:1:flew:flown:n", "draw:1:drew:drawn:n", "ride:1:rode:ridden:n",
    "drive:2:drove:driven:n", "throw:1:threw:thrown:n", "catch:1:caught:caught:n", "bring:2:brought:brought",
    "buy:2:bought:bought", "think:2:thought:thought", "teach:2:taught:taught", "fight:2:fought:fought:n",
    "sell:2:sold:sold", "tell:2:told:told", "find:2:found:found", "keep:2:kept:kept", "feel:2:felt:felt",
    "sweep:2:swept:swept", "leave:2:left:left", "lose:2:lost:lost", "win:1:won:won:Dn", "begin:2:began:begun:D",
    "break:2:broke:broken:n", "choose:3:chose:chosen", "speak:2:spoke:spoken", "steal:3:stole:stolen",
    "wake:2:woke:woken", "freeze:3:froze:frozen", "forget:2:forgot:forgotten:D", "hide:2:hid:hidden",
    "bite:2:bit:bitten:n", "blow:2:blew:blown:n", "grow:1:grew:grown", "know:1:knew:known",
    "fall:1:fell:fallen:n", "hold:2:held:held:n", "stand:1:stood:stood:n", "understand:3:understood:understood",
    "wear:1:wore:worn", "tear:3:tore:torn:n", "shake:2:shook:shaken:n", "sink:3:sank:sunk:n",
    "ring:2:rang:rung:n", "dig:2:dug:dug:D", "hang:3:hung:hung", "send:2:sent:sent", "spend:3:spent:spent",
    "lend:3:lent:lent", "build:2:built:built:n", "bend:3:bent:bent:n", "meet:2:met:met", "feed:2:fed:fed:n",
    "lead:3:led:led:n", "hear:1:heard:heard", "say:1:said:said", "pay:2:paid:paid:n", "lay:3:laid:laid",
    "sting:3:stung:stung:n", "swing:2:swung:swung:n", "stick:3:stuck:stuck:n", "light:3:lit:lit:na",
    "shoot:3:shot:shot:n", "slide:3:slid:slid:n", "cut:1:cut:cut:Dn", "put:1:put:put:D", "hit:1:hit:hit:Dn",
    "shut:2:shut:shut:D", "hurt:2:hurt:hurt", "let:2:let:let:D", "cost:3:cost:cost:n", "set:3:set:set:Dn",
    "spread:4:spread:spread", "burst:4:burst:burst", "become:3:became:become", "do:0:did:done",
    "have:0:had:had", "get:1:got:got:D", "shine:3:shone:shone", "fly:1:flew:flown:n", "lie:4:lay:lain",
    "forgive:3:forgave:forgiven", "drink:0:drank:drunk:n",
    # regular verbs
    "walk:0::n", "jump:0::n", "play:0::n", "help:0::n", "cook:1::n", "clean:1::a", "open:1::a", "kick:0::n",
    "push:1::n", "pull:1::n", "climb:1::n", "wash:1::n", "talk:1::n", "laugh:1::n", "look:1::n", "call:2::n",
    "paint:2::n", "plant:1::n", "pick:1::n", "fill:2", "help:0::n", "watch:1::n", "wish:2::n", "brush:1::n",
    "dance:1::n", "smile:1::n", "bake:2", "like:1", "live:2::a", "love:1::n", "close:2::a", "move:2::n",
    "skate:3::n", "share:2::n", "save:2", "smell:2::n", "shout:2::n", "cry:1::n", "try:2::n", "carry:2",
    "hurry:2::n", "study:3::n", "marry:3", "stop:1::Dn", "hop:1::Dn", "clap:1::Dn", "drop:2::Dn",
    "plan:2::Dn", "skip:2::D", "hug:1::Dn", "rub:3::D", "nod:2::Dn", "grab:3::D", "chop:3::D",
    "shop:2::Dn", "beg:3::D", "pat:3::Dn", "wag:3::D", "rob:3::D", "trip:3::Dn", "jog:3::Dn",
    "enjoy:3", "visit:2::n", "learn:2", "fix:3", "kiss:2::n", "mix:3", "fetch:3", "touch:2::n",
    "rest:2::n", "need:2::n", "want:1", "wait:2", "ask:1", "answer:2::n", "count:2::n", "listen:2",
    "arrive:3", "decide:3", "invite:3", "explain:4", "travel:3::Dn", "shiver:4", "obey:4", "borrow:3",
    "follow:3", "fold:3::n", "float:3", "melt:3", "boil:3", "fry:3", "pour:3", "rain:0::n", "snow:2::n",
    "work:1::n", "finish:2::n", "start:2::n", "end:3::n", "worry:3::n", "copy:3::n", "bury:4",
    "agree:4", "reply:4::n", "tidy:3::a", "chase:3::n", "collect:3", "repair:4::n", "receive:4",
    "believe:4", "whisper:4::n", "complete:4::a", "describe:4", "prepare:4", "practise:4",
]

ADJS = [
    # base:lvl[:rule]  rule: D, M, X, I=comp/sup, B ; +n +v other senses
    "big:0:D", "small:0", "tall:0", "short:0", "long:0:+v", "hot:0:D", "cold:0:+n", "happy:0", "sad:0:D",
    "fat:1:D+n", "thin:1:D", "old:0", "new:0", "young:1", "fast:1:+v", "slow:1:+v", "good:0:I=better/best",
    "bad:0:I=worse/worst", "red:0:X+n", "blue:0:X+n", "green:0:X+n", "yellow:0:X+n", "black:0:X+n",
    "white:0:X+n", "pink:1:X+n", "brown:1:X+n", "grey:1:X+n", "orange:0:X+n", "purple:1:X+n",
    "clean:0:+v", "dirty:1", "wet:1:D+v", "dry:1:+v", "hard:1", "soft:1", "heavy:1", "light:2:+nv",
    "full:1", "empty:1:+v", "sweet:1:+n", "sour:2", "loud:1", "quiet:2:+n", "rich:2", "poor:2", "strong:1",
    "weak:2", "kind:1:+n", "cruel:3:I=crueller/cruellest", "brave:2", "clever:2:B", "lazy:2", "busy:2", "hungry:1", "thirsty:2",
    "tired:2:X", "sleepy:1", "angry:2", "funny:1", "pretty:1:+d", "ugly:2", "beautiful:2:M", "huge:2",
    "tiny:1", "round:1:+n", "flat:2:D+n", "sharp:2", "shiny:2", "bright:2", "dark:1:+n", "cheap:3",
    "costly:3", "deep:2", "wide:2", "narrow:3:B", "thick:2", "smooth:3", "rough:3", "early:2:+d",
    "late:2:+d", "near:2:+p", "far:2:I=farther/farthest+d", "high:2:+d", "low:2:+d", "great:2", "nice:1",
    "safe:2:+n", "fresh:2", "ripe:2", "raw:3:X", "juicy:2", "tasty:2", "salty:3", "spicy:3", "bitter:3:B",
    "warm:1:+v", "cool:2:+v", "noisy:2", "silly:2", "lucky:2", "neat:2", "messy:3", "friendly:3:B",
    "careful:3:M", "helpful:3:M", "useful:3:M", "colourful:3:M", "famous:3:M", "honest:3:M", "polite:3:B",
    "proud:3", "gentle:3", "simple:3:B", "easy:2", "difficult:3:M", "important:4:M", "dangerous:4:M",
    "delicious:3:M", "wonderful:3:M", "naughty:3", "healthy:3", "sick:2", "ill:3:X", "fine:2:+n",
    "wise:3", "foolish:4:M", "calm:3:+v", "fierce:4", "grand:4", "little:1:I=smaller/smallest",
    "many:1:I=more/most", "much:2:I=more/most", "excited:3:M", "scared:3:M", "afraid:3:X", "alone:3:X",
    "golden:3:X", "wooden:3:X", "real:3:X", "silver:3:X+n", "true:3", "free:3:+v", "same:2:X",
    "different:3:M", "modern:4:M", "ancient:5:M", "curious:4:M", "generous:5:M", "humble:5", "gloomy:5",
    "cheerful:4:M", "graceful:5:M", "grateful:5:M", "sturdy:5", "fragile:6:M", "ordinary:5:M",
]

ADVERBS = ("slowly:3 quickly:3 loudly:3 softly:3 happily:3 sadly:3 carefully:3 quietly:3 gently:3 "
           "neatly:3 bravely:4 kindly:4 angrily:4 easily:4 politely:4 badly:4 well:3 fast:3 hard:3 "
           "always:3 never:3 often:4 soon:3 today:3 yesterday:3 tomorrow:3 here:3 there:3 "
           "everywhere:4 rarely:5 suddenly:4 proudly:4 eagerly:5 brightly:4 honestly:5 noisily:4 "
           "cheerfully:5 busily:4 lazily:4 hungrily:4")

PRONOUNS = "I you he she it we they me him her us them myself"
PREPS = "in on under behind beside between above below near into over through across along towards"
CONJS = "and but or because so although while until unless"
INTERJ = "wow oh hurray alas ouch oops hello bravo"
