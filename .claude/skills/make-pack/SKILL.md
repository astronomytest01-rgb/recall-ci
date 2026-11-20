---
name: make-pack
description: Turn a folder of Markdown notes (any repo) into a Recall study pack — a JSON file of quiz and flash cards. Use when the user asks to add a repo, folder or document to Recall, regenerate a pack, or "сделай карточки / пак из …".
---

# make-pack

Recall is a local iOS study app. Content lives in packs: one JSON file per pack in `Recall/Packs/`.

1. Read `tools/PACK_FORMAT.md` and follow it exactly.
2. Cards hold only durable general knowledge (see «Что брать в карточки» in the spec): no people, who-said-what, meetings, dates, ticket keys or counts, volatile numbers, identifiers. Organize packs by theme (product, rules, metrics, user psychology, decisions with arguments, processes), not by source file. Read the source files fully. Split big sources between subagents, one pack per subagent (≈100–160 cards each), and give every subagent the format spec path and the validation command below.
3. Pack ids: `<repo>-<area>`, kebab-case. Keep card ids stable when regenerating so progress survives.
4. Validate every file:
   `python3 tools/validate_packs.py Recall/Packs/*.json`
5. Bundled pack → rebuild and reinstall the app. Quick path without a rebuild: AirDrop or Files the JSON to the phone, then Recall → Настройки → Импортировать пак.
6. Never put credentials, tokens or private test logins into cards.
