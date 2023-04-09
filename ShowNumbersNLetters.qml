import QtQuick 2.2
import QtQuick.Dialogs 1.0
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1
import MuseScore 3.0
import FileIO 3.0

MuseScore {
    menuPath: "Plugins.ShowNumbersNLetters"
    description: "Show numbers or letters for brass instrument notes"
    version: "1.0"
    requiresScore: true
    pluginType: "dock"
    id: window

    property var output
    property string letterMappingFilePath : "mappings/letters_mapping_default_de.json"
    property var lettersMapping
    property string numberMappingFilePath : "mappings/numbers_mapping_default.json"
    property var numbersMapping
    property var updating: false

    onRun: {
        processMappings()
    }
    onScoreStateChanged: {
        //updateAll()
    }
    function showObject(oObject) {
        //  PURPOSE: Lists all key -> value pairs to the console.
        //  NOTE: To reduce clutter I am filtering out any 
        //'undefined' properties. (The MuseScore 'element' object
        //is very flat - it will show many, many properties for any
        //given element type; but for any given element many, if not 
        //most of these properties will return 'undefined' as they 
        //are not all valid for all element types. If you want to see 
        //this comment out the filter.)
        
        if (Object.keys(oObject).length >0) {
            Object.keys(oObject)
            .filter(function(key) {
                return oObject[key] != null;
            })
            .sort()
            .forEach(function eachKey(key) {
                console.log("---- ---- ", key, " : <", oObject[key], ">");
            });
        }
    }

    function removeAllStaffs() {
        console.log("remove all staffs")
        var cursor = curScore.newCursor()

        for (var i=0; i<curScore.nstaves; i++) {
            cursor.rewind(0)
            cursor.voice = 0
            cursor.staffIdx = i

            while (cursor.segment) {
                removeNoteText(cursor)
                cursor.next()
            }
        }
    }

    function updateStaff(staffIndex) {
        console.log("update staff "+staffIndex)
        var cursor = curScore.newCursor()

        var staff = getStaffFromInd(staffIndex)

        if (!staff.part.hasPitchedStaff) {
            return
        }

        cursor.voice = 0
        cursor.staffIdx = staffIndex
        cursor.rewind(0)

        // brass.trombone, brass.euphonium, brass.sousaphone, brass.trumpet
        var instrumentId = staff.part.instruments[0].instrumentId
        console.log("instrumentId "+instrumentId)

        var instInd = numbersMapping["instrumentIds"].findIndex(function(e) {return e==instrumentId})
        if (instInd==-1) {
            instInd = 0
        }

        var last_text = ""

        while (cursor.segment) {
            if (cursor.element.type == Element.CHORD) {
                var notes = cursor.element.notes
                var lowestNote
                var lowestPitch = 1000
                for (var i=0; i<notes.length; i++) {
                    var n = notes[i]
                    var tpc = n.tpc
                    var pitch = n.pitch + 0
                    var tpitch = pitch + (n.tpc2-n.tpc1)
                    if (!lowestNote || tpitch<lowestPitch) {
                        lowestNote = n
                        lowestPitch = tpitch
                    }
                }
                if (lowestNote) {
                    var text = numbersMapping[(lowestPitch).toString()][instInd]
                    var hasTieBack = lowestNote.tieBack != null
                    if ((!hideRepeatingValuesCheckBox.checked || text != last_text) && !hasTieBack) {
                        last_text = text
                        text = text.toString().split("").join("\n")
                        insertNoteText(cursor,text,lowestNote)
                    }
                }
            }

            cursor.next()
        }
        console.log("finished staff "+staffIndex)
    }

    function removeNoteText(cur) {
        for (var i=0; i<cur.segment.annotations.length; i++) {
            var a = cur.segment.annotations[i]
            if (a.name == "FiguredBass") {
                removeElement(a)
            }
        }
    }

    function insertNoteText(cur,text,note) {
        var textEl = newElement(Element.FIGURED_BASS) 
        textEl.text = text
        //textEl.fontFace: 'MScore Text'
        //textEl.fontSize: 18
        //showObject(textEl)
        cur.add(textEl)
    }

    function removeAll() {
        if (updating) {
            return
        }
        updating = true
        console.log("remove")
        curScore.startCmd()

        var selectedStaffs = getSelectedStaffsOrAllInd()
        console.log("selected staffs "+selectedStaffs)
        removeAllStaffs()

        curScore.endCmd()
        console.log("remove end")
        updating = false
    }

    function updateAll() {
        removeAll()
        if (updating) {
            return
        }
        updating = true
        console.log("update")
        curScore.startCmd()

        var selectedStaffs = getSelectedStaffsOrAllInd()
        console.log("selected staffs "+selectedStaffs)
        for (var i=0; i<selectedStaffs.length; i++) {
            updateStaff(selectedStaffs[i])
        }

        curScore.endCmd()
        console.log("update end")
        updating = false
    }

    function stringRepeat(s,c) {
        var str = ""
        for (var i=0; i<c; i++) {
            str += s
        }
        return str
    }

    function getStaffFromInd(i) {
        var c = curScore.newCursor()
        c.voice = 0
        c.rewind(0)
        c.staffIdx = i
        return c.element.staff
    }

    function getSelectedStaffsOrAllInd() {
        var selectedStaffs = []
        if (curScore.selection.elements.length>0) {
            if (curScore.selection.isRange) {
                for (var i=curScore.selection.startStaff; i<curScore.selection.endStaff; i++) {
                    selectedStaffs.push(i)
                }
            } else {
                var c = curScore.newCursor()
                c.voice = 0
                c.rewind(0)
                for (var i=0; i<curScore.selection.elements.length; i++) {
                    var e = curScore.selection.elements[i]
                    if (e.type==Element.CHORD || e.type==Element.NOTE || e.type==Element.REST) {
                        var selectInd = -1
                        for (var j=0; j<curScore.nstaves; j++) {
                            c.staffIdx = j
                            if (e.staff.is(c.element.staff)) {
                                selectInd = j
                                break
                            }
                        }
                        if (selectedStaffs.indexOf(selectInd)<0) {
                            selectedStaffs.push(selectInd)
                        }
                    }
                }
            }
        }
        if (selectedStaffs.length==0) {
            for (var i=0; i<curScore.nstaves; i++) {
                selectedStaffs.push(i)
            }
        }

        return selectedStaffs
    }

    GridLayout {
        anchors.margins:10
        columns: 1

        GridLayout {
            id: settingsContainer
            anchors.margins: 4
            columns: 2

            /*
            CheckBox {
                id: showNumbersCheckBox
                checked: true
                onCheckedChanged: function () {
                    console.log("changed showNumbers")
                }
            }
            Rectangle {
                width: childrenRect.width + 20
                height: childrenRect.height + 10

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Show Numbers")
                }
            }
            */

            CheckBox {
                id: hideRepeatingValuesCheckBox
                checked: false
                onCheckedChanged: function () {
                    updateAll()
                }
            }
            Rectangle {
                width: childrenRect.width + 20
                height: childrenRect.height + 10

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Hide repeating values")
                }
            }
        }
        GridLayout {
            id: mappingFilesContainer
            anchors.margins: 4
            columns: 2


            Rectangle {
                width: childrenRect.width + 20
                height: childrenRect.height + 10
                anchors.verticalCenter: buttonNumbersMappingFile.verticalCenter

                Label {
                    id: numbersMappingFileLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Numbers Map File")+":"
                }
            }
            
            Button {
                id : buttonNumbersMappingFile
                text: qsTr(numberMappingFilePath.substr(numberMappingFilePath.lastIndexOf("/")+1))
                onClicked: {
                    console.log("select mapping file")
                    numbersMappingFileDialog.open()
                }
            }

        }

        GridLayout {
            rows: 1

            Button {
                id: updateButton
                text: qsTr("Update")
                onClicked: updateAll()
            }

            Button {
                id: removeButton
                text: qsTr("Remove")
                onClicked: removeAll()
            }
        }
    }

    function getLocalPath(path) {
        path = path.replace(/^(file:\/{2})/,"")
        if (Qt.platform.os == "windows") path = path.replace(/^\//,"")
        path = decodeURIComponent(path)
        return path
    }

    function dirname(p) {
        if (p.indexOf("/")>=0) {
            p = (p.slice(0,p.lastIndexOf("/")+1))
        }
        if (p.indexOf("\\")>=0) {
            p = (p.slice(0,p.lastIndexOf("\\")+1))
        }
        return p
    }
     
    function basename(p) {
        if (p.indexOf("/")>=0) {
            p = (p.slice(p.lastIndexOf("/")+1))
        }
        if (p.indexOf("\\")>=0) {
            p = (p.slice(p.lastIndexOf("\\")+1))
        }
        return p
    }

    function extension(p) {
        return (p.slice(p.lastIndexOf(".")+1))
    }

    FileDialog {
        id: numbersMappingFileDialog
        title: qsTr("Numbers Map File")
        selectExisting: true
        selectFolder: false
        selectMultiple: false
        folder: shortcuts.home
        onAccepted: {
            var filename = numbersMappingFileDialog.fileUrl.toString()
            
            if(filename){
                filename = getLocalPath(filename)
                console.log("selected "+filename)
                numberMappingFilePath = filename

                processMappings()
            }
        }
    }

    FileDialog {
        id: lettersMappingFileDialog
        title: qsTr("Letters Map File")
        selectExisting: true
        selectFolder: false
        selectMultiple: false
        folder: shortcuts.home
        onAccepted: {
            var filename = lettersMappingFileDialog.fileUrl.toString()
            
            if(filename){
                filename = getLocalPath(filename)
                console.log("selected "+filename)
                letterMappingFilePath = filename

                processMappings()
            }
        }
    }

    function processMappings() {
        var xhr = new XMLHttpRequest
        xhr.open("GET", numberMappingFilePath)
        xhr.onreadystatechange = function() {
            if (xhr.readyState == XMLHttpRequest.DONE) {
                numbersMapping = JSON.parse(xhr.responseText)
                console.log("updated numbers mapping")
            }
        }
        xhr.send()

        var xhr1 = new XMLHttpRequest
        xhr1.open("GET", letterMappingFilePath)
        xhr1.onreadystatechange = function() {
            if (xhr1.readyState == XMLHttpRequest.DONE) {
                lettersMapping = JSON.parse(xhr1.responseText)
                console.log("updated letters mapping")
            }
        }
        xhr1.send()
    }

}

