import QtQuick 2.2
import QtQuick.Dialogs 1.0
import QtQuick.Controls 2.0
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

    QProcess {
        id: proc
    }

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
                    var text = (lowestPitch).toString()
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

    function processStaffVoice(staff,voice, format) {

        if (format==undefined) {
            format = "txt"
        }

        var instrumentPitchOffset = 0
        var sss = getStaffFromInd(staff)
        if(sss.part.instruments[0].instrumentId.indexOf("brass.trombone")==0) {
            instrumentPitchOffset = 12
        } else if(sss.part.instruments[0].instrumentId.indexOf("brass.euphonium")==0) {
            instrumentPitchOffset = 12
        } else if(sss.part.instruments[0].instrumentId.indexOf("brass.sousaphone")==0) {
            instrumentPitchOffset = 24
        } else if(sss.part.instruments[0].instrumentId.indexOf("brass.trumpet")==0) {
            instrumentPitchOffset = 0
        } else {
            console.log(sss.part.instruments[0].instrumentId)
        }

        var cur = curScore.newCursor()
        cur.staffIdx = staff
        cur.voice = voice 
        cur.rewind(0)
        
        var score = cur.score
        
        var pH = new processHelper(score, sss)

        
        var  i = 0
        while (cur.segment) {
        
            var nind = cur.segment.tick/division
            
            for (var j=0; j<cur.segment.annotations.length; j++) {
                var an = cur.segment.annotations[j]
                if (an.type==41) { // tempo annotation
                } else if (an.type==42) {
                    console.log("  staff text"+an.text)
                    pH.newPart(an.text)
                } else if (an.type==43) {
                    //console.log("  system text "+an.text)
                    pH.newPart(an.text)
                } else {
                    console.log("  ======> Annotation with type "+an.type+" "+an.userName())
                }
            }

        
            if (cur.element) {
                if (cur.element.type==Element.CHORD) {
                    /* TODO: handle multiple notes
                    for (var j=0; j<cur.element.notes.length; j++) {
                        var n = cur.element.notes[j]
                        var pitch = n.pitch + instrumentPitchOffset
                        var tpitch = pitch + (n.tpc2-n.tpc1)
                    }
                    */
                    var n = cur.element.notes[0]
                    var pitch = n.pitch + instrumentPitchOffset
                    var tpitch = pitch + (n.tpc2-n.tpc1)
                    if (n.tieBack!==null && n.tieBack.startNote.pitch==n.pitch) {
                    } else {
                        pH.newNote(nind, tpitch, cur.element.actualDuration, useSharps(cur))
                    }
                } else if (cur.element.type==Element.REST) {
                    var duration = cur.element.actualDuration
                    pH.newRest(nind,duration.numerator/duration.denominator)
                } else {
                    console.log("  ======> Other element of type "+cur.element.userName()+")")
                }
            } else {
                console.log("No element")
            }

            var mes = cur.measure.elements
            var m = cur.measure
            for (var j=0; j<mes.length; j++) {
                var me = mes[j]
                if (me.type==Element.LAYOUT_BREAK) {
                    pH.newLayoutBreak(m.lastSegment.tick/division)
                    if (!m.lastSegment) {
                    } else if (m.lastSegment.is(cur.segment)) {
                    } else {
                        var cs = m.firstSegment
                        while (cs!=null) {
                            cs = cs.nextInMeasure
                        }
                    }
                } else {
                    console.log("    =====> Other measure element "+m.name)
                }
            }
            
        
            cur.next()
            
            /*
            i = i+1
            if (i>60) {
                break
            }
            */
        }

        var o = pH.getOutput(format)
        return o
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

    Control {
        id: mainControl
        width: childrenRect.width
        height: parent.height

        Rectangle {
            id: backgroundRect
            width: childrenRect.width
            height: parent.height

            Control {
                id: showNumbersControl
                height: childrenRect.height

                CheckBox {
                    id: showNumbersCheckBox
                    checked: true
                    text: "Show Numbers"
                    onCheckedChanged: function () {
                        console.log("changed showNumbers")
                    }
                }
                Label {
                    text: "Show Numbers"
                    anchors.left: showNumbersCheckBox.right
                    anchors.leftMargin: 2
                    color: "#DDD"
                }
            }

            Control {
                id: hideRepeatingValuesControl
                height: childrenRect.height
                anchors.top: showNumbersControl.bottom
                anchors.topMargin: 4

                CheckBox {
                    id: hideRepeatingValuesCheckBox
                    checked: true
                    text: "Hide repeating values"
                    onCheckedChanged: function () {
                        updateAll()
                    }
                }
                Label {
                    text: "Hide repeating values"
                    anchors.left: hideRepeatingValuesCheckBox.right
                    anchors.leftMargin: 2
                    color: "#DDD"
                }
            }

            Button {
                id: updateButton
                anchors.top: hideRepeatingValuesControl.bottom
                anchors.topMargin: 4
                text: "Update"
                onClicked: updateAll()
            }

            Button {
                id: removeButton
                anchors.top: updateButton.top
                anchors.left: updateButton.right
                anchors.leftMargin: 4
                text: "Remove"
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
        title: qsTr("Numbers Mapping File")
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
        title: qsTr("Letters Mapping File")
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


        
        
    function numbers(pitch) {
        switch (pitch) {
            case 54: return "1/2/3"
            case 55: return "1/3"
            case 56: return "2/3"
            case 57: return "½"
            case 58: return "1"
            case 59: return "2"
            case 60: return "L"
            case 61: return "1/2/3"
            case 62: return "1/3"
            case 63: return "2/3"
            case 64: return "½"
            case 65: return "1"
            case 66: return "2"
            case 67: return "L"
            case 68: return "2/3"
            case 69: return "½"
            case 70: return "1"
            case 71: return "2"
            case 72: return "L"
            case 73: return "½"
            case 74: return "1"
            case 75: return "2"
            case 76: return "L"
            case 77: return "1"
            case 78: return "2"
            case 79: return "L"
            case 80: return "2/3"
            case 81: return "½"
            case 82: return "1"
            case 83: return "2"
            case 84: return "L"
            default: ""
        }
    }

    function letters(tpitch, cur) {
        if (useSharps(cur)) {
            return lettersSharp(tpitch)
        } else {
            return lettersFlat(tpitch)
        }
    }

    function useSharps(cur) {
        if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="auto") {
            if (cur.keySignature<0) {
                return false
            } else {
                return true
            }
        } else if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="sharp") {
            return true
        } else if (sharpOrFlatSelection.get(sharpOrFlatSelectionBox.currentIndex).value=="flat") {
            return false
        }
    }
    
    function lettersSharp(pitch) {
        switch (pitch) {
            case 54: return "Fis"
            case 55: return "G"
            case 56: return "Gis"
            case 57: return "A"
            case 58: return "Ais"
            case 59: return "H"
            case 60: return "C"
            case 61: return "Cis"
            case 62: return "D"
            case 63: return "Dis"
            case 64: return "E"
            case 65: return "F"
            case 66: return "Fis"
            case 67: return "G"
            case 68: return "Gis"
            case 69: return "A"
            case 70: return "Ais"
            case 71: return "H"
            case 72: return "C"
            case 73: return "Cis"
            case 74: return "D"
            case 75: return "Dis"
            case 76: return "E"
            case 77: return "F"
            case 78: return "Fis"
            case 79: return "G"
            case 80: return "Gis"
            case 81: return "A"
            case 82: return "Ais"
            case 83: return "H"
            case 84: return "C"
            default: ""
        }
    }
    
    
    
    function lettersFlat(pitch) {
        switch (pitch) {
            case 54: return "Ges"
            case 55: return "G"
            case 56: return "As"
            case 57: return "A"
            case 58: return "B"
            case 59: return "H"
            case 60: return "C"
            case 61: return "Des"
            case 62: return "D"
            case 63: return "Es"
            case 64: return "E"
            case 65: return "F"
            case 66: return "Ges"
            case 67: return "G"
            case 68: return "As"
            case 69: return "A"
            case 70: return "B"
            case 71: return "H"
            case 72: return "C"
            case 73: return "Des"
            case 74: return "D"
            case 75: return "Es"
            case 76: return "E"
            case 77: return "F"
            case 78: return "Ges"
            case 79: return "G"
            case 80: return "As"
            case 81: return "A"
            case 82: return "B"
            case 83: return "H"
            case 84: return "C"
            default: ""
        }
    }
    
    
        
}

