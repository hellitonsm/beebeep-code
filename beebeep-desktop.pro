include(beebeep.pri)
include(locale/locale.pri)

contains(QMAKE_TARGET.arch, x86) {
    # Specifichiamo la versione esatta dell'SDK di Windows 10 scaricato
    SDK_VER = 10.0.19041.0
    SDK_ROOT = "C:/Program Files (x86)/Windows Kits/10"

    # Iniettiamo i percorsi corretti in cima alla lista delle inclusioni
    INCLUDEPATH = $$SDK_ROOT/Include/$$SDK_VER/ucrt \
                  $$SDK_ROOT/Include/$$SDK_VER/um \
                  $$SDK_ROOT/Include/$$SDK_VER/shared \
                  $$INCLUDEPATH
}

TEMPLATE = subdirs

SUBDIRS += src plugins

CONFIG += ordered

TRANSLATIONS = $$BEEBEEP_TRANSLATIONS

