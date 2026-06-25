include(../plugins.pri)

os2: {
 TARGET=regularb
} else {
 TARGET = regularboldtextmarker
}

TEMPLATE = lib

DEFINES += REGULARBOLDTEXTMARKER_LIBRARY

SOURCES += RegularBoldTextMarker.cpp

HEADERS += RegularBoldTextMarker.h\
        regularboldtextmarker_global.h

RESOURCES += \
    regularboldtextmarker.qrc

unix:!macx:!android: {
  target.path = $$PLUGINDIR
  INSTALLS += target
}
