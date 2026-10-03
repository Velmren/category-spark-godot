extends RefCounted
# Interface text in every language the game speaks. Questions carry their own
# translations in data/questions.json.

# Order of the language switch.
const LANGUAGES := ["ru", "en"]

const TEXT := {
    "en": {
        "score": "Score",
        "sound_on": "Sound on",
        "sound_off": "Sound off",
        "motion_on": "Motion on",
        "motion_off": "Motion off",
        "hint": "Pick an answer, or press 1 to 4",
        "correct": "Correct!",
        "point": "+1 point",
        "wrong": "Not quite",
        "answer_is": "The answer is %s.",
        "next": "Next question",
        "results": "See results",
        "again": "Play again",
        "round_complete": "ROUND COMPLETE",
        "perfect": "Perfect spark!",
        "good": "Nicely played!",
        "low": "Keep the spark alive",
        "unavailable": "QUESTIONS UNAVAILABLE",
        "unavailable_title": "The question set could not be opened.",
        "unavailable_note": "Restore data/questions.json and reopen the game.",
    },
    "ru": {
        "score": "Счёт",
        "sound_on": "Звук вкл",
        "sound_off": "Звук выкл",
        "motion_on": "Анимация вкл",
        "motion_off": "Анимация выкл",
        "hint": "Выберите ответ или нажмите цифру от 1 до 4",
        "correct": "Верно!",
        "point": "+1 очко",
        "wrong": "Мимо",
        "answer_is": "Правильный ответ: %s.",
        "next": "Следующий вопрос",
        "results": "Показать итог",
        "again": "Сыграть ещё",
        "round_complete": "РАУНД ЗАВЕРШЁН",
        "perfect": "Идеальный раунд!",
        "good": "Хорошо сыграно!",
        "low": "Попробуйте ещё раз",
        "unavailable": "ВОПРОСЫ НЕДОСТУПНЫ",
        "unavailable_title": "Не удалось открыть вопросы.",
        "unavailable_note": "Верните файл data/questions.json и перезапустите игру.",
    },
}

const EN_NUMBERS := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
# Russian numerals in the prepositional case: «в трёх категориях».
const RU_NUMBERS := ["нуле", "одной", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти", "десяти"]

static func get_text(language: String, key: String) -> String:
    return TEXT.get(language, TEXT.en).get(key, TEXT.en[key])

# "5 correct answers across three categories." with the right plural forms.
static func summary(language: String, correct: int, categories: int) -> String:
    if language == "ru":
        var answers := "верный ответ" if _ru_form(correct) == 0 else ("верных ответа" if _ru_form(correct) == 1 else "верных ответов")
        var where: String = RU_NUMBERS[categories] if categories < RU_NUMBERS.size() else str(categories)
        return "%d %s в %s %s." % [correct, answers, where, "категории" if categories == 1 else "категориях"]
    var count: String = EN_NUMBERS[categories] if categories < EN_NUMBERS.size() else str(categories)
    return "%d correct %s across %s %s." % [correct, "answer" if correct == 1 else "answers", count, "category" if categories == 1 else "categories"]

# 0: один ответ, 1: два ответа, 2: пять ответов.
static func _ru_form(count: int) -> int:
    if count % 10 == 1 and count % 100 != 11:
        return 0
    if count % 10 >= 2 and count % 10 <= 4 and (count % 100 < 12 or count % 100 > 14):
        return 1
    return 2
