class_name TriviaImporter
extends RefCounted

# v2 holds every language in one file; v1 files (plain strings) are still read
# as single-language English sets.
const FORMAT := "velmren-trivia-v2"
const FORMAT_V1 := "velmren-trivia-v1"

static func load_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return _fail("FILE_NOT_FOUND")
    var text := FileAccess.get_file_as_string(path)
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return _fail("ROOT_MUST_BE_OBJECT")
    return validate(parsed)

static func validate(root: Dictionary) -> Dictionary:
    var languages: Array = []
    match root.get("format"):
        FORMAT_V1:
            languages = ["en"]
        FORMAT:
            languages = root.get("languages", [])
            if typeof(languages) != TYPE_ARRAY or languages.is_empty():
                return _fail("LANGUAGES_REQUIRED")
            for language in languages:
                if not _nonempty_string(language) or languages.count(language) > 1:
                    return _fail("LANGUAGES_REQUIRED")
        _:
            return _fail("UNSUPPORTED_FORMAT")
    if not root.has("categories") or typeof(root.categories) != TYPE_ARRAY or root.categories.is_empty():
        return _fail("CATEGORIES_REQUIRED")

    var category_ids := {}
    var question_ids := {}
    var normalized: Array = []

    for category_value in root.categories:
        if typeof(category_value) != TYPE_DICTIONARY:
            return _fail("CATEGORY_MUST_BE_OBJECT")
        var category: Dictionary = category_value
        var missing := _first_missing(category, ["id", "label", "questions"])
        if missing != "":
            return _fail("MISSING_CATEGORY_FIELD:" + missing)
        if not _nonempty_string(category.id):
            return _fail("INVALID_CATEGORY_TEXT")
        var label = _localized(category.label, languages, category.id, "INVALID_CATEGORY_TEXT")
        if label is String:
            return _fail(label)
        if category_ids.has(category.id):
            return _fail("DUPLICATE_CATEGORY_ID:" + category.id)
        category_ids[category.id] = true
        if typeof(category.questions) != TYPE_ARRAY or category.questions.is_empty():
            return _fail("QUESTIONS_REQUIRED:" + category.id)

        var questions: Array = []
        for question_value in category.questions:
            if typeof(question_value) != TYPE_DICTIONARY:
                return _fail("QUESTION_MUST_BE_OBJECT:" + category.id)
            var question: Dictionary = question_value
            missing = _first_missing(question, ["id", "prompt", "options", "correct_index"])
            if missing != "":
                return _fail("MISSING_QUESTION_FIELD:" + missing)
            if not _nonempty_string(question.id):
                return _fail("INVALID_QUESTION_TEXT")
            var prompt = _localized(question.prompt, languages, question.id, "INVALID_QUESTION_TEXT")
            if prompt is String:
                return _fail(prompt)
            if question_ids.has(question.id):
                return _fail("DUPLICATE_QUESTION_ID:" + question.id)
            question_ids[question.id] = true
            if typeof(question.options) != TYPE_ARRAY or question.options.size() < 2:
                return _fail("OPTIONS_REQUIRED:" + question.id)
            var options: Array = []
            for option in question.options:
                var text = _localized(option, languages, question.id, "INVALID_OPTION:" + question.id)
                if text is String:
                    return _fail(text)
                options.append(text)
            if typeof(question.correct_index) != TYPE_FLOAT and typeof(question.correct_index) != TYPE_INT:
                return _fail("INVALID_CORRECT_INDEX:" + question.id)
            var answer_index := int(question.correct_index)
            if float(answer_index) != float(question.correct_index) or answer_index < 0 or answer_index >= question.options.size():
                return _fail("INVALID_CORRECT_INDEX:" + question.id)
            questions.append({
                "id": String(question.id),
                "prompt": prompt,
                "options": options,
                "correct_index": answer_index,
                "category_id": String(category.id),
                "category_label": label
            })
        normalized.append({"id": String(category.id), "label": label, "questions": questions})

    return {"ok": true, "error": "", "data": {"format": root.format, "languages": languages.duplicate(), "categories": normalized}}

# A text is either one string used in every language (names such as HTTPS) or an
# object with a non-empty string for each language. Returns {language: text}, or
# an error code as a String.
static func _localized(value, languages: Array, owner: String, plain_error: String):
    if typeof(value) == TYPE_STRING:
        if not _nonempty_string(value):
            return plain_error
        var same := {}
        for language in languages:
            same[language] = String(value)
        return same
    if typeof(value) != TYPE_DICTIONARY:
        return plain_error
    var texts := {}
    for language in languages:
        if not value.has(language):
            return "MISSING_TRANSLATION:%s:%s" % [owner, language]
        if not _nonempty_string(value[language]):
            return "INVALID_TRANSLATION:%s:%s" % [owner, language]
        texts[language] = String(value[language])
    return texts

static func _first_missing(value: Dictionary, fields: Array) -> String:
    for field in fields:
        if not value.has(field):
            return String(field)
    return ""

static func _nonempty_string(value) -> bool:
    return typeof(value) == TYPE_STRING and not String(value).strip_edges().is_empty()

static func _fail(message: String) -> Dictionary:
    return {"ok": false, "error": message, "data": {}}
