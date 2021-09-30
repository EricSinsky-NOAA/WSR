#!/bin/ksh

set -x

msg="JOB $job HAS BEGUN"
echo "$msg"

cd $DATA

export pgm=wsr_creategfs_1p0.sh
$USHwsr/wsr_creategfs_1p0.sh
export err=$?; # err_chk
if [ $err -ne 0 ]; then
	echo "WARNING: $USHwsr/wsr_creategfs_1p0.sh return code is $err"
fi

export pgm=wsr_creategfs.sh
$USHwsr/wsr_creategfs.sh
export err=$?; # err_chk
if [ $err -ne 0 ]; then
	echo "WARNING: $USHwsr/wsr_creategfs.sh return code is $err"
fi

export pgm=wsr_createcmc_1p0.sh
$USHwsr/wsr_createcmc_1p0.sh
export err=$?; # err_chk
if [ $err -ne 0 ]; then
	echo "WARNING: $USHwsr/wsr_createcmc_1p0.sh return code is $err"
fi

export pgm=wsr_createcmc.sh
$USHwsr/wsr_createcmc.sh
export err=$?; # err_chk
if [ $err -ne 0 ]; then
	echo "WARNING: $USHwsr/wsr_createcmc.sh return code is $err"
fi

export pgm=wsr_createecmwf.sh
$USHwsr/wsr_createecmwf.sh
export err=$?; # err_chk
if [ $err -ne 0 ]; then
	echo "WARNING: $USHwsr/wsr_createecmwf.sh return code is $err"
fi

echo "JOB $job HAS COMPLETED NORMALLY"

exit
