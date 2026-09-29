help([[
  This module loads libraries required for building and running UPP
  on the NOAA RDHPC machine Gaea C7 using Intel oneAPI 2024.2.1.
]])

whatis([===[Loads libraries needed for building the UPP on Gaea C7 ]===])

prepend_path("MODULEPATH", "/opt/cray/modulefiles")
prepend_path("MODULEPATH", "/opt/cray/pe/lmod/modulefiles/craype-targets/default")
prepend_path("MODULEPATH", "/opt/cray/pe/lmod/modulefiles/core")
prepend_path("MODULEPATH", "/gpfs/f7/wrfruc/world-shared/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

stack_oneapi_ver=os.getenv("stack_oneapi_ver") or "2024.2.1"
load(pathJoin("stack-oneapi", stack_oneapi_ver))

stack_cray_mpich_ver=os.getenv("stack_cray_mpich_ver") or "8.1.32"
load(pathJoin("stack-cray-mpich", stack_cray_mpich_ver))

cmake_ver=os.getenv("cmake_ver") or "3.27.9"
load(pathJoin("cmake", cmake_ver))

setenv("zlib_ver", "1.2.11")
load("upp_common")

unload("darshan-runtime")
-- unload("cray-libsci")

setenv("CC","cc")
setenv("CXX","CC")
setenv("FC","ftn")

setenv("CMAKE_Platform","gaea.intel")

setenv("AR", "llvm-ar")
setenv("RANLIB", "llvm-ranlib")
setenv("CMAKE_AR", "/usr/bin/llvm-ar")
setenv("CMAKE_RANLIB", "/usr/bin/llvm-ranlib")
