const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const panel = fs.readFileSync(path.join(root, "Panel.qml"), "utf8");
const barWidget = fs.readFileSync(path.join(root, "BarWidget.qml"), "utf8");

function includes(source, fragment) {
  assert.equal(source.includes(fragment), true, `missing UI contract: ${fragment}`);
}

test("panel keeps required plugin wiring", () => {
  includes(panel, 'moduleName: "tamayotchi.omado"');
  includes(panel, "readonly property string label:");
  includes(panel, 'property var anchorItem: null');
  includes(panel, 'property var hostWidget: null');
  includes(panel, 'path: root.todoPath');
  includes(panel, 'onLoaded: root.loadTodos(text())');
});

test("bar widget loads and injects panel dependencies", () => {
  includes(barWidget, 'source: Qt.resolvedUrl("Panel.qml")');
  includes(barWidget, "root.injectPanel()");
  includes(barWidget, "target.bar = root.bar");
  includes(barWidget, "target.anchorItem = button");
  includes(barWidget, "target.hostWidget = root");
  includes(barWidget, 'tooltipText: "Todo list"');
});

test("panel exposes core todo interactions", () => {
  for (const functionName of [
    "addTodo",
    "addTodoTitle",
    "toggleTodo",
    "removeTodo",
    "clearCompleted",
    "moveTodo",
    "startEdit",
    "commitEdit",
    "cancelEdit"
  ]) {
    includes(panel, `function ${functionName}(`);
  }

  includes(panel, "onClicked: root.addTodo()");
  includes(panel, "onClicked: root.removeTodo(todoDelegate.index)");
  includes(panel, "root.toggleTodo(todoDelegate.index)");
  includes(panel, "root.startEdit(todoDelegate.index)");
  includes(panel, "todoModel.move(fromIndex, toIndex, 1)");
  includes(panel, "DropArea");
  includes(panel, 'keys: ["omado-todo"]');
  includes(panel, "Drag.active: rowArea.drag.active");
  includes(panel, "drag.target: (pressedButtons & Qt.LeftButton) ? todoRow : null");
  includes(panel, "root.moveTodo(drop.source.index, todoDelegate.index)");
  includes(panel, 'text: "Clear completed"');
  assert.equal(panel.includes("A → Z"), false);
  assert.equal(panel.includes("Z → A"), false);
});

test("panel handles required keyboard actions", () => {
  for (const keyName of ["Qt.Key_Return", "Qt.Key_Enter", "Qt.Key_Escape", "Qt.Key_Tab", "Qt.Key_Backtab"]) {
    includes(panel, keyName);
  }

  includes(panel, "onCloseRequested: root.close()");
  includes(panel, "onTabRequested: function (direction)");
  includes(panel, "root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1)");
});

test("panel exposes the global Quick Add overlay", () => {
  includes(panel, "import Quickshell.Hyprland");
  includes(panel, "GlobalShortcut");
  includes(panel, 'appid: "tamayotchi.omado"');
  includes(panel, 'name: "quick-add"');
  includes(panel, "function openQuickAdd()");
  includes(panel, "function closeQuickAdd()");
  includes(panel, 'root.bar.findPanelWidget(root.moduleName)');
  includes(panel, "focusedWidget !== root.hostWidget");
  includes(panel, "root.close();");
  includes(panel, "WlrLayer.Overlay");
  includes(panel, "WlrKeyboardFocus.Exclusive");
  includes(panel, 'WlrLayershell.namespace: "tamayotchi-omado-quick-add"');
  includes(panel, 'text: "QUICK ADD"');
  includes(panel, "root.addTodoTitle(text)");
});

test("panel stores todos directly in Dropbox", () => {
  includes(panel, 'readonly property string todoPath: Quickshell.env("HOME") + "/Dropbox/PERSONAL/TODO.json"');
  assert.equal(panel.includes("stateDir"), false);
  assert.equal(panel.includes("dropboxReady"), false);
  assert.equal(panel.includes("storageReady"), false);
});

test("panel renders empty and remaining-task states", () => {
  includes(panel, 'text: "No tasks yet"');
  includes(panel, 'text: root.remaining + " remaining"');
  includes(panel, "visible: remaining < todoModel.count");
});
