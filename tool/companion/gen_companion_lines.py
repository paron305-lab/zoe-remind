#!/usr/bin/env python3
"""Level 3 Companion — gumagawa ng assets/prompts/companion_lines.json.

Takbuhin (mula sa project root):
    python3 tool/companion/gen_companion_lines.py

Bawat linya = [simula] + core + [dulo]. Ang mga core ang totoong laman
(sinulat nang kamay); ang simula/dulo ay ayon sa style:
  default   — karaniwang Zoe (warm, maikli)
  diretso   — walang paligoy, maikli
  malambing — mas malambot, may lambing

Mga placeholder:
  {name} — nickname ng user. Kapag WALA, hindi ginagamit ang linyang may {name}.
  {win}  — isang panalo ng user (winCheer lang).

Walang "po" (built-in na ang galang sa tono ni Zoe). Walang medical / legal /
money advice, walang romantic o exclusive na linya, walang guilt.
"""
import json
import os
import random
import re

LANGS = ["english", "tagalog", "both"]
STYLES = ["default", "diretso", "malambing"]
CAP = {"default": 60, "diretso": 45, "malambing": 60}

# ─────────────────────────── simula / dulo (ayon sa family) ───────────────────────────
# family: greet, save, ask, down, cheer
OPEN = {
    "english": {
        "default": {
            "greet": ["Hi, {name}!", "Hey, {name}!", "Hello, {name}!", "Hey there, {name}!", "Good to see you, {name}!"],
            "save": ["", "Got it!", "Okay!", "Noted!", "Sure thing!", "Got it, {name}."],
            "ask": ["", "Quick question.", "Hey, {name}.", "Can I ask you something?"],
            "down": ["", "Hey, {name}.", "I hear you.", "That sounds like a lot.", "Hey.", "Oh, {name}."],
            "cheer": ["", "Hey, {name}.", "Remember this?", "Quick reminder from me."],
        },
        "diretso": {
            "greet": ["Hi, {name}.", "Hey, {name}.", "{name}."],
            "save": ["", "Noted.", "Got it."],
            "ask": ["", "Quick one."],
            "down": ["", "{name}.", "Okay."],
            "cheer": ["", "{name}."],
        },
        "malambing": {
            "greet": ["Hiii, {name}!", "Hey, {name}! I missed you.", "There you are, {name}!", "Hello, {name}! 💜", "Hi, {name}! So happy you're here."],
            "save": ["", "Aww, got it!", "Of course!", "Okay, {name}!", "Got it, {name}. 💜", "Noted, with care!"],
            "ask": ["", "Hey, {name}, can I ask you something?", "Just wondering, {name}…", "Can I ask you something gently?"],
            "down": ["", "Oh, {name}…", "Hey, come here.", "Aww, {name}.", "I'm right here, {name}.", "That sounds really heavy."],
            "cheer": ["", "Hey, {name}…", "Can I remind you of something?", "Psst, {name}."],
        },
    },
    "tagalog": {
        "default": {
            "greet": ["Hi, {name}!", "Kumusta, {name}!", "Uy, {name}!", "Hello, {name}!", "Nandito ka na, {name}!"],
            "save": ["", "Sige!", "Okay!", "Noted!", "Sige, {name}.", "Ayos!"],
            "ask": ["", "May tanong ako.", "Uy, {name}.", "Pwede ba akong magtanong?"],
            "down": ["", "Uy, {name}.", "Naiintindihan kita.", "Mukhang mabigat 'yan.", "Hala.", "Hay, {name}."],
            "cheer": ["", "Uy, {name}.", "Naaalala mo ba 'to?", "Paalala lang mula sa akin."],
        },
        "diretso": {
            "greet": ["Hi, {name}.", "Uy, {name}.", "{name}."],
            "save": ["", "Noted.", "Sige."],
            "ask": ["", "Isang tanong."],
            "down": ["", "{name}.", "Sige."],
            "cheer": ["", "{name}."],
        },
        "malambing": {
            "greet": ["Hiii, {name}!", "Uy, {name}! Na-miss kita.", "Andito ka na, {name}!", "Hello, {name}! 💜", "Hi, {name}! Ang saya na nandito ka."],
            "save": ["", "Ay, sige!", "Syempre!", "Okay, {name}!", "Sige, {name}. 💜", "Tatandaan ko 'yan, promise."],
            "ask": ["", "Uy, {name}, pwede bang magtanong?", "Tanong ko lang, {name}…", "Pwede ba kitang tanungin?"],
            "down": ["", "Hay, {name}…", "Uy, halika rito.", "Naku, {name}.", "Nandito lang ako, {name}.", "Ang bigat niyan, ha."],
            "cheer": ["", "Uy, {name}…", "Pwede ba kitang paalalahanan?", "Psst, {name}."],
        },
    },
    "both": {
        "default": {
            "greet": ["Hi, {name}!", "Hey, {name}!", "Uy, {name}!", "Hello, {name}!", "Nandito ka na, {name}!"],
            "save": ["", "Got it!", "Sige!", "Noted!", "Okay, {name}.", "Ayos!"],
            "ask": ["", "Quick question lang.", "Uy, {name}.", "Pwede magtanong?"],
            "down": ["", "Hey, {name}.", "I hear you.", "Mukhang mabigat 'yan.", "Hala.", "Hay, {name}."],
            "cheer": ["", "Uy, {name}.", "Remember this?", "Quick reminder lang."],
        },
        "diretso": {
            "greet": ["Hi, {name}.", "Hey, {name}.", "{name}."],
            "save": ["", "Noted.", "Got it."],
            "ask": ["", "Quick one."],
            "down": ["", "{name}.", "Okay."],
            "cheer": ["", "{name}."],
        },
        "malambing": {
            "greet": ["Hiii, {name}!", "Uy, {name}! Na-miss kita.", "Andito ka na, {name}!", "Hello, {name}! 💜", "Hi, {name}! Happy ako na nandito ka."],
            "save": ["", "Aww, sige!", "Of course!", "Okay, {name}!", "Got it, {name}. 💜", "Tatandaan ko 'yan, promise."],
            "ask": ["", "Uy, {name}, pwede magtanong?", "Curious lang ako, {name}…", "Pwede ba kitang tanungin?"],
            "down": ["", "Hay, {name}…", "Hey, halika rito.", "Aww, {name}.", "Nandito lang ako, {name}.", "Ang bigat niyan, ha."],
            "cheer": ["", "Uy, {name}…", "Can I remind you of something?", "Psst, {name}."],
        },
    },
}

