#!/bin/ksh

set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $SOURCEDIR/versions/wsr_wcoss2.ver

# Load modules
#module list
module purge

module load envvar/$envvar_ver
module load intel/$intel_ver PrgEnv-intel

module load craype/$craype_ver
module load cray-mpich/$cray_mpich_ver
module load cray-pals/$cray_pals_ver

module load prod_util/$prod_util_ver
module load prod_envir/$prod_envir_ver

module load grib_util/$grib_util_ver

#module load cce/11.0.2
#module load gcc/10.2.0
module load libjpeg/$libjpeg_ver

#module load lsf/$lsf_ver

module load cfp/$cfp_ver
export USE_CFP=YES

module list

# For Development
. $GEFS_ROCOTO/bin/wcoss2/common.sh

# Export List
export MP_EUIDEVICE=sn_all
export MP_EUILIB=us
export MP_TASK_AFFINITY=core

export MP_PGMMODEL=mpmd
export MP_CSS_INTERRUPT=yes

# CALL executable job script here
$SOURCEDIR/jobs/JWSR_PREP

