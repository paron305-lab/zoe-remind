#!/usr/bin/env python3
"""Level 3 — phrase bank ng USER: paano sinasabi ng tao ang nickname, style,
stress help, wins at routines (English / Tagalog / Taglish / text-speak).

Takbuhin (mula sa project root):
    python3 tool/companion/gen_companion_phrases.py

Gumagawa ng test/memory/companion_phrase_bank_data.dart, na binabasa ng
test/memory/companion_phrase_bank_test.dart:
  • CompanionFacts.read(phrase) == inaasahang kind + value
  • ChatRouter.of(phrase).route == memory  (negative: != memory)
"""
import os
import random

rng = random.Random(20261124)

NAMES = ["AC", "Pao", "JM", "Aaron", "Bea", "Migs", "Kat", "Jojo", "Nina", "Ced", "Rhea", "Gab",
         "Ella", "Tonton", "Yna", "Kiko", "Mika", "Raffy", "Lia", "Bong"]

PREFIX = ["", "zoe, ", "Zoe ", "hi zoe, ", "hey zoe ", "uy zoe, ", "oy ", "btw ", "Zoe pls ",
          "hello zoe! ", "beh ", "zoe, from now on ", "ah zoe, "]
SUFFIX = ["", " please", " ha", " 😊", " po", "!", " thanks", " salamat", " nga", " 💜", " ok?", " haha"]

NICK_CORES = [
    "call me {N}", "just call me {N}", "you can call me {N}", "please call me {N}", "call me {N} from now on",
    "call me {N} na lang", "i'd like you to call me {N}", "my name is {N}",
    "tawagin mo akong {N}", "tawagin mo na lang akong {N}", "tawagin mo ako {N}", "tawagin mo akong {N} simula ngayon",
    "{N} na lang itawag mo sa akin", "{N} na lang ang itawag mo sakin", "{N} ang itawag mo sa akin",
    "{N} na lang tawag mo sakin", "ang pangalan ko ay {N}", "pangalan ko ay {N}",
    "tandaan mo, tawagin mo akong {N}", "remember, call me {N}",
]

STYLE_CORES = {
    "diretso": [
        "diretsuhin mo lang ako", "diretso ka lang sa akin", "diretsahan mo na lang ako", "deretsuhin mo ako",
        "be direct with me", "just be direct", "be straight with me", "straight to the point lang",
        "straight to the point please", "keep it short", "keep your answers short", "keep your replies short",
        "short answers lang", "short replies only", "maikling sagot lang", "no sugarcoating",
        "wag mo na akong i-baby", "huwag mo akong i-baby", "don't sugarcoat it", "just tell me straight",
        "be blunt with me", "wag mo nang i-sugarcoat",
    ],
    "malambing": [
        "maging malambing ka sa akin", "malambing ka lang sa akin", "lambingin mo ako", "be gentle with me",
        "be soft with me", "be sweet to me", "be kind to me", "go easy on me", "gentle ka lang",
        "gentle ka lang sa akin", "dahan-dahan ka lang sa akin", "talk to me gently", "mahinahon ka lang sa akin",
        "maging mahinahon ka", "just be gentle", "be gentle lang", "gusto ko malambing ka",
    ],
}

WHEN_EN = ["when i'm stressed", "when i'm stressed out", "whenever i'm stressed", "if i'm stressed",
           "when i'm overwhelmed", "when i'm sad", "when i'm down", "when i feel down", "if i get stressed",
           "when i am stressed", "whenever i feel sad", "when im stressed"]
WHEN_TL = ["kapag stressed ako", "pag stressed ako", "kapag pagod ako", "kapag malungkot ako", "pag down ako",
           "kapag na-stress ako", "kung stressed ako", "kapag nalulungkot ako", "pag overwhelmed ako",
           "kapag ako ay pagod", "pag pagod na ako", "kapag stress na stress ako"]
HELP = {
    "listen": {
        "en": ["just listen", "listen first", "just listen to me", "hear me out", "let me vent", "just let me vent"],
        "tl": ["makinig ka muna", "makinig ka lang", "pakinggan mo lang ako", "hayaan mo akong mag-vent",
               "makinig ka lang sa kwento ko", "makinig ka muna bago ka magsalita"],
    },
    "advice": {
        "en": ["give me advice", "give me tips", "give me a tip", "i need advice", "advise me", "give me solutions"],
        "tl": ["bigyan mo ako ng payo", "payuhan mo ako", "payo agad", "tips agad", "bigyan mo ako ng tips",
               "magbigay ka ng solusyon"],
    },
    "lighten": {
        "en": ["cheer me up", "make me laugh", "tell me a joke", "tell me jokes", "make me smile"],
        "tl": ["patawanin mo ako", "pasayahin mo ako", "magbiro ka", "pagaanin mo loob ko", "pangitiin mo ako",
               "bigyan mo ako ng jokes"],
    },
}

TRIGGERS = ["tandaan mo, ", "tandaan mo na ", "zoe tandaan mo, ", "remember that ", "please remember that ",
            "don't forget that ", "keep in mind that ", "fyi ", "for the record, ", "wag mong kalimutan na "]
