#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHrrfs/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u -x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that generates grid files.
========================================================================"
#
#-----------------------------------------------------------------------
#
# OpenMP environment setting
#
#-----------------------------------------------------------------------
#
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=1024m
#
#-----------------------------------------------------------------------
#
# Set the machine-dependent run command.  Also, set resource limits as
# necessary.
#
#-----------------------------------------------------------------------
#
ulimit -a
APRUN="time"
#
#-----------------------------------------------------------------------
#
# For the fire weather grid, read in the center lat/lon from the
# operational NAM fire weather nest.  The center lat/lon is set by the
# SDM.  When RRFS is implemented, a similar file will be needed.
# Rewrite the default center lat/lon values in var_defns.sh, if needed.
# Then call a Python script to determine if the nest falls inside the
# RRFS computational grid based on the center lat/lon.
#
#-----------------------------------------------------------------------
#
if [ ${WGF} = "firewx" ]; then
  hh="${CDATE:8:2}"
  firewx_loc="${COMINnam}/input/nam_firewx_loc"
  center_lat=${LAT_CTR}
  center_lon=${LON_CTR}
  LAT_CTR=`grep ${hh}z $firewx_loc | awk '{print $2}'`
  LON_CTR=`grep ${hh}z $firewx_loc | awk '{print $3}'`

  if [ ${center_lat} != ${LAT_CTR} ] || [ ${center_lon} != ${LON_CTR} ]; then
    sed -i -e "s/${center_lat}/${LAT_CTR}/g" ${GLOBAL_VAR_DEFNS_FP}
    sed -i -e "s/${center_lon}/${LON_CTR}/g" ${GLOBAL_VAR_DEFNS_FP}
    . ${GLOBAL_VAR_DEFNS_FP}
  fi

  python ${USHrrfs}/rrfsfw_domain.py ${LAT_CTR} ${LON_CTR}
  if [[ $? != 0 ]]; then
    err_exit "WARNING: Problem with the requested fire weather grid - ABORT"
  fi