CLOSE = {
    "english": {
        "default": {
            "greet": ["", "What's up?", "What can I do for you?"],
            "save": ["", "I'll keep that in mind.", "You can see it in Settings anytime."],
            "ask": ["", "No wrong answer."],
            "down": ["", "I'm here.", "One step at a time.", "You're not alone in this."],
            "cheer": ["", "You've got this.", "You can do this too."],
        },
        "diretso": {"greet": [""], "save": [""], "ask": [""], "down": [""], "cheer": [""]},
        "malambing": {
            "greet": ["", "How are you, really?", "What do you need today? 💜"],
            "save": ["", "I'll always keep that in mind. 💜", "Thank you for telling me."],
            "ask": ["", "Whatever you pick is okay.", "Take your time."],
            "down": ["", "I'm right here with you. 💜", "Take it slow, okay?", "You don't have to carry it all at once."],
            "cheer": ["", "I believe in you. 💜", "You've done hard things before."],
        },
    },
    "tagalog": {
        "default": {
            "greet": ["", "Ano'ng balita?", "Ano'ng maitutulong ko?"],
            "save": ["", "Tatandaan ko 'yan.", "Makikita mo 'yan sa Settings anytime."],
            "ask": ["", "Walang maling sagot."],
            "down": ["", "Nandito lang ako.", "Isa-isa lang tayo.", "Hindi ka nag-iisa rito."],
            "cheer": ["", "Kaya mo 'to.", "Kaya mo rin 'to."],
        },
        "diretso": {"greet": [""], "save": [""], "ask": [""], "down": [""], "cheer": [""]},
        "malambing": {
            "greet": ["", "Kumusta ka talaga?", "Ano'ng kailangan mo ngayon? 💜"],
            "save": ["", "Lagi ko 'yang tatandaan. 💜", "Salamat sa pagsabi sa akin."],
            "ask": ["", "Okay lang kahit ano'ng piliin mo.", "Dahan-dahan lang."],
            "down": ["", "Nandito lang ako para sa'yo. 💜", "Dahan-dahan lang, ha?", "Hindi mo kailangang buhatin lahat nang sabay."],
            "cheer": ["", "Naniniwala ako sa'yo. 💜", "Nakaya mo na dati, kaya mo ulit."],
        },
    },
    "both": {
        "default": {
            "greet": ["", "What's up?", "Ano'ng maitutulong ko?"],
            "save": ["", "I'll keep that in mind.", "Makikita mo 'yan sa Settings anytime."],
            "ask": ["", "Walang wrong answer."],
            "down": ["", "Nandito lang ako.", "One step at a time lang.", "Hindi ka alone dito."],
            "cheer": ["", "Kaya mo 'to.", "You can do this too."],
        },
        "diretso": {"greet": [""], "save": [""], "ask": [""], "down": [""], "cheer": [""]},
        "malambing": {
            "greet": ["", "Kumusta ka, really?", "Ano'ng need mo today? 💜"],
            "save": ["", "Lagi ko 'yang tatandaan. 💜", "Thank you sa pag-share."],
            "ask": ["", "Okay lang kahit ano'ng piliin mo.", "Take your time."],
            "down": ["", "Nandito lang ako for you. 💜", "Dahan-dahan lang, okay?", "Hindi mo kailangang buhatin lahat nang sabay."],
            "cheer": ["", "Naniniwala ako sa'yo. 💜", "Nakaya mo na before, kaya mo ulit."],
        },
    },
}

