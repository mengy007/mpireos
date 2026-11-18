# Mpire window frames: MpireOS's KWin window decoration (KDecoration3 plugin).
find_package(KDecoration3 6.5 CONFIG REQUIRED)
find_package(KF6CoreAddons CONFIG REQUIRED)

add_library(mpiredecoration MODULE mpiredecoration.cpp mpiredecoration.h)
set_target_properties(mpiredecoration PROPERTIES OUTPUT_NAME org.mpireos.decoration PREFIX "")
target_link_libraries(mpiredecoration PRIVATE Qt6::Gui KF6::CoreAddons KDecoration3::KDecoration)
target_compile_features(mpiredecoration PRIVATE cxx_std_20)   # KDecoration3 headers need C++20

if(NOT KDECORATION_PLUGIN_DIR)
    set(KDECORATION_PLUGIN_DIR "org.kde.kdecoration3")
endif()
set(MPIRE_QT_PLUGIN_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/plugins" CACHE STRING "Where Qt plugins are installed")
install(TARGETS mpiredecoration DESTINATION ${MPIRE_QT_PLUGIN_DIR}/${KDECORATION_PLUGIN_DIR})
