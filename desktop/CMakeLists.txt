cmake_minimum_required(VERSION 3.21)
project(mpire-desktop VERSION 0.3 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.9 REQUIRED COMPONENTS Gui Qml Quick DBus)
find_package(LayerShellQt REQUIRED)

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
    src/shellapi.cpp src/shellapi.h
    src/apps.cpp src/apps.h
    src/iconprovider.h
    src/notifications.cpp src/notifications.h
    src/systemstatus.cpp src/systemstatus.h)
target_compile_definitions(mpire-shell PRIVATE MPIRE_SHELL_QML_DIR="${shell_qml_dir}")
target_link_libraries(mpire-shell PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::DBus LayerShellQt::Interface)

install(TARGETS mpire-shell RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
# Shared style module (also used by Mpire Setup and the login screen).
install(DIRECTORY style/MpireOS DESTINATION ${MPIRE_QML_MODULE_DIR})
install(DIRECTORY shell/ DESTINATION ${MPIRE_SHELL_QML_INSTALL_DIR})
# Login screen, as an SDDM theme.
install(DIRECTORY greeter/ DESTINATION ${CMAKE_INSTALL_DATADIR}/sddm/themes/mpireos)
# Session: mpire-shell takes plasmashell's place, and SDDM uses our theme.
install(FILES session/mpire-shell.conf
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/systemd/user/plasma-plasmashell.service.d)
install(FILES session/30-mpire-theme.conf DESTINATION ${CMAKE_INSTALL_FULL_SYSCONFDIR}/sddm.conf.d)
# Interim: MpireOS's look for the KDE pieces still in use (KWin title bars,
# KDE and Qt apps), until our own components replace them.
install(FILES kde/MpireOS.colors DESTINATION ${CMAKE_INSTALL_DATADIR}/color-schemes)
install(FILES kde/kdeglobals kde/kwinrc kde/breezerc kde/ksplashrc kde/kcminputrc
        DESTINATION ${CMAKE_INSTALL_FULL_SYSCONFDIR}/xdg)
# Alt+Space opens our launcher (KDE's global shortcut service reads this).
install(FILES session/org.mpireos.launcher.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES session/org.mpireos.launcher.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/kglobalaccel)
install(FILES kde/kglobalshortcutsrc DESTINATION ${CMAKE_INSTALL_FULL_SYSCONFDIR}/xdg)
install(DIRECTORY kde/lookandfeel/ DESTINATION ${CMAKE_INSTALL_DATADIR}/plasma/look-and-feel/org.mpireos.desktop)
