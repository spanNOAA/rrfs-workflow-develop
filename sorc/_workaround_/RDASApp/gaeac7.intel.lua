help([[
Load environment for running the RDAS application with Intel compilers and MPI.
]])

local pkgName    = myModuleName()
local pkgVersion = myModuleVersion() or ""
local pkgNameVer = myModuleFullName()

prepend_path("MODULEPATH", "/opt/cray/modulefiles")
prepend_path("MODULEPATH", "/opt/cray/pe/lmod/modulefiles/craype-targets/default")
prepend_path("MODULEPATH", "/opt/cray/pe/lmod/modulefiles/core")
prepend_path("MODULEPATH", "/gpfs/f7/wrfruc/world-shared/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

load("stack-oneapi/2024.2.1")
load("stack-python/3.11.7")
load("stack-cray-mpich/8.1.32")
load("jedi-mpas-env/1.0.0")
load("jedi-fv3-env/1.0.0")
load("py-jinja2/3.1.4")

unload("cray-libsci/24.11.0")
setenv("CC","cc")
setenv("FC","ftn")
setenv("CXX","CC")

prepend_path("LD_LIBRARY_PATH", "/opt/cray/pe/mpich/8.1.32/ofi/intel/2022.1/lib")

if mode() == "load" then
  setenv("LD_PRELOAD", "/lib64/libm.so.6")
end
if mode() == "unload" then
  unsetenv("LD_PRELOAD")
end

local mpiexec = '/usr/bin/srun'
local mpinproc = '-n'
setenv('MPIEXEC_EXEC', mpiexec)
setenv('MPIEXEC_NPROC', mpinproc)

whatis("Name: ".. pkgName)
whatis("Version: ".. tostring(pkgVersion or ""))
whatis("Category: RDASApp")
whatis("Description: Load all libraries needed for RDASApp")

local my_path = myFileName()
if my_path then
  local repo_root = my_path:match("(.*)/sorc/RDASApp/modulefiles/RDAS/.*")
  if repo_root then
    prepend_path("LD_LIBRARY_PATH", pathJoin(repo_root, "sorc/RDASApp/build/lib"))
  end
end
