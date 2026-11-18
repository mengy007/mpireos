# Mpire Glass: the widget style for Qt and KDE apps (a Qt style plugin). It is
# Breeze with frosted-glass windows: see mpireglass.h.
find_package(KF6WindowSystem CONFIG)   # blur behind the windows (without it they're just see-through)

add_library(mpireglass MODULE mpireglass.cpp mpireglass.h)
set_target_properties(mpireglass PROPERTIES OUTPUT_NAME mpireglass PREFIX "")
target_link_libraries(mpireglass PRIVATE Qt6::Widgets)
if(KF6WindowSystem_FOUND)
    target_link_libraries(mpireglass PRIVATE KF6::WindowSystem)
    target_compile_definitions(mpireglass PRIVATE MPIRE_HAVE_KWINDOWSYSTEM)
endif()

set(MPIRE_QT_PLUGIN_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/plugins" CACHE STRING "Where Qt plugins are installed")
install(TARGETS mpireglass DESTINATION ${MPIRE_QT_PLUGIN_DIR}/styles)