WINS = [
    "nakapasa ako sa board exam", "natapos ko na ang thesis ko", "nanalo ako sa contest", "natanggap ako sa trabaho",
    "na-promote ako", "graduate na ako", "nakapasa ako sa interview", "natapos ko ang first marathon ko",
    "i passed the board exam", "i finished my first marathon", "i got the job", "i got promoted",
    "i graduated last year", "i won the hackathon", "i passed my driving test", "i got hired at my dream company",
]
ROUTINES = [
    "nag-gy-gym ako tuwing MWF", "nagsisimba kami tuwing linggo", "araw-araw akong nagja-jogging",
    "gumigising ako ng maaga araw-araw", "lagi akong late natutulog", "i jog every morning",
    "i usually sleep late", "i go to the gym every monday", "i always drink coffee first",
    "nagbabasa ako gabi-gabi", "nagluluto ako tuwing weekend", "i work night shift every weekday",
    "every sunday i visit my lola", "nag-aaral ako tuwing gabi",
]

# Hindi dapat maging memory card ng Level 3.
NEGATIVE = [
    "call me later", "call me at 7pm", "call me tomorrow", "call me back please", "can you call me later?",
    "ano tawag mo sa akin?", "anong itatawag mo sakin?", "ano pangalan ko?",
    "kapag stressed ako, i-remind mo akong magpahinga", "remind me every morning to drink water",
    "pagod na ako", "stressed ako ngayon", "ang saya ko, nakapasa ako!", "nakapasa ako sa exam!!",
    "i got the job!!!", "natapos ko na lahat", "be direct, remind me bukas ng 8am", "diretso uwi ako mamaya",
    "nag-gym ako kanina", "gusto ko ng morning reminders", "do you remember that i passed?",
    "remind me to call mama", "tawagan mo si mama bukas", "ano gagawin ko today?", "salamat zoe",
    "may tips ka ba kapag stressed ako?", "what should i do when i'm stressed? any advice?",
    "paano ako makakapag-relax kapag pagod ako, may tips ka?", "kapag stressed ako, ano pwede kong gawin?",
]


def combos(cores, cap, expect, question_ok=True):
    out = []
    suffixes = SUFFIX if question_ok else [x for x in SUFFIX if "?" not in x]
    pool = [(p, c, s) for p in PREFIX for c in cores for s in suffixes]
    rng.shuffle(pool)
    # bawat core, isang beses na walang dagdag
    for c in cores:
        out.append(c)
    for p, c, s in pool:
        if len(out) >= cap:
            break
        out.append(p + c + s)
    return [(x, expect) for x in dict.fromkeys(out)]


def main():
    bank = {}
    # nickname — bawat pangalan
    nick = []
    for name in NAMES:
        cores = [c.replace("{N}", name) for c in NICK_CORES if c]
        for text, _ in combos(cores, 40, None):
            nick.append((text, name))
    bank["nickname"] = nick
    for st, cores in STYLE_CORES.items():
        bank["style|" + st] = [(t, st) for t, _ in combos(cores, 380, st)]
    for h, parts in HELP.items():
        cores = []
        for w in WHEN_EN:
            for x in parts["en"]:
                cores.append(f"{w}, {x}")
                cores.append(f"{x} {w}")
        for w in WHEN_TL:
            for x in parts["tl"]:
                cores.append(f"{w}, {x}")
                cores.append(f"{w} {x}")
        # Taglish
        for w in WHEN_TL[:4]:
            for x in parts["en"]:
                cores.append(f"{w}, {x}")
        rng.shuffle(cores)
        cores = cores[:120]
        bank["stress_help|" + h] = [(t, h) for t, _ in combos(cores, 330, h, question_ok=False)]
    bank["win"] = [(t, None) for t, _ in combos([tr + w for tr in TRIGGERS for w in WINS], 320, None, question_ok=False)]
    bank["routine"] = [(t, None) for t, _ in combos([tr + r for tr in TRIGGERS for r in ROUTINES], 320, None, question_ok=False)]
    bank["negative"] = [(t, None) for t in NEGATIVE]
    return bank


def dart_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def write(bank, path):
    total = sum(len(v) for v in bank.values())
    lines = [
        "// GENERATED ng tool/companion/gen_companion_phrases.py — huwag i-edit nang kamay.",
        "//",
        f"// {total} phrases para sa Level 3 Companion memory (EN / Tagalog / Taglish / text-speak).",
        "// Takbuhin:  flutter test test/memory/companion_phrase_bank_test.dart",
        "",
        "/// kind ('nickname', 'style', 'stress_help', 'win', 'routine', 'negative') →",
        "/// listahan ng (phrase, inaasahang value). value null = walang value.",
        "const companionBank = <String, List<(String, String?)>>{",
    ]
    for key, items in bank.items():
        kind = key.split("|")[0]
        lines.append(f"  // {key} ({len(items)})")
    lines = lines[:-len(bank)]
    merged = {}
    for key, items in bank.items():
        merged.setdefault(key.split("|")[0], []).extend(items)
    for kind, items in merged.items():
        lines.append(f"  '{kind}': [")
        for text, value in items:
            v = "null" if value is None else dart_str(value)
            lines.append(f"    ({dart_str(text)}, {v}),")
        lines.append("  ],")
    lines.append("};")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{total} phrases → {path}")
    return merged


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    b = main()
    write(b, os.path.join(root, "test", "memory", "companion_phrase_bank_data.dart"))