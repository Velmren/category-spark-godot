# Category Spark

Trivia game made with Godot 4: six questions in three categories, instant feedback, a score and a new round.

![First question of a round](docs/screenshot.webp)

- Play in the browser: https://velmren.com/assets/godot/web/
- Windows build: https://velmren.com/assets/godot/CategorySpark-Windows-x64.zip
- Case page: https://velmren.com/en/godot/

## What it does

- Six fixed questions about sound, the web and space, loaded from `data/questions.json`. Answer positions vary between questions.
- After an answer, the correct row gets a green border and a check mark. A wrong choice gets a rose border and a cross, and the correct answer is revealed. The feedback text says the same thing, so colour is not the only signal.
- An accepted answer cannot be changed or scored twice. Next question stays disabled until an answer is given; after question six it becomes See results. Play again starts a new round.
- Mouse, keys 1 to 4, or Tab with Space and Enter. The Motion button turns off the 180 ms question fade.
- The layout follows the window size. It starts at 900x620. Windows lower than 500 px and at least 600 px wide put the answers in two columns; narrow and portrait windows keep a vertical list.
- If the question file is missing or invalid, the game shows a recovery message instead of starting a round.

There are no accounts, backend, online leaderboard, audio or localisation.

## Tech stack

Godot 4.7.2, GDScript, Compatibility renderer. The interface is built from native Control nodes in code (`scripts/main.gd`).

## Getting started

Prerequisites: [Godot 4.7.2](https://godotengine.org/download/). In the commands below, replace `godot` with the path to your Godot executable. On Windows, use the `_console.exe` build to see test output.

Run the game from the editor (open `project.godot` and press F5) or from the command line:

```sh
godot --path .
```

### Tests

Import the project once, then run the headless checks:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/import_check.gd
godot --headless --path . --script res://tests/gameplay_check.gd
```

`import_check.gd` loads the real question set and two broken files from `tests/` (a duplicate ID and a missing field) and expects specific error codes. `gameplay_check.gd` plays a round through the scene: scoring, the answer lock, round completion, the result screen, restart and the wrong-answer message. Both exit with code 1 on failure.

`tests/capture_run.gd` plays a round with real viewport mouse and keyboard events at a given window size, checks that controls stay inside the window and saves PNG captures. It needs a rendering window, so it does not run headless. Example in PowerShell:

```powershell
$env:CATEGORY_SPARK_CAPTURE_DIR = "$PWD/output/390x844"
$env:CATEGORY_SPARK_WIDTH = "390"
$env:CATEGORY_SPARK_HEIGHT = "844"
godot --path . --script res://tests/capture_run.gd
```

Set `CATEGORY_SPARK_RECORD=1` and add `--write-movie output/round.avi --fixed-fps 30` to record the run as video.

### Windows build

Install the Godot 4.7.2 export templates, then use the included preset. The target folder must exist:

```sh
mkdir output
godot --headless --path . --export-release "Windows Desktop" output/CategorySpark.exe
```

The result is a single x86_64 executable with the game data embedded. Tests and docs are excluded from the pack. The executable is not code-signed.

## Question format

`scripts/trivia_importer.gd` treats the JSON as data and validates it before the game uses it. The `format` field must be `velmren-trivia-v1`. Question IDs must be unique, prompts and options must be non-empty strings, and `correct_index` must be an integer inside the options list. A failed check returns a structured error such as `DUPLICATE_QUESTION_ID:<id>` or `MISSING_QUESTION_FIELD:<field>`.

## Project structure

```
scripts/          main.gd (UI, layout, input, scoring) and trivia_importer.gd (JSON validation)
data/             questions.json
assets/fonts/     Rajdhani Bold and its licence
tests/            headless checks, the capture runner and broken JSON fixtures
docs/             README screenshot; .gdignore keeps it out of the Godot import
main.tscn         main scene
export_presets.cfg  Windows Desktop export preset
```

## Credits

- Rajdhani Bold by Indian Type Foundry, SIL Open Font License 1.1, see `assets/fonts/Rajdhani-OFL.txt`.
- Built with [Godot Engine](https://godotengine.org/). Engine licence and third-party notices: https://godotengine.org/license/

## License

MIT, see [LICENSE](LICENSE).
