cmake_minimum_required(VERSION 3.13)

if(NOT DEFINED XMOS_MODULES_ROOT_DIR)
    message(FATAL_ERROR "XMOS_MODULES_ROOT_DIR must be set before including xmos_utils.cmake")
endif()

if(PROJECT_SOURCE_DIR AND NOT DEFINED AFR_VENDORS_DIR)
    message(FATAL_ERROR "xmos_utils.cmake must be included before a project definition")
endif()

## Setup at caller scope

# Set up compiler
if(DEFINED XMOS_TOOLS_PATH)
    set(CMAKE_C_COMPILER "${XMOS_TOOLS_PATH}/xcc")
    set(CMAKE_CXX_COMPILER  "${XMOS_TOOLS_PATH}/xcc")
    set(CMAKE_ASM_COMPILER  "${XMOS_TOOLS_PATH}/xcc")
    set(CMAKE_AR "${XMOS_TOOLS_PATH}/xmosar")
    set(CMAKE_C_COMPILER_AR "${XMOS_TOOLS_PATH}/xmosar")
    set(CMAKE_CXX_COMPILER_AR "${XMOS_TOOLS_PATH}/xmosar")
    set(CMAKE_ASM_COMPILER_AR "${XMOS_TOOLS_PATH}/xmosar")
else()
    message(WARNING "XMOS_TOOLS_PATH not specified.  CMake will assume tools have been added to PATH.")
    set(CMAKE_C_COMPILER "xcc")
    set(CMAKE_CXX_COMPILER  "xcc")
    set(CMAKE_ASM_COMPILER  "xcc")
    set(CMAKE_AR "xmosar")
    set(CMAKE_C_COMPILER_AR "xmosar")
    set(CMAKE_CXX_COMPILER_AR "xmosar")
    set(CMAKE_ASM_COMPILER_AR "xmosar")
endif()

set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)
set(CMAKE_ASM_COMPILER_FORCED TRUE)

# Set up some XMOS specific variables
set(FULL 1 )
set(BITSTREAM_ONLY 2 )
set(BSP_ONLY 3 )
define_property(TARGET PROPERTY OPTIONAL_HEADERS BRIEF_DOCS "Contains list of optional headers." FULL_DOCS "Contains a list of optional headers.  The application level should search through all app includes and define D__[header]_h_exists__ for each header that is in both the app and optional headers.")
# define_property(TARGET PROPERTY FILE_FLAGS BRIEF_DOCS "List of files with additional compile flags." FULL_DOCS "List of files with additional compile flags.  The target level needs to set_source_files_properties for each file flag pair.")
define_property(GLOBAL PROPERTY XMOS_TARGETS_LIST BRIEF_DOCS "brief" FULL_DOCS "full")

# Setup build output
file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")

if(DEFINED AFR_ROOT_DIR)
    include("${AFR_VENDORS_DIR}/xmos/lib_rtos_support/cmake_utils/xmos_afr_support.cmake")
endif()

function(XMOS_ADD_FILE_COMPILER_FLAGS)
    if(NOT ${ARGC} EQUAL 2)
        message(FATAL_ERROR "XMOS_ADD_FILE_COMPILER_FLAGS requires 2 arguments, a file and string of flags")
    else()
        if(NOT EXISTS ${ARGV0} AND NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${ARGV0})
            message(FATAL_ERROR "arg 0 must be a file relative to the caller.")
        endif()
        if(NOT ${ARGV1} STRGREATER "")
            message(FATAL_ERROR "arg 1 must be a non empty string.")
        endif()
    endif()

    set_source_files_properties(${ARGV0} PROPERTIES COMPILE_FLAGS ${ARGV1})
endfunction()


