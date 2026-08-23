import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root
    moduleName: "tamayotchi.omado"

    property var anchorItem: null
    property var hostWidget: null
    readonly property var barIdentity: hostWidget || root
    readonly property string label: ""
    property int remaining: 0

    // Index of the row being edited (-1 = none), plus the TextField holding
    // it so switching to another row can flush the pending text first.
    property int editingIndex: -1
    property var activeEditor: null
    property bool quickAddOpen: false

    readonly property string todoPath: Quickshell.env("HOME") + "/Dropbox/TODO.json"

    ListModel {
        id: todoModel
    }

    function openFromHotkey() {
        root.controller.show();
        Qt.callLater(function () {
            if (root.opened)
                root.setCenterHoverRevealSuppressed(true);
        });
    }

    function close() {
        // The panel stays mapped through its fade-out, so the editor's
        // focus-loss handler cannot be relied on here.
        flushEdit();
        setCenterHoverRevealSuppressed(false);
        root.controller.hide();
    }

    function toggle() {
        if (root.opened)
            root.close();
        else
            root.openFromHotkey();
    }

    function closeForPopoutSwitch() {
        root.close();
    }

    function openQuickAdd() {
        // Each monitor has its own bar-widget instance. Let the bar choose
        // the instance on the focused monitor, then open only that overlay.
        var focusedWidget = root.bar && typeof root.bar.findPanelWidget === "function"
            ? root.bar.findPanelWidget(root.moduleName) : null;
        if (!focusedWidget || focusedWidget !== root.hostWidget)
            return;

        // Keep the quick-add overlay as the only active panel, so one Escape
        // always closes the menu instead of revealing the todo panel beneath it.
        if (root.opened)
            root.close();
        root.quickAddOpen = true;
        Qt.callLater(function () {
            if (root.quickAddOpen) {
                quickAddField.forceActiveFocus();
                quickAddField.selectAll();
            }
        });
    }

    function closeQuickAdd() {
        root.quickAddOpen = false;
        quickAddField.clear();
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.barIdentity, direction);
        return false;
    }

    function setCenterHoverRevealSuppressed(value) {
        if (root.bar && "centerHoverRevealSuppressed" in root.bar)
            root.bar.centerHoverRevealSuppressed = value;
    }

    function recount() {
        var n = 0;
        for (var i = 0; i < todoModel.count; ++i)
            if (!todoModel.get(i).completed)
                n++;
        remaining = n;
    }

    function loadTodos(raw) {
        var todos = Model.parseTodos(raw);
        todoModel.clear();
        for (var i = 0; i < todos.length; ++i)
            todoModel.append(todos[i]);
        recount();
    }

    function saveTodos() {
        var todos = [];
        for (var i = 0; i < todoModel.count; ++i) {
            var item = todoModel.get(i);
            todos.push({
                title: item.title,
                completed: item.completed
            });
        }
        todoFile.setText(JSON.stringify(todos, null, 2) + "\n");
    }

    function cancelEdit() {
        root.editingIndex = -1;
    }

    function flushEdit() {
        if (root.editingIndex >= 0 && root.activeEditor)
            root.commitEdit(root.editingIndex, root.activeEditor.text);
        root.editingIndex = -1;
    }

    // Right-click entry point. Any row already being edited is committed
    // first; otherwise its text is dropped when the delegate loses focus.
    function startEdit(index) {
        if (index < 0 || index >= todoModel.count)
            return;
        if (root.editingIndex !== index)
            flushEdit();
        root.editingIndex = index;
    }

    // editingIndex is cleared before saveTodos(): the save round-trips
    // through FileView and rebuilds the model, destroying the editor.
    function commitEdit(index, text) {
        var title = String(text).replace(/^\s+|\s+$/g, "");
        root.editingIndex = -1;
        if (index < 0 || index >= todoModel.count)
            return;
        if (title === "" || title === todoModel.get(index).title)
            return;
        todoModel.setProperty(index, "title", title);
        saveTodos();
    }

    function addTodoTitle(text) {
        root.cancelEdit();
        var title = String(text).replace(/^\s+|\s+$/g, "");
        if (title === "")
            return false;
        todoModel.insert(0, {
            title: title,
            completed: false
        });
        saveTodos();
        recount();
        return true;
    }

    function addTodo() {
        if (!root.addTodoTitle(todoField.text))
            return;
        todoField.clear();
        todoField.forceActiveFocus();
    }

    function toggleTodo(index) {
        root.cancelEdit();
        if (index < 0 || index >= todoModel.count)
            return;
        var completed = !todoModel.get(index).completed;
        todoModel.setProperty(index, "completed", completed);
        saveTodos();
        recount();
    }

    function moveTodo(fromIndex, toIndex) {
        root.cancelEdit();
        if (fromIndex < 0 || fromIndex >= todoModel.count
                || toIndex < 0 || toIndex >= todoModel.count
                || fromIndex === toIndex)
            return;
        todoModel.move(fromIndex, toIndex, 1);
        saveTodos();
    }

    function removeTodo(index) {
        root.cancelEdit();
        if (index < 0 || index >= todoModel.count)
            return;
        todoModel.remove(index);
        saveTodos();
        recount();
    }

    function clearCompleted() {
        root.cancelEdit();
        var removed = false;
        for (var i = todoModel.count - 1; i >= 0; --i) {
            if (todoModel.get(i).completed) {
                todoModel.remove(i);
                removed = true;
            }
        }
        if (removed) {
            saveTodos();
            recount();
        }
    }

    FileView {
        id: todoFile
        path: root.todoPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadTodos(text())
        onLoadFailed: root.loadTodos("[]")
        onFileChanged: reload()
    }

    GlobalShortcut {
        appid: "tamayotchi.omado"
        name: "quick-add"
        onPressed: root.openQuickAdd()
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: false
        focusTarget: todoField
        contentWidth: panel.fittedContentWidth(Style.space(440))
        contentHeight: panel.fittedContentHeight(todoColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: todoField.activeFocus || root.editingIndex >= 0
            onCloseRequested: root.close()
            onTabRequested: function (direction) {
                root.switchPanel(direction);
            }

            Flickable {
                id: todoScroll
                anchors.fill: parent
                contentWidth: width
                contentHeight: todoColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: todoColumn
                    width: todoScroll.width
                    spacing: Style.space(12)

                    Row {
                        width: parent.width
                        leftPadding: Style.space(16)
                        rightPadding: Style.space(16)
                        spacing: Style.space(10)

                        Text {
                            text: root.label
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.display
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: Style.space(2)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "TODO LIST"
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.title
                                font.bold: true
                            }
                            Text {
                                text: root.remaining + " remaining"
                                color: Qt.darker(root.bar.foreground, 1.5)
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.bodySmall
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        leftPadding: Style.space(16)
                        rightPadding: Style.space(16)
                        spacing: Style.space(8)

                        TextField {
                            id: todoField
                            width: parent.width - Style.space(80)
                            placeholderText: "Add a task…"
                            foreground: root.bar.foreground
                            font.family: root.bar.fontFamily

                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.addTodo();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.close();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1);
                                    event.accepted = true;
                                }
                            }
                        }

                        Rectangle {
                            width: Style.space(40)
                            height: todoField.height
                            radius: Style.cornerRadius
                            color: addArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.title
                            }

                            MouseArea {
                                id: addArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addTodo()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - Style.space(32)
                        x: Style.space(16)
                        height: Style.spacing.hairline
                        color: root.bar.foreground
                        opacity: 0.12
                    }

                    ListView {
                        id: todoList
                        width: parent.width
                        height: Math.max(Style.space(48), contentHeight)
                        interactive: false
                        model: todoModel
                        spacing: Style.space(4)

                        delegate: Item {
                            id: todoDelegate
                            required property int index
                            required property string title
                            required property bool completed

                            readonly property bool editing: root.editingIndex === index

                            width: todoList.width - Style.space(32)
                            x: Style.space(16)
                            height: Style.space(46)
                            z: todoRow.Drag.active ? 100 : 0

                            DropArea {
                                anchors.fill: parent
                                keys: ["omado-todo"]

                                onDropped: function (drop) {
                                    if (!drop.source || drop.source === todoDelegate)
                                        return;
                                    root.moveTodo(drop.source.index, todoDelegate.index);
                                    drop.accept(Qt.MoveAction);
                                }
                            }

                            Rectangle {
                                id: todoRow
                                width: parent.width
                                height: parent.height
                                anchors.centerIn: rowArea.drag.active ? undefined : parent
                                radius: Style.cornerRadius
                                color: rowArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

                                Drag.active: rowArea.drag.active
                                Drag.source: todoDelegate
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2
                                Drag.keys: ["omado-todo"]
                                Drag.supportedActions: Qt.MoveAction

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.space(12)
                                    anchors.rightMargin: Style.space(8)
                                    spacing: Style.space(10)

                                    Text {
                                        text: todoDelegate.completed ? "󰄲" : "󰄱"
                                        color: todoDelegate.completed ? Color.accent : root.bar.foreground
                                        font.family: root.bar.fontFamily
                                        font.pixelSize: Style.font.title
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        visible: !todoDelegate.editing
                                        id: titleText
                                        width: parent.width - Style.space(72)
                                        text: todoDelegate.title
                                        color: todoDelegate.completed ? Qt.darker(root.bar.foreground, 1.6) : root.bar.foreground
                                        font.family: root.bar.fontFamily
                                        font.pixelSize: Style.font.body
                                        font.strikeout: todoDelegate.completed
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter

                                        PanelToolTip {
                                            visible: rowArea.containsMouse && titleText.truncated
                                            text: todoDelegate.title
                                            fontFamily: root.bar.fontFamily
                                        }
                                    }

                                    TextField {
                                        id: editField
                                        visible: todoDelegate.editing
                                        width: parent.width - Style.space(72)
                                        foreground: root.bar.foreground
                                        font.family: root.bar.fontFamily
                                        verticalPadding: Style.space(2)
                                        anchors.verticalCenter: parent.verticalCenter

                                        function beginEdit() {
                                            root.activeEditor = editField;
                                            text = todoDelegate.title;
                                            forceActiveFocus();
                                            selectAll();
                                        }

                                        // A save rebuilds the model, so a delegate can be
                                        // created with editing already true, in which case
                                        // onVisibleChanged never fires.
                                        Component.onCompleted: if (visible)
                                            Qt.callLater(beginEdit)
                                        onVisibleChanged: if (visible)
                                            beginEdit()

                                        // Clicking away keeps the edit rather than dropping
                                        // it. commitEdit() clears editingIndex first, so
                                        // this cannot recurse.
                                        onActiveFocusChanged: {
                                            if (!activeFocus && todoDelegate.editing)
                                                root.commitEdit(todoDelegate.index, editField.text);
                                        }

                                        Keys.onPressed: function (event) {
                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                root.commitEdit(todoDelegate.index, editField.text);
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Escape) {
                                                root.cancelEdit();
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                                event.accepted = true;
                                            }
                                        }
                                    }

                                }

                                Rectangle {
                                    id: trashButton
                                    width: Style.space(32)
                                    height: Style.space(32)
                                    x: parent.width - width - Style.space(8)
                                    y: (parent.height - height) / 2
                                    z: 10
                                    radius: Style.cornerRadius
                                    color: trashArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        color: trashArea.containsMouse ? Color.accent : Qt.darker(root.bar.foreground, 1.4)
                                        font.family: root.bar.fontFamily
                                        font.pixelSize: Style.font.body
                                    }

                                    MouseArea {
                                        id: trashArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeTodo(todoDelegate.index)
                                    }
                                }

                                MouseArea {
                                    id: rowArea
                                    property bool wasDragged: false

                                    anchors.fill: parent
                                    anchors.rightMargin: Style.space(48)
                                    z: -1
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    drag.target: (pressedButtons & Qt.LeftButton) ? todoRow : null
                                    drag.axis: Drag.YAxis

                                    onPressed: wasDragged = false
                                    onPositionChanged: if (drag.active)
                                        wasDragged = true
                                    onReleased: if (todoRow.Drag.active)
                                        todoRow.Drag.drop()

                                    onClicked: function (mouse) {
                                        if (wasDragged)
                                            return;
                                        if (mouse.button === Qt.RightButton)
                                            root.startEdit(todoDelegate.index);
                                        else
                                            root.toggleTodo(todoDelegate.index);
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: todoModel.count === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No tasks yet"
                        color: Qt.darker(root.bar.foreground, 1.5)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.body
                        font.italic: true
                    }

                    Row {
                        visible: remaining < todoModel.count
                        width: parent.width
                        leftPadding: Style.space(16)
                        rightPadding: Style.space(16)

                        Text {
                            text: "Clear completed"
                            color: clearArea.containsMouse ? Color.accent : Qt.darker(root.bar.foreground, 1.4)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.bodySmall

                            MouseArea {
                                id: clearArea
                                anchors.fill: parent
                                anchors.margins: -Style.space(6)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearCompleted()
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: quickAddWindow
        screen: root.bar ? root.bar.screen : null
        visible: root.quickAddOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "tamayotchi-omado-quick-add"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeQuickAdd()
            }

            Rectangle {
                id: quickAddCard
                anchors.centerIn: parent
                width: Math.min(parent.width - Style.space(48), Style.space(520))
                height: quickAddColumn.implicitHeight + Style.space(40)
                radius: Style.cornerRadius * 2
                color: Color.popups.background
                border.color: Color.accent
                border.width: Style.normalBorderWidth

                Column {
                    id: quickAddColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Style.space(20)
                    }
                    spacing: Style.space(10)

                    Text {
                        text: "QUICK ADD"
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.title
                        font.bold: true
                    }

                    TextField {
                        id: quickAddField
                        width: parent.width
                        placeholderText: "Add a task…"
                        foreground: root.bar.foreground
                        font.family: root.bar.fontFamily

                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.addTodoTitle(text))
                                    root.closeQuickAdd();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.closeQuickAdd();
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        text: "Enter to add · Esc to close"
                        color: Qt.darker(root.bar.foreground, 1.5)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.bodySmall
                    }
                }
            }
        }
    }
}