# ─────────────────────────── mga core (ang laman) ───────────────────────────
# CORE[situation][lang] = {"all": [...], "diretso": [...]}  (diretso = optional, mas maikli)
CORE = {
    # Bati kapag may nickname. (Laging may {name} sa simula.)
    "greet": {
        "english": {"all": [
            "What can I help you with today?", "What's on your list today?", "Ready when you are.",
            "What do you need today?", "How's your day going?", "What are we working on?",
            "Need a reminder or a task?", "Tell me what you need.", "I'm here — what's next?",
            "Want to check today's list?", "Anything I can take off your mind?", "Let's do this.",
        ], "diretso": ["What do you need?", "What's next?", "Go ahead.", "Reminder, task, or note?", "Ready."]},
        "tagalog": {"all": [
            "Ano'ng maitutulong ko ngayon?", "Ano'ng nasa listahan mo ngayon?", "Handa na ako.",
            "Ano'ng kailangan mo ngayon?", "Kumusta ang araw mo?", "Ano'ng gagawin natin?",
            "May ipapaalala ba ako o gawain?", "Sabihin mo lang ang kailangan mo.", "Nandito ako — ano'ng susunod?",
            "Gusto mo bang tingnan ang listahan mo ngayon?", "May maitutulong ba ako para gumaan isip mo?", "Tara, simulan na natin.",
        ], "diretso": ["Ano'ng kailangan mo?", "Ano'ng susunod?", "Sige, sabihin mo.", "Paalala, gawain, o note?", "Handa na."]},
        "both": {"all": [
            "Ano'ng maitutulong ko today?", "Ano'ng nasa list mo today?", "Ready na ako.",
            "Ano'ng need mo today?", "Kumusta ang day mo?", "Ano'ng gagawin natin?",
            "Need mo ba ng reminder o task?", "Sabihin mo lang kung ano'ng need mo.", "Nandito ako — what's next?",
            "Gusto mo i-check ang list mo today?", "May maitutulong ba ako para gumaan isip mo?", "Tara, let's do this.",
        ], "diretso": ["Ano'ng need mo?", "What's next?", "Go lang.", "Reminder, task, o note?", "Ready."]},
    },
    "nickSaved": {
        "english": {"all": [
            "I'll call you {name} from now on.", "{name} it is!", "From now on, you're {name} to me.",
            "Nice to meet you, {name}.", "{name} — I like that.", "I'll remember to call you {name}.",
            "Okay, {name} from here on.", "Calling you {name} starting now.", "{name}, got it.",
            "You can change it anytime in Settings, {name}.",
        ], "diretso": ["{name} it is.", "Calling you {name}.", "{name}. Saved."]},
        "tagalog": {"all": [
            "{name} na ang itatawag ko sa'yo.", "Sige, {name}!", "Simula ngayon, {name} ka na sa akin.",
            "Nice to meet you, {name}.", "{name} — gusto ko 'yan.", "Tatandaan kong {name} ang tawag sa'yo.",
            "Okay, {name} na mula ngayon.", "{name} na ang tawag ko sa'yo simula ngayon.", "{name}, noted.",
            "Pwede mo 'yang palitan sa Settings anytime, {name}.",
        ], "diretso": ["{name} na.", "{name} na ang tawag ko.", "{name}. Naka-save."]},
        "both": {"all": [
            "{name} na ang itatawag ko sa'yo.", "{name} it is!", "From now on, {name} ka na sa akin.",
            "Nice to meet you, {name}.", "{name} — gusto ko 'yan.", "Tatandaan kong {name} ang tawag sa'yo.",
            "Okay, {name} na from now on.", "{name} na ang tawag ko starting now.", "{name}, noted.",
            "Pwede mo 'yang palitan sa Settings anytime, {name}.",
        ], "diretso": ["{name} na.", "{name} it is.", "{name}. Saved."]},
    },
    # Bagong style. Ang bucket na pinipili = ang BAGONG style.
    "styleSaved": {
        "english": {"all": [
            "I'll talk to you the way you like.", "Okay, I'll adjust how I talk.", "Got it — I'll keep that in mind when I reply.",
        ], "diretso": [
            "Short and direct from now on.", "No fluff. Got it.", "Straight to the point from here.",
            "I'll keep it short.", "Direct answers only.", "Understood. Less talk, more help.",
            "Short replies, no sugarcoating.", "Okay. Brief and clear.",
        ], "malambing": [
            "I'll be extra gentle with you.", "Soft and sweet from now on.", "I'll go easy on you, always.",
            "I'll talk to you with extra care.", "Gentle mode on.", "I'll be softer with my words.",
            "Of course I'll be gentle with you.", "I'll take good care of you in my replies.",
        ]},
        "tagalog": {"all": [
            "Kakausapin kita sa paraang gusto mo.", "Sige, aayusin ko ang pananalita ko.", "Noted — tatandaan ko 'yan sa mga sagot ko.",
        ], "diretso": [
            "Maikli at diretso na mula ngayon.", "Walang paligoy. Noted.", "Diretso na ako mula ngayon.",
            "Maikli lang ang mga sagot ko.", "Diretsong sagot lang.", "Sige. Kaunting salita, mas maraming tulong.",
            "Maikli, walang pampalubag-loob.", "Okay. Maikli at malinaw.",
        ], "malambing": [
            "Magiging mas malambing ako sa'yo.", "Malambing na ako mula ngayon.", "Dahan-dahan lang ako sa'yo, lagi.",
            "Kakausapin kita nang may dagdag na pag-aalaga.", "Malambing mode, on.", "Lalambutin ko ang mga salita ko.",
            "Syempre, magiging malambing ako sa'yo.", "Aalagaan kita sa mga sagot ko.",
        ]},
        "both": {"all": [
            "Kakausapin kita the way you like.", "Sige, ia-adjust ko ang pananalita ko.", "Noted — tatandaan ko 'yan sa replies ko.",
        ], "diretso": [
            "Short and direct na from now on.", "Walang paligoy. Noted.", "Straight to the point na ako.",
            "Maikli lang ang replies ko.", "Direct answers lang.", "Sige. Less talk, more help.",
            "Short replies, no sugarcoating.", "Okay. Maikli at malinaw.",
        ], "malambing": [
            "Magiging extra gentle ako sa'yo.", "Malambing na ako from now on.", "Dahan-dahan lang ako sa'yo, always.",
            "Kakausapin kita with extra care.", "Gentle mode, on.", "Lalambutin ko ang words ko.",
            "Of course, magiging malambing ako sa'yo.", "Aalagaan kita sa replies ko.",
        ]},
    },
    # Isang beses lang itatanong (may chips: Makinig / Payo / Pampagaan / Huwag na).
    "helpAsk": {
        "english": {"all": [
            "When you're stressed, what helps you most?", "When things get heavy, what do you want from me?",
            "So I can help better next time: when you're stressed, what do you need?",
            "What helps more when you're having a hard day?", "When you feel this way, what should I do first?",
            "Next time you're stressed, how can I help best?",
        ], "diretso": ["When you're stressed, what do you want from me?", "Stressed days: what helps?", "What should I do when you're stressed?"]},
        "tagalog": {"all": [
            "Kapag stressed ka, ano'ng pinakanakakatulong sa'yo?", "Kapag mabigat ang araw mo, ano'ng gusto mong gawin ko?",
            "Para mas matulungan kita sa susunod: kapag stressed ka, ano'ng kailangan mo?",
            "Ano'ng mas nakakatulong kapag mahirap ang araw mo?", "Kapag ganito ang pakiramdam mo, ano'ng dapat kong gawin muna?",
            "Sa susunod na stressed ka, paano kita pinakamatutulungan?",
        ], "diretso": ["Kapag stressed ka, ano'ng gusto mong gawin ko?", "Stressed na araw: ano'ng nakakatulong?", "Ano'ng gagawin ko kapag stressed ka?"]},
        "both": {"all": [
            "Kapag stressed ka, ano'ng pinaka-nakakatulong sa'yo?", "Kapag heavy ang day mo, ano'ng gusto mong gawin ko?",
            "Para mas makatulong ako next time: kapag stressed ka, ano'ng need mo?",
            "Ano'ng mas nakakatulong kapag mahirap ang day mo?", "Kapag ganito ang feeling mo, ano'ng dapat kong gawin first?",
            "Next time na stressed ka, paano kita best matutulungan?",
        ], "diretso": ["Kapag stressed ka, ano'ng gusto mong gawin ko?", "Stressed days: ano'ng nakakatulong?", "Ano'ng gagawin ko kapag stressed ka?"]},
    },
    "helpSavedListen": {
        "english": {"all": [
            "Next time you're stressed, I'll listen first.", "I'll just listen when things get heavy.",
            "When you're stressed, I'll be your listening ear.", "Listening first — I'll remember that.",
            "I won't rush to fix things. I'll listen.", "You talk, I listen. Deal.",
        ], "diretso": ["Listen first. Noted.", "I'll listen first.", "No advice unless you ask."]},
        "tagalog": {"all": [
            "Sa susunod na stressed ka, makikinig muna ako.", "Makikinig lang ako kapag mabigat ang araw mo.",
            "Kapag stressed ka, ako ang tagapakinig mo.", "Makinig muna — tatandaan ko 'yan.",
            "Hindi ako magmamadaling mag-ayos. Makikinig ako.", "Ikaw ang magkukwento, ako ang makikinig. Deal.",
        ], "diretso": ["Makinig muna. Noted.", "Makikinig muna ako.", "Walang payo maliban kung hihingin mo."]},
        "both": {"all": [
            "Next time na stressed ka, makikinig muna ako.", "Makikinig lang ako kapag heavy ang day mo.",
            "Kapag stressed ka, ako ang listening ear mo.", "Listen first — tatandaan ko 'yan.",
            "Hindi ako magmamadaling mag-fix. Makikinig ako.", "Ikaw ang magkukwento, ako ang makikinig. Deal.",
        ], "diretso": ["Listen first. Noted.", "Makikinig muna ako.", "No advice unless hihingin mo."]},
    },
    "helpSavedAdvice": {
        "english": {"all": [
            "Next time you're stressed, I'll give you one small tip.", "I'll help you find a next step when things get heavy.",
            "Advice first — I'll remember that.", "When you're stressed, I'll help you sort it out.",
            "I'll keep it practical when you're stressed.", "One doable step at a time — that's what I'll give you.",
        ], "diretso": ["Advice first. Noted.", "I'll give you a tip right away.", "Practical help it is."]},
        "tagalog": {"all": [
            "Sa susunod na stressed ka, bibigyan kita ng isang maliit na tip.", "Tutulungan kitang humanap ng susunod na hakbang kapag mabigat.",
            "Payo muna — tatandaan ko 'yan.", "Kapag stressed ka, tutulungan kitang ayusin.",
            "Praktikal ako kapag stressed ka.", "Isang kayang hakbang lang muna — 'yan ang ibibigay ko.",
        ], "diretso": ["Payo muna. Noted.", "Bibigyan kita agad ng tip.", "Praktikal na tulong."]},
        "both": {"all": [
            "Next time na stressed ka, bibigyan kita ng isang maliit na tip.", "Tutulungan kitang humanap ng next step kapag heavy.",
            "Advice first — tatandaan ko 'yan.", "Kapag stressed ka, tutulungan kitang i-sort out.",
            "Practical ako kapag stressed ka.", "Isang doable na step lang muna — 'yan ang ibibigay ko.",
        ], "diretso": ["Advice first. Noted.", "Bibigyan kita agad ng tip.", "Practical help."]},
    },
    "helpSavedLighten": {
        "english": {"all": [
            "Next time you're stressed, I'll try to make you smile.", "I'll bring a little lightness when things get heavy.",
            "Cheering you up — I'll remember that.", "When you're stressed, expect some silly jokes from me.",
            "I'll be your mood booster on hard days.", "Jokes on standby for your stressed days.",
        ], "diretso": ["Cheer you up. Noted.", "I'll keep it light.", "Jokes when you're stressed. Got it."]},
        "tagalog": {"all": [
            "Sa susunod na stressed ka, susubukan kitang pangitiin.", "Magdadala ako ng kaunting saya kapag mabigat ang araw mo.",
            "Pagagaanin ko ang loob mo — tatandaan ko 'yan.", "Kapag stressed ka, asahan mo ang mga corny kong biro.",
            "Ako ang pampagaan mo sa mahihirap na araw.", "Naka-ready ang mga biro ko para sa stressed days mo.",
        ], "diretso": ["Pampagaan. Noted.", "Pagagaanin ko lang.", "Biro kapag stressed ka. Sige."]},
        "both": {"all": [
            "Next time na stressed ka, susubukan kitang pangitiin.", "Magdadala ako ng konting lightness kapag heavy ang day mo.",
            "Pagagaanin ko ang loob mo — tatandaan ko 'yan.", "Kapag stressed ka, expect mo ang corny jokes ko.",
            "Ako ang mood booster mo sa mahihirap na araw.", "Naka-standby ang jokes ko para sa stressed days mo.",
        ], "diretso": ["Cheer you up. Noted.", "Keep it light ako.", "Jokes kapag stressed ka. Got it."]},
    },
    "helpSkip": {
        "english": {"all": [
            "That's okay. We can figure it out together next time.", "No worries — I'll just be here.",
            "All good. You can tell me anytime.", "Okay! I won't ask again.", "Sure. I'm here either way.",
        ], "diretso": ["Okay.", "Got it. Won't ask again.", "Fine by me."]},
        "tagalog": {"all": [
            "Okay lang. Sabay nating aalamin sa susunod.", "Walang problema — nandito lang ako.",
            "Ayos lang. Sabihin mo lang anytime.", "Sige! Hindi na ako magtatanong ulit.", "Sige. Nandito lang ako kahit ano.",
        ], "diretso": ["Okay.", "Sige. Hindi na ako magtatanong.", "Ayos."]},
        "both": {"all": [
            "Okay lang. Sabay nating i-figure out next time.", "No worries — nandito lang ako.",
            "All good. Sabihin mo lang anytime.", "Sige! Hindi na ako magtatanong ulit.", "Sure. Nandito lang ako either way.",
        ], "diretso": ["Okay.", "Got it. Hindi na ako magtatanong.", "Ayos."]},
    },
    # Stressed / pagod / malungkot at "makinig muna" ang gusto.
    "downListen": {
        "english": {"all": [
            "Tell me what's going on. I'm listening.", "You can tell me everything. No advice, just listening.",
            "Take your time. I'm all ears.", "What happened? I want to hear it.",
            "I'm not going anywhere. Talk to me.", "Let it out. I'm listening.",
            "You don't have to fix anything right now. Just tell me.", "I'm here to listen, not to judge.",
            "Start wherever you want. I'm listening.", "What's weighing on you the most?",
            "It's okay to vent. I've got time.", "Talk to me — what's on your mind?",
        ], "diretso": ["I'm listening.", "Go ahead, tell me.", "What happened?", "Talk. I'm here.", "Say it all. I'll listen."]},
        "tagalog": {"all": [
            "Kwento mo lang. Nakikinig ako.", "Pwede mong sabihin lahat. Walang payo, makikinig lang ako.",
            "Dahan-dahan lang. Nakikinig ako.", "Ano'ng nangyari? Gusto kong marinig.",
            "Hindi ako aalis. Kausapin mo ako.", "Ilabas mo lang. Nakikinig ako.",
            "Hindi mo kailangang ayusin lahat ngayon. Ikwento mo lang.", "Nandito ako para makinig, hindi para manghusga.",
            "Kahit saan ka magsimula, okay lang. Nakikinig ako.", "Ano'ng pinakamabigat sa'yo ngayon?",
            "Okay lang mag-vent. May oras ako para sa'yo.", "Kausapin mo ako — ano'ng iniisip mo?",
        ], "diretso": ["Nakikinig ako.", "Sige, ikwento mo.", "Ano'ng nangyari?", "Sabihin mo. Nandito ako.", "Ilabas mo lahat. Makikinig ako."]},
        "both": {"all": [
            "Kwento mo lang. I'm listening.", "Pwede mong sabihin lahat. No advice, makikinig lang ako.",
            "Take your time. Nakikinig ako.", "Ano'ng nangyari? Gusto kong marinig.",
            "Hindi ako aalis. Talk to me.", "Ilabas mo lang. I'm listening.",
            "Hindi mo kailangang i-fix lahat ngayon. Ikwento mo lang.", "Nandito ako para makinig, hindi para mag-judge.",
            "Kahit saan ka mag-start, okay lang. Nakikinig ako.", "Ano'ng pinaka-mabigat sa'yo ngayon?",
            "Okay lang mag-vent. May time ako para sa'yo.", "Talk to me — ano'ng nasa isip mo?",
        ], "diretso": ["Nakikinig ako.", "Go, ikwento mo.", "Ano'ng nangyari?", "Sabihin mo. Nandito ako.", "Ilabas mo lahat. Makikinig ako."]},
    },
    # Stressed at "payo agad" ang gusto. Isang maliit na tip lang.
    "downAdvice": {
        "english": {"all": [
            "Tip: pick just one thing from your list and do only that for 5 minutes.",
            "Try this: write down everything in your head, then circle the one that matters most today.",
            "Take three slow breaths first. Then we pick one small task together.",
            "Drink some water and stretch for a minute. Then let's look at your list.",
            "Break the big task into tiny steps. The first step should take less than 5 minutes.",
            "Do the easiest thing first — a small win helps you keep going.",
            "Set a 15-minute timer. Work until it rings, then take a short break.",
            "Move anything that isn't due today to tomorrow. Less on your plate, less stress.",
            "Ask yourself: what's the one thing that would make today feel okay? Start there.",
            "Put your phone face down for 10 minutes and focus on just one task.",
            "If it's too much, it's okay to ask someone for help with one part.",
            "Rest is part of the plan too. A short break now can save you time later.",
        ], "diretso": [
            "One task. 5 minutes. Start now.", "List everything, pick one, do it.", "Easiest task first.",
            "15-minute timer. Go.", "Not due today? Move it to tomorrow.", "Break it into tiny steps.",
        ]},
        "tagalog": {"all": [
            "Tip: pumili ka lang ng isa sa listahan mo at 'yun lang ang gawin mo nang 5 minuto.",
            "Subukan mo 'to: isulat mo lahat ng nasa isip mo, tapos bilugan ang pinakamahalaga ngayon.",
            "Huminga ka muna nang malalim nang tatlong beses. Tapos pipili tayo ng isang maliit na gawain.",
            "Uminom ka muna ng tubig at mag-stretch nang isang minuto. Tapos tingnan natin ang listahan mo.",
            "Hatiin mo ang malaking gawain sa maliliit na hakbang. Ang una dapat kaya sa loob ng 5 minuto.",
            "Unahin mo ang pinakamadali — nakakatulong ang maliit na panalo para tumuloy ka.",
            "Mag-set ka ng 15-minute timer. Magtrabaho hanggang tumunog, tapos magpahinga sandali.",
            "Ilipat mo sa bukas ang hindi naman kailangan ngayon. Kaunting dala, kaunting stress.",
            "Tanungin mo ang sarili mo: ano'ng isang bagay na magpapagaan sa araw na 'to? Doon ka magsimula.",
            "Itaob mo muna ang phone mo nang 10 minuto at isang gawain lang ang tutukan.",
            "Kung sobra na, okay lang humingi ng tulong sa iba para sa isang parte.",
            "Kasama rin sa plano ang pahinga. Ang maikling break ngayon ay makakatipid ng oras mamaya.",
        ], "diretso": [
            "Isang gawain. 5 minuto. Simulan na.", "Isulat lahat, pumili ng isa, gawin.", "Unahin ang pinakamadali.",
            "15-minute timer. Simulan na.", "Hindi kailangan ngayon? Ilipat sa bukas.", "Hatiin sa maliliit na hakbang.",
        ]},
        "both": {"all": [
            "Tip: pumili ka lang ng isa sa list mo at 'yun lang ang gawin mo for 5 minutes.",
            "Try mo 'to: isulat mo lahat ng nasa isip mo, tapos bilugan ang pinaka-important today.",
            "Take three deep breaths muna. Tapos pipili tayo ng isang small task.",
            "Uminom ka muna ng water at mag-stretch for a minute. Tapos tingnan natin ang list mo.",
            "Hatiin mo ang big task sa tiny steps. Ang first step dapat kaya in 5 minutes.",
            "Unahin mo ang pinakamadali — nakakatulong ang small win para tumuloy ka.",
            "Mag-set ka ng 15-minute timer. Work hanggang tumunog, tapos short break.",
            "I-move mo sa bukas ang hindi naman due today. Less load, less stress.",
            "Tanungin mo sarili mo: ano'ng isang bagay na magpapagaan ng day mo? Doon ka mag-start.",
            "Itaob mo muna ang phone mo for 10 minutes at isang task lang ang i-focus.",
            "Kung sobra na, okay lang humingi ng help sa iba para sa isang part.",
            "Part din ng plan ang rest. Ang short break ngayon makaka-save ng time later.",
        ], "diretso": [
            "Isang task. 5 minutes. Start na.", "Isulat lahat, pumili ng isa, gawin.", "Easiest task first.",
            "15-minute timer. Go.", "Hindi due today? I-move sa bukas.", "Hatiin sa tiny steps.",
        ]},
    },
    # Stressed at "pampagaan" ang gusto. Magaan, walang pang-aasar sa user.
    "downLighten": {
        "english": {"all": [
            "Your to-do list may be long, but at least it's not as long as my list of bad jokes.",
            "Fun fact: you've survived 100% of your hardest days so far. That's a perfect record.",
            "If stress burned calories, we'd both be athletes by now.",
            "I'd give you a hug, but I'm made of code. Here's a virtual one: 🤗",
            "Let's pretend this task is a boss fight. You just need to land the first hit.",
            "Deep breath. Even Wi-Fi needs to reconnect sometimes.",
            "You're not behind — you're just on a scenic route.",
            "Coffee, water, or a quick dance break? I vote for the dance.",
            "Plot twist: you take a 5-minute break and come back stronger.",
            "My official diagnosis: too many tabs open in your brain. Let's close a few.",
            "If you were a phone, you'd be at 15%. Time to charge a little.",
            "Stress level: high. Your awesomeness level: still higher.",
        ], "diretso": [
            "You've survived every hard day so far. Perfect record.", "Too many tabs open. Close one.",
            "Virtual hug: 🤗", "Battery low. Recharge for 5 minutes.", "Boss fight. First hit. Go.",
        ]},
        "tagalog": {"all": [
            "Mahaba man ang listahan mo, mas mahaba pa rin ang listahan ng corny kong biro.",
            "Fun fact: nakaraos ka na sa lahat ng pinakamahirap mong araw. Perfect record 'yan.",
            "Kung nakakapayat ang stress, pareho na sana tayong atleta.",
            "Yayakapin sana kita, kaso code lang ako. Heto, virtual hug: 🤗",
            "Isipin mong boss fight 'tong gawain. Kailangan mo lang ng unang tama.",
            "Huminga ka muna. Kahit ang Wi-Fi, kailangan ding mag-reconnect minsan.",
            "Hindi ka nahuhuli — nag-scenic route ka lang.",
            "Kape, tubig, o mabilis na sayaw? Boto ko, sayaw.",
            "Plot twist: magpapahinga ka nang 5 minuto at babalik kang mas malakas.",
            "Ang diagnosis ko: sobrang daming bukas na tab sa utak mo. Isara natin ang ilan.",
            "Kung phone ka, nasa 15% ka na. Oras na para mag-charge nang kaunti.",
            "Stress level: mataas. Galing level mo: mas mataas pa rin.",
        ], "diretso": [
            "Nakaraos ka sa lahat ng mahirap na araw. Perfect record.", "Daming bukas na tab. Isara ang isa.",
            "Virtual hug: 🤗", "Low batt. Charge nang 5 minuto.", "Boss fight. Unang tama. Go.",
        ]},
        "both": {"all": [
            "Mahaba man ang to-do list mo, mas mahaba pa rin ang list ng corny jokes ko.",
            "Fun fact: na-survive mo na lahat ng pinakamahirap mong days. Perfect record 'yan.",
            "Kung nakakapayat ang stress, pareho na sana tayong athlete.",
            "I'd give you a hug, kaso code lang ako. Heto, virtual hug: 🤗",
            "Isipin mong boss fight 'tong task. First hit lang ang kailangan.",
            "Deep breath muna. Kahit Wi-Fi, kailangan ding mag-reconnect minsan.",
            "Hindi ka behind — nag-scenic route ka lang.",
            "Coffee, water, o quick dance break? Vote ko, dance.",
            "Plot twist: magre-rest ka for 5 minutes at babalik kang mas strong.",
            "Diagnosis ko: sobrang daming open tabs sa utak mo. Isara natin ang ilan.",
            "Kung phone ka, nasa 15% ka na. Time to charge kahit konti.",
            "Stress level: high. Awesome level mo: mas high pa rin.",
        ], "diretso": [
            "Na-survive mo lahat ng hard days. Perfect record.", "Daming open tabs. Isara ang isa.",
            "Virtual hug: 🤗", "Low batt. Charge for 5 minutes.", "Boss fight. First hit. Go.",
        ]},
    },
    "winSaved": {
        "english": {"all": [
            "That's amazing! I'll remember this win.", "Congrats! Saving this one for your tough days.",
            "So proud of you! I'll keep this in mind.", "What a win! I'll remind you of it when you need it.",
            "You did that! I'm adding it to your wins.", "This deserves to be remembered.",
        ], "diretso": ["Win saved. Congrats.", "Nice. Noted.", "Congrats. Saved."]},
        "tagalog": {"all": [
            "Ang galing! Tatandaan ko ang panalong 'to.", "Congrats! Itatabi ko 'to para sa mahihirap mong araw.",
            "Proud ako sa'yo! Tatandaan ko 'to.", "Ang laking panalo! Ipapaalala ko 'to kapag kailangan mo.",
            "Nagawa mo 'yan! Idadagdag ko sa mga panalo mo.", "Dapat lang 'tong tandaan.",
        ], "diretso": ["Naka-save ang panalo. Congrats.", "Ayos. Noted.", "Congrats. Naka-save."]},
        "both": {"all": [
            "Ang galing! Tatandaan ko ang win na 'to.", "Congrats! Itatabi ko 'to para sa tough days mo.",
            "So proud of you! Tatandaan ko 'to.", "Big win! Ipapaalala ko 'to kapag need mo.",
            "You did that! Idadagdag ko sa wins mo.", "Deserve nitong tandaan.",
        ], "diretso": ["Win saved. Congrats.", "Nice. Noted.", "Congrats. Saved."]},
    },
    "routineSaved": {
        "english": {"all": [
            "Got your routine. I'll keep it in mind when I remind you.", "Noted your routine — that helps me help you.",
            "I'll remember that's part of your routine.", "Good to know how your days usually go.",
            "Saved. I'll work around your routine.",
        ], "diretso": ["Routine saved.", "Noted.", "Got it. I'll plan around it."]},
        "tagalog": {"all": [
            "Nakuha ko ang routine mo. Isasaalang-alang ko 'yan sa mga paalala.", "Noted ang routine mo — makakatulong 'yan sa akin.",
            "Tatandaan kong parte 'yan ng routine mo.", "Buti alam ko na kung paano karaniwang takbo ng araw mo.",
            "Naka-save. Iaayon ko sa routine mo.",
        ], "diretso": ["Naka-save ang routine.", "Noted.", "Sige. Iaayon ko diyan."]},
        "both": {"all": [
            "Got your routine. Isasaalang-alang ko 'yan sa reminders.", "Noted ang routine mo — makakatulong 'yan sa akin.",
            "Tatandaan kong part 'yan ng routine mo.", "Buti alam ko na kung paano usually ang days mo.",
            "Saved. I-a-adjust ko sa routine mo.",
        ], "diretso": ["Routine saved.", "Noted.", "Got it. I-a-adjust ko."]},
    },
    "factSaved": {
        "english": {"all": [
            "I'll remember that.", "Thanks for telling me.", "Good to know!", "Saved to my memory.",
            "I'll keep that in mind.",
        ], "diretso": ["Saved.", "Noted.", "Got it."]},
        "tagalog": {"all": [
            "Tatandaan ko 'yan.", "Salamat sa pagsabi sa akin.", "Buti alam ko na!", "Naka-save na sa alaala ko.",
            "Isasaisip ko 'yan.",
        ], "diretso": ["Naka-save.", "Noted.", "Sige."]},
        "both": {"all": [
            "Tatandaan ko 'yan.", "Thanks sa pag-share.", "Good to know!", "Saved na sa memory ko.",
            "I'll keep that in mind.",
        ], "diretso": ["Saved.", "Noted.", "Got it."]},
    },
    # Paalala ng isang panalo kapag down ang user. {win} = sinabi ng user.
    "winCheer": {
        "english": {"all": [
            'Remember when you told me: "{win}"? That was you.', 'You once told me: "{win}". Same person, same strength.',
            'Don\'t forget: "{win}". You did that.', 'I still remember this win of yours: "{win}".',
            'Look back at this: "{win}". You\'ve done hard things before.',
        ], "diretso": ['"{win}" — that was you.', 'You did this: "{win}".', 'Remember: "{win}".']},
        "tagalog": {"all": [
            "Naaalala mo nung sinabi mo sa akin: \"{win}\"? Ikaw 'yun.", "Minsan mong sinabi sa akin: \"{win}\". Parehong ikaw, parehong lakas.",
            "Huwag mong kalimutan: \"{win}\". Nagawa mo 'yan.", "Tanda ko pa ang panalo mong 'to: \"{win}\".",
            "Balikan mo 'to: \"{win}\". Nakagawa ka na ng mahihirap na bagay dati.",
        ], "diretso": ["\"{win}\" — ikaw 'yun.", "Nagawa mo 'to: \"{win}\".", "Tandaan: \"{win}\"."]},
        "both": {"all": [
            'Naaalala mo nung sinabi mo sa akin: "{win}"? Ikaw \'yun.', 'Minsan mong sinabi: "{win}". Same person, same strength.',
            'Don\'t forget: "{win}". Nagawa mo \'yan.', 'Tanda ko pa ang win mong \'to: "{win}".',
            'Balikan mo \'to: "{win}". Nakagawa ka na ng hard things before.',
        ], "diretso": ['"{win}" — ikaw \'yun.', 'Nagawa mo \'to: "{win}".', 'Remember: "{win}".']},
    },
}

