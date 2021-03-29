import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

import Cutefish.FileManager 1.0
import MeuiKit 1.0 as Meui

GridView {
    id: control

    property Item rubberBand: null
    property Item hoveredItem: null
    property Item pressedItem: null

    property int verticalDropHitscanOffset: 0

    property int pressX: -1
    property int pressY: -1

    property int dragX: -1
    property int dragY: -1

    property bool ctrlPressed: false
    property bool shiftPressed: false

    property int previouslySelectedItemIndex: -1
    property variant cPress: null
    property Item editor: null
    property int anchorIndex: 0

    property var itemSize: settings.gridIconSize

    property var itemWidth: itemSize + Meui.Units.largeSpacing
    property var itemHeight: itemSize + Meui.Units.fontMetrics.height * 2

    property variant cachedRectangleSelection: null

    property bool scrollLeft: false
    property bool scrollRight: false
    property bool scrollUp: false
    property bool scrollDown: false

    signal keyPress(var event)

    highlightMoveDuration: 0
    keyNavigationEnabled : true
    keyNavigationWraps : true
    Keys.onPressed: {
        if (event.key === Qt.Key_Control) {
            ctrlPressed = true
        } else if (event.key === Qt.Key_Shift) {
            shiftPressed = true

            if (currentIndex != -1)
                anchorIndex = currentIndex
        }

        control.keyPress(event)
    }
    Keys.onReleased: {
        if (event.key === Qt.Key_Control) {
            ctrlPressed = false
        } else if (event.key === Qt.Key_Shift) {
            shiftPressed = false
            anchorIndex = 0
        }
    }

    cellHeight: {
        // var extraHeight = calcExtraSpacing(itemHeight, control.height - topMargin - bottomMargin)
        return itemHeight // + extraHeight
    }

    cellWidth: {
        var extraWidth = calcExtraSpacing(itemWidth, control.width - leftMargin - rightMargin)
        return itemWidth + extraWidth
    }

    clip: true
    currentIndex: -1
    ScrollBar.vertical: ScrollBar {
        bottomPadding: Meui.Theme.mediumRadius
    }

    onPressXChanged: {
        cPress = mapToItem(control.contentItem, pressX, pressY)
    }

    onPressYChanged: {
        cPress = mapToItem(control.contentItem, pressX, pressY)
    }

    onCachedRectangleSelectionChanged: {
        if (cachedRectangleSelection === null)
            return

        if (cachedRectangleSelection.length)
            control.currentIndex[0]

        folderModel.updateSelection(cachedRectangleSelection, control.ctrlPressed)
    }

    MouseArea {
        id: _mouseArea
        anchors.fill: parent
        propagateComposedEvents: true
        preventStealing: true
        acceptedButtons: Qt.RightButton | Qt.LeftButton
        hoverEnabled: true
        enabled: true
        z: -1

        onDoubleClicked: {
            if (mouse.button === Qt.LeftButton && control.pressedItem)
                folderModel.openSelected()
        }

        onPressed: {
            control.forceActiveFocus()

//            if (mouse.source === Qt.MouseEventSynthesizedByQt) {
//                var index = control.indexAt(mouse.x, mouse.y)
//                var indexItem = control.itemAtIndex(index)
//                if (indexItem && indexItem.iconArea) {
//                    control.currentIndex = index
//                    hoveredItem = indexItem
//                } else {
//                    hoveredItem = null
//                }
//            }

            pressX = mouse.x
            pressY = mouse.y

            if (!hoveredItem || hoveredItem.blank) {
                if (!control.ctrlPressed) {
                    control.currentIndex = -1
                    previouslySelectedItemIndex = -1
                    folderModel.clearSelection()
                }

                if (mouse.buttons & Qt.RightButton) {
                    clearPressState()
                    folderModel.openContextMenu(null, mouse.modifiers)
                    mouse.accepted = true
                }
            } else {
                pressedItem = hoveredItem

                var pos = mapToItem(hoveredItem, mouse.x, mouse.y)

                if (control.shiftPressed && control.currentIndex !== -1) {
                    folderModel.setRangeSelected(control.anchorIndex, hoveredItem.index)
                } else {
                    if (!control.ctrlPressed && !folderModel.isSelected(hoveredItem.index)) {
                        previouslySelectedItemIndex = -1
                        folderModel.clearSelection()
                    }

                    if (control.ctrlPressed) {
                        folderModel.toggleSelected(hoveredItem.index)
                    } else {
                        folderModel.setSelected(hoveredItem.index)
                    }
                }

                control.currentIndex = hoveredItem.index

                if (mouse.buttons & Qt.RightButton) {
                    clearPressState()
                    folderModel.openContextMenu(null, mouse.modifiers)
                    mouse.accepted = true
                }
            }
        }

        onPositionChanged: {
            control.ctrlPressed = (mouse.modifiers & Qt.ControlModifier)
            control.shiftPressed = (mouse.modifiers & Qt.ShiftModifier)

            var cPos = mapToItem(control.contentItem, mouse.x, mouse.y)
            var item = control.itemAt(cPos.x, cPos.y)
            var leftEdge = Math.min(control.contentX, control.originX)

            if (!item || item.blank) {
                if (control.hoveredItem/* && !root.containsDrag*/) {
                    control.hoveredItem = null
                }
            } else {
                var fPos = mapToItem(item.iconArea, mouse.x, mouse.y)

                if (fPos.x < 0 || fPos.y < 0 || fPos.x > item.iconArea.width || fPos.y > item.iconArea.height) {
                    control.hoveredItem = null
                } else {
                    control.hoveredItem = item
                }
            }

            // Trigger autoscroll.
            if (pressX != -1) {
                control.scrollLeft = (mouse.x <= 0 && control.contentX > leftEdge);
                control.scrollRight = (mouse.x >= control.width
                    && control.contentX < control.contentItem.width - control.width);
                control.scrollUp = (mouse.y <= 0 && control.contentY > 0);
                control.scrollDown = (mouse.y >= control.height
                    && control.contentY < control.contentItem.height - control.height);
            }

            // Update rubberband geometry.
            if (control.rubberBand) {
                var rB = control.rubberBand

                if (cPos.x < cPress.x) {
                    rB.x = Math.max(leftEdge, cPos.x)
                    rB.width = Math.abs(rB.x - cPress.x)
                } else {
                    rB.x = cPress.x
                    var ceil = Math.max(control.width, control.contentItem.width) + leftEdge
                    rB.width = Math.min(ceil - rB.x, Math.abs(rB.x - cPos.x))
                }

                if (cPos.y < cPress.y) {
                    rB.y = Math.max(0, cPos.y)
                    rB.height = Math.abs(rB.y - cPress.y)
                } else {
                    rB.y = cPress.y
                    var ceil = Math.max(control.height, control.contentItem.height)
                    rB.height = Math.min(ceil - rB.y, Math.abs(rB.y - cPos.y))
                }

                // Ensure rubberband is at least 1px in size or else it will become
                // invisible and not match any items.
                rB.width = Math.max(1, rB.width)
                rB.height = Math.max(1, rB.height)

                control.rectangleSelect(rB.x, rB.y, rB.width, rB.height)

                return
            }

            if (pressX != -1) {
                if (pressedItem != null && folderModel.isSelected(pressedItem.index)) {
                    control.dragX = mouse.x
                    control.dragY = mouse.y
                    control.verticalDropHitscanOffset = pressedItem.y + (pressedItem.height / 2)
                    folderModel.dragSelected(mouse.x, mouse.y)
                    control.dragX = -1
                    control.dragY = -1
                    clearPressState()
                } else {
                    folderModel.pinSelection()
                    control.rubberBand = rubberBandObject.createObject(control.contentItem, {x: cPress.x, y: cPress.y})
                    control.interactive = false
                }
            }
        }

        onClicked: {
            clearPressState()

            if (mouse.button === Qt.RightButton)
                return

            if (!hoveredItem)
                return;

//            var pos = mapToItem(hoveredItem, mouse.x, mouse.y);
//            if (pos.x < 0 || pos.x > hoveredItem.width || pos.y < 0 || pos.y > hoveredItem.height) {
//                hoveredItem = null
//                previouslySelectedItemIndex = -1
//                folderModel.clearSelection()
//                return
//            }
        }

        onReleased: pressCanceled()
        onCanceled: pressCanceled()
    }

    function clearPressState() {
        pressedItem = null
        pressX = -1
        pressY = -1
    }

    function pressCanceled() {
        if (control.rubberBand) {
            control.rubberBand.close()
            control.rubberBand = null

            control.interactive = true
            // control.cachedRectangleSelection = null
            folderModel.unpinSelection()
        }

        clearPressState()
    }

    function rectangleSelect(x, y, width, height) {
        var rows = (control.flow === GridView.FlowLeftToRight)
        var axis = rows ? control.width : control.height
        var step = rows ? cellWidth : cellHeight
        var perStripe = Math.floor(axis / step)
        var stripes = Math.ceil(control.count / perStripe)
        var cWidth = control.cellWidth - (2 * Meui.Units.smallSpacing)
        var cHeight = control.cellHeight - (2 * Meui.Units.smallSpacing)
        var midWidth = control.cellWidth / 2
        var midHeight = control.cellHeight / 2
        var indices = []

        for (var s = 0; s < stripes; s++) {
            for (var i = 0; i < perStripe; i++) {
                var index = (s * perStripe) + i

                if (index >= control.count) {
                    break
                }

                if (folderModel.isBlank(index)) {
                    continue
                }

                var itemX = ((rows ? i : s) * control.cellWidth)
                var itemY = ((rows ? s : i) * control.cellHeight)

                if (control.effectiveLayoutDirection === Qt.RightToLeft) {
                    itemX -= (rows ? control.contentX : control.originX)
                    itemX += cWidth
                    itemX = (rows ? control.width : control.contentItem.width) - itemX
                }

                // Check if the rubberband intersects this cell first to avoid doing more
                // expensive work.
                if (control.rubberBand.intersects(Qt.rect(itemX + Meui.Units.smallSpacing, itemY + Meui.Units.smallSpacing,
                    cWidth, cHeight))) {
                    var item = control.contentItem.childAt(itemX + midWidth, itemY + midHeight)

                    // If this is a visible item, check for intersection with the actual
                    // icon or label rects for better feel.
                    if (item && item.iconArea) {
                        var iconRect = Qt.rect(itemX + item.iconArea.x, itemY + item.iconArea.y,
                            item.iconArea.width, item.iconArea.height)

                        if (control.rubberBand.intersects(iconRect)) {
                            indices.push(index)
                            continue
                        }

                        var labelRect = Qt.rect(itemX + item.textArea.x, itemY + item.textArea.y,
                            item.textArea.width, item.textArea.height)

                        if (control.rubberBand.intersects(labelRect)) {
                            indices.push(index)
                            continue
                        }
                    } else {
                        // Otherwise be content with the cell intersection.
                        indices.push(index)
                    }
                }
            }
        }

        control.cachedRectangleSelection = indices
    }

    function calcExtraSpacing(cellSize, containerSize) {
        var availableColumns = Math.floor(containerSize / cellSize)
        var extraSpacing = 0
        if (availableColumns > 0) {
            var allColumnSize = availableColumns * cellSize
            var extraSpace = Math.max(containerSize - allColumnSize, Meui.Units.smallSpacing)
            extraSpacing = extraSpace / availableColumns
        }
        return Math.floor(extraSpacing)
    }
}
