// Small helpers for the Dropbox-backed todo list.
function parseTodos(raw) {
    var todos = []
    try {
        var parsed = JSON.parse(String(raw || "[]"))
        if (!Array.isArray(parsed)) return todos
        for (var i = 0; i < parsed.length; ++i) {
            var item = parsed[i]
            if (!item || typeof item.title !== "string") continue
            var title = item.title.replace(/^\s+|\s+$/g, "")
            if (title === "") continue
            todos.push({
                title: title,
                completed: item.completed === true
            })
        }
    } catch (e) {
        return []
    }
    // Preserve the saved order exactly; users arrange tasks by dragging them.
    return todos
}

if (typeof module !== "undefined") {
    module.exports = { parseTodos: parseTodos }
}