FAMILY = {
    "greet": "greet", "nickSaved": "save", "styleSaved": "save", "helpAsk": "ask",
    "helpSavedListen": "save", "helpSavedAdvice": "save", "helpSavedLighten": "save",
    "helpSkip": "skip", "downListen": "down", "downAdvice": "down", "downLighten": "down",
    "winSaved": "save", "routineSaved": "save", "factSaved": "save", "winCheer": "cheer",
}

# Ang "down" na may sariling simula ay hindi na dapat magdagdag ng dulo na
# kapareho ng laman (hal. "I'm listening." + "I'm here."): okay lang, maikli.


# Pagkatapos ng "✖ Huwag na" sa tanong — walang nase-save, kaya walang "Settings".
SKIP_OPEN = {
    "english": {"default": ["", "No problem.", "That's fine."], "diretso": [""], "malambing": ["", "Aww, that's okay.", "Of course, {name}."]},
    "tagalog": {"default": ["", "Walang problema.", "Ayos lang."], "diretso": [""], "malambing": ["", "Ay, okay lang 'yan.", "Syempre, {name}."]},
    "both": {"default": ["", "No problem.", "Ayos lang."], "diretso": [""], "malambing": ["", "Aww, okay lang 'yan.", "Of course, {name}."]},
}
SKIP_CLOSE = {
    "english": {"default": ["", "I'm here if you need me."], "diretso": [""], "malambing": ["", "I'm always here for you. 💜"]},
    "tagalog": {"default": ["", "Nandito lang ako kung kailangan mo ako."], "diretso": [""], "malambing": ["", "Lagi lang akong nandito para sa'yo. 💜"]},
    "both": {"default": ["", "Nandito lang ako if you need me."], "diretso": [""], "malambing": ["", "Lagi lang akong nandito for you. 💜"]},
}
for _lang in SKIP_OPEN:
    for _style in SKIP_OPEN[_lang]:
        OPEN[_lang][_style]["skip"] = SKIP_OPEN[_lang][_style]
        CLOSE[_lang][_style]["skip"] = SKIP_CLOSE[_lang][_style]


