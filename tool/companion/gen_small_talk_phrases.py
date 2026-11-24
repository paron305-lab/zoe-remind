#!/usr/bin/env python3
"""Small talk — phrase bank ng USER ("wassup", "kumusta ka?", "sino ka?"…).

Takbuhin (mula sa project root):
    python3 tool/companion/gen_small_talk_phrases.py

Gumagawa ng test/ai/small_talk_bank_data.dart (binabasa ng test/ai/small_talk_test.dart):
  • SmallTalkRules.read(ChatRouter.clean(phrase)) == inaasahang kind
  • ChatRouter.of(phrase): route greeting + talk == kind
  • negative: may utos / tanong / nararamdaman pa → HINDI small talk
"""
import os
import random

rng = random.Random(20261124)

PREFIX = ["", "zoe ", "zoe, ", "hi zoe ", "hello zoe, ", "hey zoe ", "uy zoe ", "oy ", "yo zoe ", "beh ", "Zoe! "]
SUFFIX = ["", "?", "!", " zoe", " po", " 😊", " haha", " ba", " naman", " 🙂", " lol"]

CORES = {
    "hello": ["wassup", "wassup zoe", "waassup", "wazzup", "whaddup", "waddup", "wsup", "what's up", "whats up",
              "what is up", "sup", "sup sup", "what's poppin", "what's new", "what's crackin", "anong ganap",
              "ano ganap", "ano balita", "anong balita", "anong chika", "chika naman", "anong meron", "ano bago",
              "hello", "hi", "hey", "heyy", "heyyo", "hey hey", "yo", "yow", "ayo", "hellurr", "helloo", "hallo",
              "hola", "kumusta", "musta", "good morning", "good afternoon", "good evening", "magandang umaga",
              "magandang gabi", "hellooo", "hiii", "howdy", "wasssup", "hey bestie", "hi bestie", "hey sis",
              "hi besh", "omg hi", "i'm back", "back na ako", "andito na ako", "good vibes", "uyyy hi",
              "hey girl", "musta mga bes"],
    "howAreYou": ["kumusta ka", "kamusta ka", "musta ka", "kumusta ka na", "kumusta ka naman", "musta na",
                  "how are you", "how r u", "how are you doing", "how u doin", "how's it going", "how's your day",
                  "how was your day", "how's ur day", "how have you been", "how you been", "how's life",
                  "how's the vibe", "what's good", "ok ka lang", "okay ka lang ba", "oks ka lang", "g ka lang",
                  "ayos ka lang", "are you okay", "are you good", "you good", "u good", "u ok", "hru",
                  "pagod ka na ba", "kumusta ang araw mo", "ikaw naman", "hbu", "wbu", "masaya ka ba",
                  "happy ka ba"],
    "whatDoing": ["ano ginagawa mo", "anong ginagawa mo", "ano'ng ginagawa mo", "what are you doing",
                  "what you doing", "what's you doing", "whatcha doing", "what are you up to", "what u up to",
                  "wyd", "busy ka ba", "are you busy", "busy u", "ano pinagkakaabalahan mo", "nag-aano ka",
                  "ano trip mo"],
    "whoAreYou": ["sino ka", "who are you", "ano ka ba", "what are you", "anong pangalan mo", "ano pangalan mo",
                  "what's your name", "what is your name", "introduce yourself", "pakilala ka",
                  "sino ka ba talaga", "who made you", "sino gumawa sa'yo", "what can you do",
                  "ano kaya mong gawin"],
    "areYouAi": ["tao ka ba", "tao ka ba talaga", "are you human", "are you real", "are you a robot",
                 "are you a bot", "are you ai", "robot ka ba", "ai ka ba", "totoo ka ba", "bot ka lang ba",
                 "are you a real person", "chatbot ka", "are you chatgpt", "are you siri", "buhay ka ba",
                 "may feelings ka ba", "do you have feelings"],
    "goodNight": ["good night", "goodnight", "gn", "nighty night", "night night", "nyt", "gnyt", "goodnyt",
                  "good nite", "tulog na ako", "matutulog na ako", "tutulog na ako", "sleep na ako",
                  "i'm going to sleep", "going to bed", "pahinga na ako", "g'night", "good night zoe",
                  "sleepy na ako", "antok na ako", "inaantok na ako", "i'm sleepy", "sweet dreams",
                  "hihiga na ako", "bedtime"],
    "bye": ["bye", "bye bye", "byeee", "babye", "bye na", "see you", "see you later", "see you tomorrow", "see ya",
            "see you around", "paalam", "alis na ako", "alis na ko", "una na ako", "aalis na muna ako", "ttyl",
            "talk to you later", "ingat", "take care", "catch you later", "gtg", "g2g", "gotta go", "brb",
            "laters", "later", "peace out", "ciao", "balik ako later", "babalik ako"],
    "compliment": ["ang galing mo", "ang talino mo", "galing mo talaga", "you're so smart", "you're the best",
                   "you are amazing", "you're awesome", "good job zoe", "best ka", "idol kita", "ang bait mo",
                   "you're so helpful", "good bot", "ang astig mo", "slay", "slay zoe", "periodt", "goat",
                   "lodi", "idol", "you rock", "ang galing mo naman", "galing galing", "so helpful",
                   "super smart", "ang helpful mo", "naks", "nice zoe", "ang cute mo", "you ate",
                   "ang ganda mo naman"],
    "affection": ["love you zoe", "i love you", "love you", "mahal kita", "mahal na kita", "ily", "ilysm",
                  "i like you", "luv you", "lab you", "love ya", "love you so much", "love you bestie",
                  "mwah", "muah", "mwah mwah", "hugs", "hug"],
    "bored": ["bored ako", "bored na ako", "i'm bored", "i'm so bored", "so bored", "bored af", "nakakabagot",
              "nakakaboring", "nababagot ako", "bagot na bagot", "wala akong magawa", "wala magawa",
              "nothing to do", "boring", "bored", "naiinip na ako", "nakakainip"],
    "haveYouEaten": ["kumain ka na", "kumain ka na ba", "kain ka na", "nag-lunch ka na", "nag lunch ka na",
                     "nag-dinner ka na", "nag-breakfast ka na", "nag-almusal ka na", "nakakain ka na",
                     "have you eaten", "did you eat", "u ate na", "nagkape ka na"],
    "letsChat": ["kwentuhan tayo", "kuwentuhan naman", "tara chika", "tara kwentuhan", "tara usap", "usap tayo",
                 "wanna chat", "wanna talk", "let's chat", "let's talk", "what's the tea", "spill the tea",
                 "may chika ka", "chika mo naman", "talk to me", "kausapin mo ako", "samahan mo ako",
                 "kwento ka naman", "entertain me", "chat tayo"],
}

