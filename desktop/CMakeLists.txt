cmake_minimum_required(VERSION 3.21)
project(mpire-desktop VERSION 0.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.9 REQUIRED COMPONENTS Gui Qml Quick)
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

add_executable(mpire-shell src/main.cpp src/shellapi.cpp src/shellapi.h)
target_compile_definitions(mpire-shell PRIVATE MPIRE_SHELL_QML_DIR="${shell_qml_dir}")
target_link_libraries(mpire-shell PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick LayerShellQt::Interface)

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