fi
#
#-----------------------------------------------------------------------
#
# Generate grid file.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "Starting grid file generation..."
if [ "${GRID_GEN_METHOD}" = "GFDLgrid" ]; then
  #
  # Generate a GFDLgrid-type of grid.
  #
  nx_t6sg=$(( 2*GFDLgrid_RES ))
  grid_name="${GRID_GEN_METHOD}"

  export pgm="make_hgrid"
  . prep_step

  $APRUN ${EXECrrfs}/$pgm \
    --grid_type gnomonic_ed \
    --nlon ${nx_t6sg} \
    --grid_name ${grid_name} \
    --do_schmidt \
    --stretch_factor ${STRETCH_FAC} \
    --target_lon ${LON_CTR} \
    --target_lat ${LAT_CTR} \
    --nest_grid \
    --parent_tile 6 \
    --refine_ratio ${GFDLgrid_REFINE_RATIO} \
    --istart_nest ${ISTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
    --jstart_nest ${JSTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
    --iend_nest ${IEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
    --jend_nest ${JEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
    --halo 1 \
    --great_circle_algorithm >>$pgmout 2>${DATA}/errfile
  export err=$?; err_chk
  mv ${DATA}/errfile ${DATA}/errfile_make_hgrid

  # Set the name of the regional grid file.
  grid_fn="${grid_name}.tile${TILE_RGNL}.nc"

elif [ "${GRID_GEN_METHOD}" = "ESGgrid" ]; then
  #
  # Generate a ESGgrid-type of grid.
  #
  # Create the namelist file read
  rgnl_grid_nml_fp="${DATA}/${RGNL_GRID_NML_FN}"

  # Create a multiline variable that consists of a yaml-compliant string
  # specifying the values that the namelist variables need to be set to
  # (one namelist variable per line, plus a header and footer).
  settings="
'regional_grid_nml': {
    'plon': ${LON_CTR},
    'plat': ${LAT_CTR},
    'delx': ${DEL_ANGLE_X_SG},
    'dely': ${DEL_ANGLE_Y_SG},
    'lx': ${NEG_NX_OF_DOM_WITH_WIDE_HALO},
    'ly': ${NEG_NY_OF_DOM_WITH_WIDE_HALO},
    'pazi': ${PAZI},
 }
"

  # Call the python script to create the namelist file.
  ${USHrrfs}/set_namelist.py -q -u "$settings" -o ${rgnl_grid_nml_fp}
  export err=$?
  if [ $err -ne 0 ]; then
    err_exit "Call to python script set_namelist.py to set the variables 
  in the regional_esg_grid namelist file failed. Parameters passed to this 
  script are:
  Full path to output namelist file:
    rgnl_grid_nml_fp = \"${rgn_grid_nml_fp}\"
  Namelist settings specified on command line (these have highest precedence):
    settings =
$settings"
  fi

  # Call the executable that generates the grid file.
  export pgm="regional_esg_grid"
  . prep_step

  $APRUN ${EXECrrfs}/$pgm ${rgnl_grid_nml_fp} >>$pgmout 2>${DATA}/errfile
  export err=$?; err_chk
  mv ${DATA}/errfile ${DATA}/errfile_regional_esg_grid

  # Set the name of the regional grid file generated by the above call.
  # This must be the same name as in the regional_esg_grid code.
  grid_fn="regional_grid.nc"
fi

# Set the full path to the grid file generated above.
grid_fp="${DATA}/${grid_fn}"

print_info_msg "$VERBOSE" "Grid file generation completed successfully."
#
#-----------------------------------------------------------------------
#
# Calculate the regional grid's global uniform cubed-sphere grid equivalent
# resolution.
#
#-----------------------------------------------------------------------
#
export pgm="global_equiv_resol"
. prep_step

$APRUN ${EXECrrfs}/$pgm "${grid_fp}" >>$pgmout 2>${DATA}/errfile
export err=$?; err_chk
mv ${DATA}/errfile ${DATA}/errfile_global_equiv_resol

# Make the following (reading of res_equiv) a function in another file
# so that it can be used both here and in the exrrfs_make_orog.sh
# script.
res_equiv=$( ncdump -h "${grid_fp}" | \
             grep -o ":RES_equiv = [0-9]\+" | grep -o "[0-9]" )
export err=$?
if [ $err -ne 0 ]; then
  err_exit "Attempt to extract the equivalent global uniform cubed-sphere 
  grid resolution from the grid file (grid_fp) failed:
  grid_fp = \"${grid_fp}\""
fi
res_equiv=${res_equiv//$'\n'/}
#
#-----------------------------------------------------------------------
#
# Set the string CRES that will be comprise the start of the grid file
# name (and other file names later in other tasks/scripts).  Then set its
# value in the variable definitions file.
#
#-----------------------------------------------------------------------
#
if [ "${GRID_GEN_METHOD}" = "GFDLgrid" ]; then
  if [ "${GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES}" = "TRUE" ]; then
    CRES="C${GFDLgrid_RES}"
  else
    CRES="C${res_equiv}"
  fi
elif [ "${GRID_GEN_METHOD}" = "ESGgrid" ]; then
  CRES="C${res_equiv}"
fi
#
#-----------------------------------------------------------------------
#
# Copy the grid file from the run directory (DATA) to COMOUT directory. 
# In the process, rename it such that its name includes CRES and the halo width.
#
#-----------------------------------------------------------------------
#
grid_fp_orig="${grid_fp}"
grid_fn="${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NHW}.nc"
grid_fp="${COMOUT}/fix/${grid_fn}"
cpreq -p "${grid_fp_orig}" "${grid_fn}"
cpreq -p "${grid_fn}" "${grid_fp}"
#
#-----------------------------------------------------------------------
#
# If there are pre-existing orography or climatology files that we will
# be using (i.e. if RUN_TASK_MAKE_OROG or RUN_TASK_MAKE_SURF_CLIMO is set
# to "FALSE", in which case RES_IN_FIXLAM_FILENAMES will not be set to a
# null string), check that the grid resolution contained in the variable
# CRES set above matches the resolution appearing in the names of the
# preexisting orography and/or surface climatology files.
#
#-----------------------------------------------------------------------
#
if [ ! -z "${RES_IN_FIXLAM_FILENAMES}" ]; then
  res="${CRES:1}"
  if [ "$res" -ne "${RES_IN_FIXLAM_FILENAMES}" ]; then
    err_exit "\
The resolution (res) calculated for the grid does not match the resolution
(RES_IN_FIXLAM_FILENAMES) appearing in the names of the orography and/or
surface climatology files:
  res = \"$res\"
  RES_IN_FIXLAM_FILENAMES = \"${RES_IN_FIXLAM_FILENAMES}\""
  fi
fi
#
#-----------------------------------------------------------------------
#
# Partially "shave" the halo from the grid file having a wide halo to
# generate multiple grid files with [6,4,3,0]-grid-wide halos. 
# These are needed as inputs by the forecast model as well as by the code 
# (chgres_cube) that generates the lateral boundary condition files.
#
#-----------------------------------------------------------------------
#
# Set the full path to the "unshaved" grid file (wide halo).
unshaved_fp="${grid_fp}"

export pgm="shave"

halo_num_list=('0' '3' '4')
for halo_num in "${halo_num_list[@]}"; do
  print_info_msg "Shaving grid file with ${halo_num}-cell-wide halo..."

  nml_fn="input.shave.grid.halo${halo_num}"
  shaved_fp="${DATA}/${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${halo_num}.nc"
  printf "%s %s %s %s %s\n" \
  $NX $NY ${halo_num} \"${unshaved_fp}\" \"${shaved_fp}\" \
  > ${nml_fn}

  . prep_step

  $APRUN ${EXECrrfs}/$pgm < ${nml_fn} >>$pgmout 2>${DATA}/errfile
  export err=$?; err_chk
  mv ${DATA}/errfile ${DATA}/errfile_shave_nh${halo_num}
  cpreq -p ${shaved_fp} ${COMOUT}/fix
done
#
#-----------------------------------------------------------------------
#
# Create the grid mosaic files with various cell-wide halos.
#
#-----------------------------------------------------------------------
#
export pgm="make_solo_mosaic"

halo_num_list[${#halo_num_list[@]}]="${NHW}"
for halo_num in "${halo_num_list[@]}"; do
  print_info_msg "Creating grid mosaic file with ${halo_num}-cell-wide halo..."  
  grid_fn="${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${halo_num}.nc"
  grid_fp="${COMOUT}/fix/${grid_fn}"
  mosaic_fn="${CRES}${DOT_OR_USCORE}mosaic.halo${halo_num}.nc"
  mosaic_fp="${COMOUT}/fix/${mosaic_fn}"
  mosaic_fp_prefix="${mosaic_fp%.*}"

  . prep_step

  $APRUN ${EXECrrfs}/$pgm \
      --num_tiles 1 \
      --dir "${DATA}" \
      --tile_file "${grid_fn}" \
      --mosaic "${mosaic_fp_prefix}" >>$pgmout 2>${DATA}/errfile
  export err=$?; err_chk
  mv ${DATA}/errfile ${DATA}/errfile_mosaic_nh${halo_num}  
done
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Grid files with various halo widths generated successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1
