cmake_minimum_required(VERSION 3.21)
project(mpire-desktop VERSION 0.7 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.9 REQUIRED COMPONENTS Gui Qml Quick DBus Widgets)
find_package(LayerShellQt REQUIRED)
# Blur behind the shell's glass panels (optional: without it they're just see-through).
find_package(KF6WindowSystem CONFIG)

include(GNUInstallDirs)
set(MPIRE_QML_MODULE_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE STRING "Where the MpireOS.Style QML module is installed")
set(MPIRE_SHELL_QML_INSTALL_DIR "${CMAKE_INSTALL_FULL_DATADIR}/mpire-desktop/shell")
option(MPIRE_SHELL_RUN_FROM_SOURCE "Load QML from the source tree (for development)" ON)
if(MPIRE_SHELL_RUN_FROM_SOURCE)
    set(shell_qml_dir "${CMAKE_CURRENT_SOURCE_DIR}/shell")
else()
    set(shell_qml_dir "${MPIRE_SHELL_QML_INSTALL_DIR}")
endif()

add_executable(mpire-shell
    src/main.cpp
    src/ai.cpp src/ai.h
    src/shellapi.cpp src/shellapi.h
    src/apps.cpp src/apps.h
    src/desktopsettings.cpp src/desktopsettings.h
    src/filesearch.cpp src/filesearch.h
    src/glass.cpp src/glass.h
    src/iconprovider.h
    src/notifications.cpp src/notifications.h
    src/systemstatus.cpp src/systemstatus.h
    src/tray.cpp src/tray.h
    src/workspaces.cpp src/workspaces.h)
target_compile_definitions(mpire-shell PRIVATE MPIRE_SHELL_QML_DIR="${shell_qml_dir}")
target_link_libraries(mpire-shell PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::DBus LayerShellQt::Interface)
if(KF6WindowSystem_FOUND)
    target_link_libraries(mpire-shell PRIVATE KF6::WindowSystem)
    target_compile_definitions(mpire-shell PRIVATE MPIRE_HAVE_KWINDOWSYSTEM)
endif()

install(TARGETS mpire-shell RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# A stand-in app with a tray icon and menu, for checking the system tray (CI
# boot test, or by hand). Uses Qt's own tray support, like any Qt or KDE app.
add_executable(mpire-tray-test tests/tray-test.cpp)
target_link_libraries(mpire-tray-test PRIVATE Qt6::Widgets)
install(TARGETS mpire-tray-test RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}/mpire-desktop)
# Shared style module (also used by Mpire Setup and the login screen).
install(DIRECTORY style/MpireOS DESTINATION ${MPIRE_QML_MODULE_DIR})
install(DIRECTORY shell/ DESTINATION ${MPIRE_SHELL_QML_INSTALL_DIR})
# Login screen, as an SDDM theme.
install(DIRECTORY greeter/ DESTINATION ${CMAKE_INSTALL_DATADIR}/sddm/themes/mpireos)
# Session: mpire-shell takes plasmashell's place, and SDDM uses our theme.
install(FILES session/mpire-shell.conf
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/systemd/user/plasma-plasmashell.service.d)
install(FILES session/30-mpire-theme.conf DESTINATION ${CMAKE_INSTALL_FULL_SYSCONFDIR}/sddm.conf.d)
# Mpire window frames: our KWin window decoration (KWin uses it via kde/kwinrc).
option(MPIRE_BUILD_DECORATION "Build the Mpire window frames (needs KDecoration3)" ON)
if(MPIRE_BUILD_DECORATION)
    add_subdirectory(decoration)
endif()
# Mpire Glass: the widget style for Qt and KDE apps (Breeze, with frosted-glass
# windows; kde/kdeglobals selects it).
option(MPIRE_BUILD_GLASS_STYLE "Build the Mpire Glass app style" ON)
if(MPIRE_BUILD_GLASS_STYLE)
    add_subdirectory(qtstyle)
endif()
# Interim: MpireOS's look for the KDE pieces still in use (KWin title bars,
# KDE and Qt apps), until our own components replace them.
install(FILES kde/MpireOS.colors kde/MpireOSDark.colors DESTINATION ${CMAKE_INSTALL_DATADIR}/color-schemes)
install(FILES kde/kdeglobals kde/kwinrc kde/breezerc kde/ksplashrc kde/kcminputrc kde/konsolerc
        DESTINATION ${CMAKE_INSTALL_FULL_SYSCONFDIR}/xdg)
# The terminal: a frosted-glass Konsole profile, the default (kde/konsolerc).
install(FILES kde/konsole/MpireOS.profile kde/konsole/MpireGlass.colorscheme DESTINATION ${CMAKE_INSTALL_DATADIR}/konsole)
# Meta+Space, Alt+Space, Alt+F2, and Search open universal search: KRunner's
# entry is shadowed by ours, and Meta+Space has an entry of its own (KDE's
# global shortcut service reads both directories).
install(FILES session/org.kde.krunner.desktop DESTINATION /usr/local/share/applications)
install(FILES session/org.kde.krunner.desktop DESTINATION /usr/local/share/kglobalaccel)
install(FILES session/org.mpireos.search.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES session/org.mpireos.search.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/kglobalaccel)
# Meta+A opens the AI assistant.
install(FILES session/org.mpireos.assistant.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES session/org.mpireos.assistant.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/kglobalaccel)
install(DIRECTORY kde/lookandfeel/ DESTINATION ${CMAKE_INSTALL_DATADIR}/plasma/look-and-feel/org.mpireos.desktop)
