#PBS -N wsr_prep_prod_2021021500
#PBS -j oe
#PBS -S /bin/bash
#PBS -q dev
#PBS -A GEFS-DEV
#PBS -l walltime=1:20:00
#PBS -l place=vscatter,select=1:ncpus=16:mem=3GB:mpiprocs=16:ompthreads=1
#PBS -l debug=true

set -x
#module purge

date

cd $PBS_O_WORKDIR

export envir='dev'
export RUN_ENVIR='dev'
export WHERE_AM_I='wcoss2'
export EXPID=$(basename $(readlink -f `pwd`/../)) #'wsr_wcoss2_final'
export SOURCEDIR="/lfs/h2/emc/ens/noscrub/$LOGNAME/wsr/${EXPID}"
export GEFS_ROCOTO="${SOURCEDIR}/rocoto"
export WORKDIR="/lfs/h2/emc/ptmp/$LOGNAME/o/${EXPID}"

export PDY='20210215' #'20201120' #'20210215'
export cyc='00'
export job=wsr_prep_${EXPID}_${PDY}${cyc}

#set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $SOURCEDIR/versions/run.ver

module purge
module load envvar/$envvar_ver
module load intel/$intel_ver
module load PrgEnv-intel/$PrgEnv_intel_ver

module load craype/$craype_ver
module load cray-mpich/$cray_mpich_ver
module load cray-pals/$cray_pals_ver

module load prod_util/$prod_util_ver
module load prod_envir/$prod_envir_ver

module load libjpeg/$libjpeg_ver
module load grib_util/$grib_util_ver

module load cfp/$cfp_ver
export USE_CFP=YES
module list

export KEEPDATA=YES

export RUN_ENVIR=${RUN_ENVIR:-dev}
export envir=${envir:-dev}
#export ver=${ver:-$(echo ${wsr_ver:-v3.3.0}|cut -c1-4)}

export NET=${NET:-wsr}
export RUN=${RUN:-wsr}

export SENDDBN=${SENDDBN:-NO}
export SENDDBN_NTC=${SENDDBN_NTC:-NO}

#export PARAFLAG=${PARAFLAG:-YES}
export SENDECF=${SENDECF:-NO}
export SENDCOM=${SENDCOM:-YES}
export KEEPDATA=${KEEPDATA:-NO}

# Enviorenmenat variables related to Development work place and output files
#
export HOMEwsr=$SOURCEDIR
#export COMROOT=$WORKDIR/$envir/com
export DATAROOT=$WORKDIR/tmp

#export COMINgens=/lfs/h2/emc/ens/noscrub/Xianwu.Xue/wsr/HOMEdata_WSR/com/gefs/prod
#export COMPATH=/lfs/h2/emc/ens/noscrub/Xianwu.Xue/wsr/HOMEdata_WSR/com/naefs/prod
#export COMINcmce=/lfs/h2/emc/ens/noscrub/Xianwu.Xue/wsr/HOMEdata_WSR/com/naefs/prod
#export DCOMROOT=/lfs/h2/emc/ens/noscrub/Xianwu.Xue/wsr/HOMEdata_WSR/dcom

export HOMEdata=/lfs/h2/emc/ens/noscrub/Xianwu.Xue/wsr/HOMEdata_WSR
#export HOMEdata=/lfs/h1/ops

export COMPATH=$HOMEdata/canned/com/gefs:$HOMEdata/canned/com/naefs:${WORKDIR}/$envir/com/${NET} #$COMROOT/$RUN
export DCOMROOT=${HOMEdata}/canned/dcom


# Export List
export MP_EUIDEVICE=sn_all
export MP_EUILIB=us
export MP_TASK_AFFINITY=core

export MP_PGMMODEL=mpmd
export MP_CSS_INTERRUPT=yes

#export OMP_NUM_THREADS=1

export envir=prod
#${GEFS_ROCOTO}/bin/wcoss2/wsr_prep.sh
${HOMEwsr:?}/jobs/JWSR_PREP