# Small talk + iba pa → hindi small talk (utos, tanong, nararamdaman ang masusunod).
NEGATIVE = [
    "hi zoe, ano gagawin ko today?", "hello zoe remind me bukas 8am mag-review", "kumusta ka? pagod na ako",
    "what's up for tomorrow?", "ano ganap ko mamaya?", "anu ganap ko 2day?", "good night zoe, remind me 6am",
    "hey zoe add task laundry", "bye zoe, i-note mo wifi password zoe123", "sino si mama?",
    "ano pangalan ng doctor ko?", "hi zoe stressed na ako", "good morning, ano schedule ko?",
    "yo zoe gawa ka reminder 5pm", "love you zoe pero paalala ko bukas ha", "bored ako, remind me mag-gym 7pm",
    "zoe!", "hmm", "ano?", "salamat zoe", "thank you zoe, good night", "ang galing mo, may tanong ako about sa wifi",
    "tao ba si zoe sa notes ko?", "kumain ka na? remind mo ako kumain 12pm", "gtg, i-note mo parking B2",
    "brb, add task hugasan pinggan", "bored ako, ano gagawin ko today?", "wanna chat about my schedule tomorrow?",
    "slay! natapos ko na lahat", "love you zoe, pero pagod na ako", "sino si bestie sa contacts ko?",
]


def main():
    bank = {}
    for kind, cores in CORES.items():
        pool = [(p, c, s) for p in PREFIX for c in cores for s in SUFFIX]
        rng.shuffle(pool)
        out = list(cores)
        for p, c, s in pool:
            if len(out) >= 350:
                break
            out.append((p + c + s).strip())
        bank[kind] = list(dict.fromkeys(out))[:350]
    bank["negative"] = NEGATIVE
    return bank


def dart_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    bank = main()
    total = sum(len(v) for v in bank.values())
    lines = [
        "// GENERATED ng tool/companion/gen_small_talk_phrases.py — huwag i-edit nang kamay.",
        f"// {total} phrases. Takbuhin:  flutter test test/ai/small_talk_test.dart",
        "",
        "/// kind (SmallTalk.name, o 'negative') → mga mensahe ng user.",
        "const smallTalkBank = <String, List<String>>{",
    ]
    for kind, items in bank.items():
        lines.append(f"  '{kind}': [")
        lines += [f"    {dart_str(t)}," for t in items]
        lines.append("  ],")
    lines.append("};")
    path = os.path.join(root, "test", "ai", "small_talk_bank_data.dart")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{total} phrases → {path}")