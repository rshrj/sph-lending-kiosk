cmake_minimum_required(VERSION 3.28)

project(SphKiosk
    VERSION 0.1.0
    DESCRIPTION "ETH SPH lending kiosk (borrow & return) for a 7\" Raspberry Pi 5 touchscreen"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Raspberry Pi OS (Debian 13 "trixie") ships Qt 6.8.2 — this is the floor.
# The Mac (Homebrew) has a newer Qt; keep code within the 6.8 API.
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(sph-kiosk
    src/main.cpp
    src/backend.h src/backend.cpp
    src/idlemonitor.h src/idlemonitor.cpp
    src/rfidservice.h src/rfidservice.cpp
    src/rfid/iso14443.h
)

# RC522 driver uses Linux spidev + GPIO character-device APIs; elsewhere only the simulator exists.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_sources(sph-kiosk PRIVATE src/rfid/mfrc522.h src/rfid/mfrc522.cpp)
    target_compile_definitions(sph-kiosk PRIVATE KIOSK_HAVE_MFRC522=1)
else()
    target_compile_definitions(sph-kiosk PRIVATE KIOSK_HAVE_MFRC522=0)
endif()

set_source_files_properties(qml/Theme.qml qml/Notify.qml qml/Session.qml qml/Fmt.qml qml/Tray.qml qml/components/Icons.qml
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

qt_add_qml_module(sph-kiosk
    URI Kiosk
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/Notify.qml
        qml/Session.qml
        qml/Tray.qml
        qml/Fmt.qml
        qml/AttractScreen.qml
        qml/ScreenshotTour.qml
        qml/components/Icon.qml
        qml/components/Icons.qml
        qml/components/KButton.qml
        qml/components/Card.qml
        qml/components/InfoRow.qml
        qml/components/Keypad.qml
        qml/components/TapPrompt.qml
        qml/components/SwipeToConfirm.qml
        qml/components/SuccessMark.qml
        qml/components/CountdownRing.qml
        qml/components/Toast.qml
        qml/components/HoldButton.qml
        qml/components/ModeTile.qml
        qml/components/Header.qml
        qml/components/Heading.qml
        qml/components/ItemRow.qml
        qml/components/StatusChip.qml
        qml/components/CameraView.qml
        qml/components/Modal.qml
        qml/screens/StartScreen.qml
        qml/screens/SignInScreen.qml
        qml/screens/TrayScreen.qml
        qml/screens/ConfirmScreen.qml
        qml/screens/DoneScreen.qml
        qml/screens/AddByTag.qml
        qml/screens/MyLoans.qml
        qml/screens/StaffPanel.qml
        qml/screens/TeachPanel.qml
    RESOURCES
        ${BRAND_FONTS}
        assets/sph/sph-logo.svg
        assets/sph/sph-logo-white.svg
        assets/sph/brush-yellow.svg
        assets/sph/brush-purple.svg
        assets/sph/brush-orange.svg
        assets/sph/brush-green.svg
)

target_include_directories(sph-kiosk PRIVATE src)  # for the generated QML type registrations

target_compile_definitions(sph-kiosk PRIVATE
    PROJECT_VERSION_STRING="${PROJECT_VERSION}")

target_compile_options(sph-kiosk PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic>)

target_link_libraries(sph-kiosk PRIVATE
    Qt6::Core Qt6::Gui Qt6::Network Qt6::Qml Qt6::Quick Qt6::QuickControls2)

set_target_properties(sph-kiosk PROPERTIES
    MACOSX_BUNDLE OFF   # plain binary on macOS too: same run command everywhere
    WIN32_EXECUTABLE OFF)

include(GNUInstallDirs)
install(TARGETS sph-kiosk RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
