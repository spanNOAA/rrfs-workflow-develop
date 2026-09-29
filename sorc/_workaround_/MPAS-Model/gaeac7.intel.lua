help([[
This module loads libraries for MPAS-Model
]])

whatis([===[Loads libraries for MPAS-Model ]===])

prepend_path("MODULEPATH", "/opt/cray/modulefiles")
prepend_path("MODULEPATH", "/opt/cray/pe/lmod/modulefiles/craype-targets/default")
prepend_path("MODULEPATH", "/opt/cray/pe/lmod/modulefiles/core")
prepend_path("MODULEPATH", "/gpfs/f7/wrfruc/world-shared/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

load("stack-oneapi/2024.2.1")
load("stack-cray-mpich/8.1.32")
load("cmake/3.27.9")
load("parallel-netcdf/1.12.3")
load("parallelio/2.6.2")

if mode() == "load" then
  setenv("PNETCDF", os.getenv("parallel_netcdf_ROOT"))
  setenv("LD_PRELOAD", "/lib64/libm.so.6")
end
if mode() == "unload" then
  unsetenv("PNETCDF")
  unsetenv("LD_PRELOAD")
end

setenv("CMAKE_C_COMPILER", "mpicc")
setenv("CMAKE_CXX_COMPILER", "mpic++")
setenv("CMAKE_Fortran_COMPILER", "mpifort")