## Registers an application and it's dependencies
function(XMOS_REGISTER_APP)
    if(NOT APP_HW_TARGET)
        message(FATAL_ERROR "APP_HW_TARGET is not defined.")
    endif()

    ## Populate build flag for hardware target
    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${APP_HW_TARGET})
        get_filename_component(HW_ABS_PATH ${CMAKE_CURRENT_SOURCE_DIR}/${APP_HW_TARGET} ABSOLUTE)
        set(APP_TARGET_COMPILER_FLAG ${HW_ABS_PATH})
    else()
        set(APP_TARGET_COMPILER_FLAG "-target=${APP_HW_TARGET}")
    endif()

    if(DEFINED THIS_XCORE_TILE)
        list(APPEND APP_COMPILER_FLAGS "-DTHIS_XCORE_TILE=${THIS_XCORE_TILE}")
    endif()

    set(LIB_NAME ${PROJECT_NAME}_LIB)
    set(LIB_VERSION ${PROJECT_VERSION})
    set(LIB_ADD_COMPILER_FLAGS ${APP_COMPILER_FLAGS})
    set(LIB_XC_SRCS ${APP_XC_SRCS})
    set(LIB_C_SRCS ${APP_C_SRCS})
    set(LIB_ASM_SRCS ${APP_ASM_SRCS})
    set(LIB_INCLUDES ${APP_INCLUDES})
    set(LIB_DEPENDENT_MODULES ${APP_DEPENDENT_MODULES})
    set(LIB_OPTIONAL_HEADERS "")
    set(LIB_FILE_FLAGS "")
    
    XMOS_REGISTER_MODULE("silent")

    get_target_property(${PROJECT_NAME}_LIB_SRCS ${PROJECT_NAME}_LIB SOURCES)
    get_target_property(${PROJECT_NAME}_LIB_INCS ${PROJECT_NAME}_LIB INCLUDE_DIRECTORIES)
    get_target_property(${PROJECT_NAME}_LIB_OPTINCS ${PROJECT_NAME}_LIB OPTIONAL_HEADERS)
    get_target_property(${PROJECT_NAME}_LIB_FILE_FLAGS ${PROJECT_NAME}_LIB FILE_FLAGS)

    set(APP_SOURCES ${${PROJECT_NAME}_LIB_SRCS})
    set(APP_INCLUDES ${${PROJECT_NAME}_LIB_INCS})

    get_property(XMOS_TARGETS_LIST GLOBAL PROPERTY XMOS_TARGETS_LIST)

    foreach(lib ${XMOS_TARGETS_LIST})
        get_target_property(inc ${lib} INCLUDE_DIRECTORIES)
        list(APPEND APP_INCLUDES ${inc})
    endforeach()

    list(REMOVE_DUPLICATES APP_SOURCES)
    list(REMOVE_DUPLICATES APP_INCLUDES)

    foreach(file ${APP_SOURCES})
        get_filename_component(ext ${file} EXT)
        if(${ext} STREQUAL ".xc")
            set_source_files_properties(${file} PROPERTIES LANGUAGE C)
        endif()
    endforeach()

    # Only define header exists, if header optional
    foreach(inc ${APP_INCLUDES})
        file(GLOB headers ${inc}/*.h)
        foreach(header ${headers})
            get_filename_component(name ${header} NAME)
            list(FIND ${PROJECT_NAME}_LIB_OPTINCS ${name} FOUND)
            if(${FOUND} GREATER -1)
                get_filename_component(name_we ${header} NAME_WE)
                list(APPEND HEADER_EXIST_FLAGS -D__${name_we}_h_exists__)
            endif()
        endforeach()
    endforeach()

    set(TARGET_NAME "${PROJECT_NAME}.xe")
    set(APP_COMPILE_FLAGS ${APP_TARGET_COMPILER_FLAG} ${APP_COMPILER_FLAGS} ${APP_COMPILER_C_FLAGS} ${HEADER_EXIST_FLAGS})

    foreach(target ${XMOS_TARGETS_LIST})
        target_include_directories(${target} PRIVATE ${APP_INCLUDES})
        target_compile_options(${target} BEFORE PRIVATE ${APP_COMPILE_FLAGS})
    endforeach()

    set(DEPS_TO_LINK "")
    foreach(DEP_MODULE ${LIB_DEPENDENT_MODULES})
        string(REGEX MATCH "^[A-Za-z0-9_ -]+" DEP_NAME ${DEP_MODULE})
        list(APPEND DEPS_TO_LINK ${DEP_NAME})
    endforeach()

    list(REMOVE_DUPLICATES DEPS_TO_LINK)

    add_executable(${TARGET_NAME})
    target_sources(${TARGET_NAME} PRIVATE ${APP_SOURCES})
    target_include_directories(${TARGET_NAME} PRIVATE ${APP_INCLUDES})
    target_compile_options(${TARGET_NAME} PRIVATE ${APP_COMPILE_FLAGS})
    target_link_libraries(${TARGET_NAME} PRIVATE ${DEPS_TO_LINK})
    target_link_options(${TARGET_NAME} PRIVATE ${APP_COMPILE_FLAGS})
endfunction()

## Registers a module and it's dependencies
function(XMOS_REGISTER_MODULE)
    if(ARGC GREATER 0)
        ## Do not output added library message
        string(FIND ${ARGV0} "silent" ${LIB_NAME}_SILENT_FLAG)
        if(${LIB_NAME}_SILENT_FLAG GREATER -1)
            set(${LIB_NAME}_SILENT_FLAG True)
        endif()
    endif()

    set(DEP_MODULE_LIST "")
    if(NOT TARGET ${LIB_NAME})
        if(NOT ${LIB_NAME}_SILENT_FLAG)
            add_library(${LIB_NAME} STATIC)
            set_property(TARGET ${LIB_NAME} PROPERTY VERSION ${LIB_VERSION})
        else()
            add_library(${LIB_NAME} OBJECT EXCLUDE_FROM_ALL)
            set_property(TARGET ${LIB_NAME} PROPERTY VERSION ${LIB_VERSION})
        endif()

        set(DEP_OPTIONAL_HEADERS "")
        set(DEP_FILE_FLAGS "")
        foreach(DEP_MODULE ${LIB_DEPENDENT_MODULES})
            string(REGEX MATCH "^[A-Za-z0-9_ -]+" DEP_NAME ${DEP_MODULE})
            string(REGEX REPLACE "^[A-Za-z0-9_ -]+" "" DEP_FULL_REQ ${DEP_MODULE})

            list(APPEND DEP_MODULE_LIST ${DEP_NAME})
            if("${DEP_FULL_REQ}" STREQUAL "")
                message(FATAL_ERROR "Missing dependency version requirement for ${DEP_NAME} in ${LIB_NAME}.\nA version requirement must be specified for all dependencies.")
            endif()

            string(REGEX MATCH "[0-9.]+" VERSION_REQ ${DEP_FULL_REQ} )
            string(REGEX MATCH "[<>=]+" VERSION_QUAL_REQ ${DEP_FULL_REQ} )

            # Add dependencies directories
            if(NOT TARGET ${DEP_NAME})
                if(EXISTS ${XMOS_MODULES_ROOT_DIR}/${DEP_NAME})
                    add_subdirectory("${XMOS_MODULES_ROOT_DIR}/${DEP_NAME}"  "${CMAKE_CURRENT_BINARY_DIR}/${DEP_NAME}")
                else()
                    message(FATAL_ERROR "Missing dependency ${DEP_NAME}")
                endif()

                get_target_property(${DEP_NAME}_optinc ${DEP_NAME} OPTIONAL_HEADERS)
                list(APPEND DEP_OPTIONAL_HEADERS ${${DEP_NAME}_optinc})
            endif()

            # Check dependency version
            get_target_property(DEP_VERSION ${DEP_NAME} VERSION)

            if(DEP_VERSION VERSION_EQUAL VERSION_REQ)
                string(FIND ${VERSION_QUAL_REQ} "=" DEP_VERSION_CHECK)
            elseif(DEP_VERSION VERSION_LESS VERSION_REQ)
                string(FIND ${VERSION_QUAL_REQ} "<" DEP_VERSION_CHECK)
            elseif(DEP_VERSION VERSION_GREATER VERSION_REQ)
                string(FIND ${VERSION_QUAL_REQ} ">" DEP_VERSION_CHECK)
            endif()

            if(${DEP_VERSION_CHECK} EQUAL "-1")
                message(WARNING "${LIB_NAME} dependency ${DEP_MODULE} not met.  Found ${DEP_NAME}(${DEP_VERSION}).")
            endif()
        endforeach()

        if(NOT ${LIB_NAME}_SILENT_FLAG)
            get_property(XMOS_TARGETS_LIST GLOBAL PROPERTY XMOS_TARGETS_LIST)
            set_property(GLOBAL PROPERTY XMOS_TARGETS_LIST "${XMOS_TARGETS_LIST};${LIB_NAME}")
        endif()

        ## Set optional headers
        if(${LIB_NAME}_DEPS_ONLY_FLAG)
            set(LIB_OPTIONAL_HEADERS ${DEP_OPTIONAL_HEADERS})
        else()
            list(APPEND LIB_OPTIONAL_HEADERS ${DEP_OPTIONAL_HEADERS})
        endif()
        list(REMOVE_DUPLICATES LIB_OPTIONAL_HEADERS)
        list(FILTER LIB_OPTIONAL_HEADERS EXCLUDE REGEX "^.+-NOTFOUND$")
        set_property(TARGET ${LIB_NAME} PROPERTY OPTIONAL_HEADERS ${LIB_OPTIONAL_HEADERS})

        foreach(file ${LIB_XC_SRCS})
            set_source_files_properties(${file} PROPERTIES LANGUAGE C)
        endforeach()

        target_sources(${LIB_NAME} PUBLIC ${LIB_XC_SRCS} ${LIB_C_SRCS} ${LIB_ASM_SRCS})
        target_include_directories(${LIB_NAME} PUBLIC ${LIB_INCLUDES})

        if(DEFINED AFR_ROOT_DIR)
            include("${AFR_VENDORS_DIR}/xmos/lib_rtos_support/cmake_utils/xmos_afr_support.cmake")
        endif()

        target_link_libraries(
            ${LIB_NAME}
            PRIVATE
                ${DEP_MODULE_LIST}
        )
        target_compile_options(${LIB_NAME} PRIVATE ${LIB_ADD_COMPILER_FLAGS})

        if(NOT ${LIB_NAME}_SILENT_FLAG)
            message("Added ${LIB_NAME} (${LIB_VERSION})")
        endif()
    endif()
endfunction()
