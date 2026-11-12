cmake_minimum_required(VERSION 3.21)
project(mpire-setup VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Qml Quick QuickControls2)

include(GNUInstallDirs)
set(MPIRE_SETUP_QML_INSTALL_DIR "${CMAKE_INSTALL_FULL_DATADIR}/mpire-setup/qml")
option(MPIRE_SETUP_RUN_FROM_SOURCE "Load QML from the source tree (for development)" ON)
if(MPIRE_SETUP_RUN_FROM_SOURCE)
    set(qml_dir "${CMAKE_CURRENT_SOURCE_DIR}/qml")
else()
    set(qml_dir "${MPIRE_SETUP_QML_INSTALL_DIR}")
endif()

add_executable(mpire-setup src/main.cpp)
target_compile_definitions(mpire-setup PRIVATE MPIRE_SETUP_QML_DIR="${qml_dir}")
target_link_libraries(mpire-setup PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2)

install(TARGETS mpire-setup RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY qml/ DESTINATION ${MPIRE_SETUP_QML_INSTALL_DIR})