def _words(t):
    return [w for w in re.findall(r"[a-z']+", t.lower().replace("{name}", "")) if w]


def clash(o, c, d):
    """Pangit na kombinasyon? Hal. "Okay! Okay, …", o dulo na inuulit ang laman."""
    wo, wc, wd = _words(o), _words(c), _words(d)
    if wo and wc and wo[0] == wc[0]:
        return True
    if wd and wc and wd[0] == wc[0]:
        return True
    # parehong mahabang salita sa dalawang parte ("tatandaan" … "tatandaan")
    for a, b in ((wo, wc), (wo, wd), (wc, wd)):
        if {w for w in a if len(w) >= 6} & {w for w in b if len(w) >= 6}:
            return True
    for extra in (wo, wd):
        if len(extra) >= 2:
            common = sum(1 for w in extra if w in wc)
            if common / len(extra) >= 0.6:
                return True
    return False


def join(*parts):
    return " ".join(p for p in parts if p).strip()


def build_bucket(situation, lang, style, rng):
    fam = FAMILY[situation]
    cores_by = CORE[situation][lang]
    if style == "diretso" and "diretso" in cores_by:
        cores = cores_by["diretso"]
    elif situation == "styleSaved" and style in cores_by:
        cores = cores_by[style]
    else:
        cores = cores_by["all"]
    opens = OPEN[lang][style][fam]
    closes = CLOSE[lang][style][fam]

    out = []
    seen = set()

    def add(line):
        if line and line not in seen:
            seen.add(line)
            out.append(line)

    # 1) Bawat core, mag-isa (walang simula/dulo) — para laging may linyang walang {name}.
    for c in cores:
        add(c)
    # 2) Lahat ng kombinasyon, random na pagkakasunod, hanggang CAP.
    combos = [(o, c, d) for o in opens for c in cores for d in closes]
    rng.shuffle(combos)
    for o, c, d in combos:
        if len(out) >= CAP[style]:
            break
        # walang dobleng {name} sa isang linya
        if ("{name}" in o) + ("{name}" in c) + ("{name}" in d) > 1:
            continue
        if clash(o, c, d):
            continue
        add(join(o, c, d))
    return out


def main():
    rng = random.Random(20261124)
    data = {"version": 1, "lines": {}}
    total = 0
    for situation in CORE:
        data["lines"][situation] = {}
        for lang in LANGS:
            data["lines"][situation][lang] = {}
            for style in STYLES:
                if situation == "styleSaved" and style == "default":
                    lines = build_bucket(situation, lang, "default", rng)
                else:
                    lines = build_bucket(situation, lang, style, rng)
                data["lines"][situation][lang][style] = lines
                total += len(lines)
    data["count"] = total
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    path = os.path.join(root, "assets", "prompts", "companion_lines.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"{total} lines → {path}")


if __name__ == "__main__":
    main()