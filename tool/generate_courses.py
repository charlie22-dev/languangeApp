"""Build bundled beginner courses from reviewed, UTF-8 pipe-delimited sources.

Run from the project root. --check validates reproducibility without writing.
Japanese is intentionally not regenerated: its published IDs remain unchanged.
"""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {
    "spanish": ("es", "Spanish", "es-ES"),
    "french": ("fr", "French", "fr-FR"),
    "german": ("de", "German", "de-DE"),
    "italian": ("it", "Italian", "it-IT"),
    "portuguese": ("pt", "Portuguese", "pt-BR"),
}
THEMES = ["Greetings", "People", "Numbers", "Food", "Places", "Actions"]


def build_course(slug):
    prefix, language, locale = LANGUAGES[slug]
    source = ROOT / "tool" / "course_sources" / f"{slug}.txt"
    rows = [line.split("|") for line in source.read_text(encoding="utf-8").splitlines()]
    if len(rows) != 60 or any(len(row) != 4 or any(not x.strip() for x in row) for row in rows):
        raise ValueError(f"{source}: expected 60 complete four-field rows")
    words = []
    for i, (text, translation, example, example_translation) in enumerate(rows):
        word_id = prefix + "_" + re.sub(r"[^a-z0-9]+", "_", translation.lower()).strip("_")
        words.append({
            "id": word_id, "text": text, "translation": translation,
            "example": example, "exampleTranslation": example_translation,
            "tags": ["beginner", THEMES[i // 10].lower()],
        })
    if len({w["id"] for w in words}) != 60:
        raise ValueError(f"Duplicate word IDs in {source}")
    units = []
    for group, theme in enumerate(THEMES):
        lesson_id = f"{prefix}_{theme.lower()}"
        batch = words[group * 10:(group + 1) * 10]
        exercises = []

        def add(kind, **fields):
            exercises.append({"id": f"{lesson_id}_{len(exercises) + 1}", "type": kind, **fields})

        def choices(index, field):
            options = [batch[(index + offset) % 10][field] for offset in range(4)]
            shift = (group + index) % 4
            return options[shift:] + options[:shift]

        for index in (0, 1):
            options = choices(index, "translation")
            add("multipleChoice", prompt=f'What does “{batch[index]["text"]}” mean?',
                options=options, correctIndex=options.index(batch[index]["translation"]))
        add("matchPairs", pairs=[{"left": w["text"], "right": w["translation"]} for w in batch[2:5]])
        for index in (5, 6):
            word = batch[index]
            sentence, count = re.subn(re.escape(word["text"]), "___", word["example"], count=1, flags=re.IGNORECASE)
            if count != 1:
                raise ValueError(f'Example must contain {word["text"]}')
            add("fillInBlank", sentenceWithBlank=sentence, answer=word["text"], choices=choices(index, "text"))
        add("typeTranslation", prompt=f'Translate into {language}: {batch[7]["translation"]}', acceptedAnswers=[batch[7]["text"]])
        add("listening", audioText=batch[8]["text"], acceptedAnswers=[batch[8]["text"]], options=choices(8, "text"))
        add("speaking", phrase=batch[9]["text"], minimumScore=0.8)
        if group % 3 == 0:
            number = len(units) + 1
            units.append({"id": f"{prefix}_unit_{number}", "title": "First Steps" if number == 1 else "Everyday Life", "lessons": []})
        units[-1]["lessons"].append({"id": lesson_id, "title": theme, "wordIds": [w["id"] for w in batch], "exercises": exercises})
    return {"schemaVersion": 1, "id": f"{prefix}_basics_en", "title": f"{language} Basics",
            "targetLanguage": language, "nativeLanguage": "English", "targetLocale": locale,
            "words": words, "units": units}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for slug in LANGUAGES:
        content = json.dumps(build_course(slug), ensure_ascii=False, indent=2) + "\n"
        asset = ROOT / "assets" / "courses" / f"{slug}_basics.json"
        if args.check:
            if asset.read_text(encoding="utf-8") != content:
                raise SystemExit(f"Out of date: {asset.relative_to(ROOT)}")
        else:
            asset.write_text(content, encoding="utf-8", newline="\n")
        print(f"{slug}: 60 words, 6 lessons, 48 exercises")


if __name__ == "__main__":
    main()
