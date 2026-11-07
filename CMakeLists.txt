cmake_minimum_required(VERSION 3.28)

project(KioskLab
    VERSION 0.1.0
    DESCRIPTION "Touch / UI test bench for a 7\" Raspberry Pi 5 kiosk"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Raspberry Pi OS (Debian 13 "trixie") ships Qt 6.8.2 — this is the floor.
# The Mac (Homebrew) has a newer Qt; keep code within the 6.8 API.
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(kiosk-lab
    src/main.cpp
    src/systeminfo.h src/systeminfo.cpp
    src/idlemonitor.h src/idlemonitor.cpp
    src/rfidservice.h src/rfidservice.cpp
    src/rfid/iso14443.h
)

# RC522 driver uses Linux spidev + GPIO character-device APIs; elsewhere only the simulator exists.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_sources(kiosk-lab PRIVATE src/rfid/mfrc522.h src/rfid/mfrc522.cpp)
    target_compile_definitions(kiosk-lab PRIVATE KIOSK_HAVE_MFRC522=1)
else()
    target_compile_definitions(kiosk-lab PRIVATE KIOSK_HAVE_MFRC522=0)
endif()

set_source_files_properties(qml/Theme.qml qml/Notify.qml qml/Session.qml qml/components/Icons.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# Brand fonts (Proxima Nova, Alternate Gothic No2) are commercial and not in the repo: copy the TTFs
# into fonts/ (see fonts/README.md). Without them the app builds and falls back to a system font.
set(BRAND_FONTS)
foreach(font ProximaNova-Regular ProximaNova-Bold AlternateGothicNo2Pro-Regular)
    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/fonts/${font}.ttf)
        list(APPEND BRAND_FONTS fonts/${font}.ttf)
    else()
        message(WARNING "fonts/${font}.ttf is missing, using a fallback font (see fonts/README.md)")
    endif()
endforeach()

qt_add_qml_module(kiosk-lab
    URI Kiosk
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/Notify.qml
        qml/Session.qml
        qml/components/Icon.qml
        qml/components/Icons.qml
        qml/components/NavRail.qml
        qml/components/KButton.qml
        qml/components/Card.qml
        qml/components/ActionTile.qml
        qml/components/KSwitch.qml
        qml/components/KSlider.qml
        qml/components/Segmented.qml
        qml/components/Stepper.qml
        qml/components/Dial.qml
        qml/components/Keypad.qml
        qml/components/SwipeToConfirm.qml
        qml/components/Sparkline.qml
        qml/components/Toast.qml
        qml/components/FpsMeter.qml
        qml/components/SectionHeader.qml
        qml/components/InfoRow.qml
        qml/components/SuccessMark.qml
        qml/components/CountdownRing.qml
        qml/components/SoftBlob.qml
        qml/components/HoldButton.qml
        qml/components/TouchDot.qml
        qml/pages/HomePage.qml
        qml/pages/TouchLabPage.qml
        qml/pages/MultiTouchPane.qml
        qml/pages/GesturesPane.qml
        qml/pages/AccuracyPane.qml
        qml/pages/ControlsPage.qml
        qml/pages/SystemPage.qml
        qml/pages/SettingsPage.qml
        qml/pages/GuidedFlow.qml
        qml/pages/BadgePage.qml
        qml/components/TapPrompt.qml
        qml/AttractScreen.qml
        qml/VirtualKeyboard.qml
        qml/ScreenshotTour.qml
    RESOURCES
        fonts/Inter-Light.ttf
        fonts/Inter-Regular.ttf
        fonts/Inter-Medium.ttf
        fonts/Inter-SemiBold.ttf
        fonts/Inter-Bold.ttf
        ${BRAND_FONTS}
        assets/sph/brush-black.svg
        assets/sph/brush-cyan.svg
        assets/sph/brush-green.svg
        assets/sph/brush-orange.svg
        assets/sph/brush-purple.svg
        assets/sph/brush-white.svg
        assets/sph/brush-yellow.svg
        assets/sph/chevron-right.svg
        assets/sph/sph-logo-white.svg
        assets/sph/sph-logo.svg
)

target_include_directories(kiosk-lab PRIVATE src)  # for the generated QML type registrations

target_compile_definitions(kiosk-lab PRIVATE
    PROJECT_VERSION_STRING="${PROJECT_VERSION}")

target_compile_options(kiosk-lab PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic>)

target_link_libraries(kiosk-lab PRIVATE
    Qt6::Core Qt6::Gui Qt6::Network Qt6::Qml Qt6::Quick Qt6::QuickControls2)

set_target_properties(kiosk-lab PROPERTIES
    MACOSX_BUNDLE OFF   # plain binary on macOS too: same run command everywhere
    WIN32_EXECUTABLE OFF)

include(GNUInstallDirs)
install(TARGETS kiosk-lab RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
