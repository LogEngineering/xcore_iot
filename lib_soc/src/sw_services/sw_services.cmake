if(NOT TARGET SOC_SW_SERVICES_CMAKE)
add_library(SOC_SW_SERVICES_CMAKE INTERFACE)

file(GLOB_RECURSE sw_svc_list "src/sw_services/**/*.cmake")

foreach(sw_svc ${sw_svc_list})
    include(${sw_svc})
    if(LIB_SOC_SW_${SW_SVC_NAME})
        list(APPEND LIB_ADD_COMPILER_FLAGS "-DLIB_SOC_HAS_SW_${SW_SVC_NAME}=1")
        list(APPEND LIB_ADD_COMPILER_FLAGS ${SW_SVC_ADD_COMPILER_FLAGS})
        list(APPEND LIB_XC_SRCS ${SW_SVC_XC_SRCS})
        list(APPEND LIB_C_SRCS ${SW_SVC_C_SRCS})
        list(APPEND LIB_INCLUDES ${SW_SVC_INCLUDES})
        list(APPEND LIB_DEPENDENT_MODULES ${SW_SVC_DEPENDENT_MODULES})
        list(APPEND LIB_OPTIONAL_HEADERS ${SW_SVC_OPTIONAL_HEADERS})
        message("\tAdded ${SW_SVC_NAME} software service for lib_soc")
    else()
        list(APPEND LIB_ADD_COMPILER_FLAGS "-DLIB_SOC_HAS_SW_${SW_SVC_NAME}=0")
    endif()
endforeach()
endif()