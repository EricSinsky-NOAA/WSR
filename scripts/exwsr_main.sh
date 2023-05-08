#!/bin/ksh

set -xa
export PS4='$SECONDS + $(basename ${0})[$LINENO]'

###########################################################################
# This is the main script to produce the U.MIAMI-NCEP Ensemble Transform  #
# Kalman Filter targeting products                                        #
#                                                                         #
# INPUT COMIN_setup (read the file targdata.d):                           #
# ========================================                                #
# curdate     : the current date (8digits)                                #
# cases       : number of targeting situations to calculate               # 
# resolution  : code for the resolution of the ensemble used              #
#                1) 2.5 X 2.5 degree grib                                 #
# ivnorm       : code for the verifying norm to be used                   #
#                1) 200mb, 500mb, 850mb (u,v) winds norm                  #
#                2) 200mb, 500mb, 850mb (u,v,T) norm                      #
#                3) 850mb winds, 12-hr precipitation, mslp norm           #
# radvr       : radius of the verification area                           #
# lon1                                                                    #
# lon2                                                                    #
# lat1                                                                    #
# lat2        : define the boundaries of the scanned geog.region          #
# obsdate[i]  : observation date for case i                               #
# veridate[i] : verification date for case i                              #
# vrlon[i]    : longitude of ver. region for case i                       #
# vrlat[i]    : latitude of ver. region for case i                        #
#                                                                         #
# (**) inconsequential to this program                                    #  
#                                                                         #
# ADJUSTABLE PARAMETERS (can be changed with editing this script):        #
# ===============================================================         #
# mem        : number of ensemble perturbations                           #
# nd         : the number of points in the target region                  #
# DATA       : the directory from which this script is run                #
# COMIN_setup: working directory on SP                                    #
# COMIN      : directory for the input data from wsr_prep                 #
# COMOUT     : directory to which output is directed                      #
#                                                                         #
########################################################################### 

## UPDATED TO SUPPORT UNIQUE FILENAMES FOR SUMMARY CHARTS AND FLIGHT ##
## INITIAL
## HISTOGRAMS, 2/13/02 J. Mosakatis  ##
## UPDATED TO SUPPORT MORE MEMBERS 12/12/06 Yucheng Song

## UPDATED TO SUPPORT RESCALING AND MORE REALISTIC REPRESENTATION OF THE 
## ROUTINE OBSERVATIONAL NETWORK (NORTHERN HEMISPHERE RAWINSONDES AND 
## SATELLITE TEMPERATURE OBSERVATIONS)
## UPDATED TO USE NEW STANDARDS for WCOSS2 by Xianwu Xue
 
cd $DATA
cp $FIXwsr/wsr_track.* .

#############################################
# Read in targdata.d header (first 9 lines) #
#############################################

curdate=`head -1 $COMIN_setup/targdata.d`
cases=`head -2 $COMIN_setup/targdata.d | tail -1`
resolution=`head -3 $COMIN_setup/targdata.d | tail -1`
ivnorm=`head -4 $COMIN_setup/targdata.d | tail -1`
radvr=`head -5 $COMIN_setup/targdata.d | tail -1`
lon1=`head -6 $COMIN_setup/targdata.d | tail -1`
lon2=`head -7 $COMIN_setup/targdata.d | tail -1`
lat1=`head -8 $COMIN_setup/targdata.d | tail -1`
lat2=`head -9 $COMIN_setup/targdata.d | tail -1`

londiff=`expr ${lon2} - ${lon1}`
latdiff=`expr ${lat2} - ${lat1}`
nlon=`expr ${londiff} / 5 + 1`
nlat=`expr ${latdiff} / 5 + 1`

reso=2.5

#### Read in targdata.d body (remaining lines) ####
#### Assumes 6 lines per case ####

i=1
while [[ $i -le $cases ]]
do
	case_id[i]=$i
	line=`expr ${i} \* 6 + 4`
	obsdate[i]=`head -n $line $COMIN_setup/targdata.d | tail -1`
	line=`expr $line + 1`
	veridate[i]=`head -n $line $COMIN_setup/targdata.d | tail -1`
	line=`expr $line + 1`
	vrlon[i]=`head -n $line $COMIN_setup/targdata.d | tail -1`
	line=`expr $line + 1`
	check_vrlon=`echo "${vrlon[$i]} <0"|bc -l`
	if [[ ${check_vrlon} -eq 1 ]]
	then
		vrlon[i]=`echo "360 + ${vrlon[$i]}" |bc`
	fi
	vrlat[i]=`head -n $line $COMIN_setup/targdata.d | tail -1`
	line=`expr $line + 1`
	priority[i]=`head -n $line $COMIN_setup/targdata.d | tail -1`
	line=`expr $line + 1`
	comments[i]=`head -n $line $COMIN_setup/targdata.d | tail -1`
	i=`expr ${i} + 1`
done

############################################################
# SET VARIABLES AND DIRECTORIES
############################################################

ensdate=${curdate}00
ymmdd=`echo $ensdate|cut -c3-8`

# Derivative quantities for DTS 

i=1
while [[ $i -le $cases ]]
do
	radvr[i]=$radvr
	inittime[i]=$ensdate
	#opttime[i]=`/nwprod/util/exec/nhour ${obsdate[$i]} ${inittime[$i]}`
	opttime[i]=`$NHOUR ${obsdate[$i]} ${inittime[$i]}`
	#leadtime[i]=`/nwprod/util/exec/nhour ${veridate[$i]} ${obsdate[$i]}`
	leadtime[i]=`$NHOUR ${veridate[$i]} ${obsdate[$i]}`
	vrlatu[i]=`echo ${vrlat[$i]} + ${radvr[$i]} \/ 111.199|bc`
	vrlatl[i]=`echo ${vrlat[$i]} - ${radvr[$i]} \/ 111.199|bc`
	vrlonl[i]=`echo ${vrlon[$i]} - ${radvr[$i]} \/ 111.199|bc`
	vrlonu[i]=`echo ${vrlon[$i]} + ${radvr[$i]} \/ 111.199|bc`
	i=`expr ${i} + 1`
done

KSEC47=100.0

#### figure out if wsr search area is being used
searchareacode=0
if [[ ${lon1} -eq 80 && ${lon2} -eq 300 ]]
then
	if [[ ${lat1} -eq 0 && ${lat2} -eq 80 ]]
	then
		searcharea='wsr'
		searchareacode=1
	fi
fi

#####################################################
# Region to plot signal variance map
#####################################################
npts12=20000
lonl=80
lonu=360
latl=00
latu=80

londiff=`expr ${lonu} - ${lonl}`
latdiff=`expr ${latu} - ${latl}`
nlo=`expr ${londiff} / 5 + 1`
nla=`expr ${latdiff} / 5 + 1`

 

###########################################################
# CALCULATE lt1 AND lt2 FOR ALL OF THE CASES
###########################################################

i=1
while [[ $i -le $cases ]]
do
	dloop=${ensdate}
	lt1[$i]=0
	while [[ ${dloop} -lt ${obsdate[$i]} ]]
	do
		lt1[$i]=`expr ${lt1[$i]} + 12`
		#dloop=`/nwprod/util/exec/ndate +${lt1[$i]} ${ensdate}`
		dloop=`$NDATE +${lt1[$i]} ${ensdate}`
	done

	lt2[$i]=${lt1[$i]}
	while [[ ${dloop} -lt ${veridate[$i]} ]]
	do
		lt2[$i]=`expr ${lt2[$i]} + 12`
		#dloop=`/nwprod/util/exec/ndate +${lt2[$i]} ${ensdate}`
		dloop=`$NDATE +${lt2[$i]} ${ensdate}`
	done

	if [[ ${lt1[$i]} -gt 216 ]]; then
		echo lt1[$i]=${lt1[$i]} limited to 216 hours
		lt1[$i]=216
	fi

	if [[ ${lt2[$i]} -gt 216 ]]; then
		echo lt2[$i]=${lt2[$i]} limited to 216 hours
		lt2[$i]=216
	fi

	i=`expr $i + 1`
done

maxlt2=${lt2[1]}
minlt2=${lt2[1]}
maxlt1=${lt1[1]}
minlt1=${lt1[1]}
i=2
while [[ $i -le $cases ]]
do 
	if [[ ${lt2[$i]} -gt ${maxlt2} ]]
	then
		maxlt2=${lt2[$i]}
	fi
	if [[ ${lt2[$i]} -lt ${minlt2} ]]
	then
		minlt2=${lt2[$i]}
	fi
	if [[ ${lt1[$i]} -gt ${maxlt1} ]]
	then
		maxlt1=${lt1[$i]}
	fi
	if [[ ${lt1[$i]} -lt ${minlt1} ]]
	then
		minlt1=${lt1[$i]}
	fi
	i=`expr $i + 1`
done

if [[ "$SENDCOM" = "YES" ]]
then

	i=1
	while [[ $i -le ${cases} ]]
	do
		echo "export lt1case${i}=${lt1[$i]}"  >> $COMOUT/ltinfo.env
		echo "export lt2case${i}=${lt2[$i]}"  >> $COMOUT/ltinfo.env
		i=`expr $i + 1`
	done

	echo "export minlt1=$minlt1"  >> $COMOUT/ltinfo.env
	echo "export maxlt1=$maxlt1"  >> $COMOUT/ltinfo.env

fi

##########################################################################
#  CALCULATE ENSEMBLE PERTURBATIONS
##########################################################################
#ensdate2=`/nwprod/util/exec/ndate -${hhdiff} ${ensdate}`
ensdate2=`$NDATE -${hhdiff} ${ensdate}`

sigtime=`expr ${maxlt1} + 84`
if [[ ${sigtime} -gt ${maxlt2} && ${sigtime} -le 240 ]]
then
	maxtint=`expr ${sigtime} / 12`
elif [[ ${sigtime} -gt 240 ]]
then
	#maxtint=`expr 204 / 12`
	# RLW 20200123 correct apparent typo
	maxtint=`expr 240 / 12`
else
	maxtint=`expr ${maxlt2} / 12`
fi
mintint=`expr ${minlt1} / 12`

#ensdateold=`/nwprod/util/exec/ndate -24 ${ensdate}`
ensdateold=`$NDATE -24 ${ensdate}`
#ensdate2old=`/nwprod/util/exec/ndate -24 ${ensdate2}`
ensdate2old=`$NDATE -24 ${ensdate2}`
prevdate=`echo $ensdateold|cut -c1-8`
prev2date=`echo $ensdate2old|cut -c1-8`

nomrf=0
noecmwf=0
nocmc=0

oldmrf=0
oldecmwf=0
oldcmc=0
mkmrf='NCEP'
mkecmwf='ECMWF'
mkcmc='CMC'

ensdategr=${ensdate}
tint=$mintint
while [[ ${tint} -le ${maxtint} ]]
do
	mlt=`expr ${tint} \* 12`
	mltold=`expr ${mlt} + 24`
	elt=`expr ${mlt} + $hhdiff `
	eltold=`expr ${elt} + 24  `
	clt=`expr ${mlt}`
	cltold=`expr ${clt} + 24  `
	mfn=`expr 200 + ${tint}`
	efn=`expr 250 + ${tint}`
	cfn=`expr 300 + ${tint}`
	[[ $mlt -le 9 ]] && mlt=0$mlt
	[[ $elt -le 9 ]] && elt=0$elt
	[[ $clt -le 9 ]] && clt=0$clt
	if [[ nomrf -ne 1 ]]; then
		fn=${COMIN}.${curdate}/prep/nc${ensdate}_${mlt}_ens.d
		if [[ -f $fn ]]
		then
			cp $fn fort.${mfn}
			ensdategr=${ensdate}
		else
			fn=${COMIN}.${prevdate}/prep/nc${ensdateold}_${mltold}_ens.d
			if [[ -f $fn ]]
			then
				cp $fn fort.${mfn}
				oldmrf=1
				ensdategr=${ensdateold}
			else
				nomrf=1
				memnc=0
				mkmrf=''
			fi
		fi
	else
		memnc=0
		mkmrf=''
	fi
	if [[ noecmwf -ne 1 ]]; then
		fn=${COMIN}.${curdate}/prep/ec${ensdate2}_${elt}_ens.d
		if [[ -f $fn ]]
		then
			cp $fn fort.${efn}
		else
			fn=${COMIN}.${prev2date}/prep/ec${ensdate2old}_${eltold}_ens.d
			if [[ -f $fn ]]
			then
				cp $fn fort.${efn}
				oldecmwf=1
			else
				noecmwf=1
				memec=0
				mkecmwf=''
			fi
		fi
	else
		memec=0
		mkecmwf=''
	fi
	if [[ nocmc -ne 1 ]] ; then
		fn=${COMIN}.${curdate}/prep/cm${ensdate}_${clt}_ens.d
		if [[ -f $fn ]]
		then
			cp $fn fort.${cfn}
		else
			fn=${COMIN}.${prevdate}/prep/cm${ensdateold}_${cltold}_ens.d
			if [[ -f $fn ]]
			then
				cp $fn fort.${cfn}
				oldcmc=1
			else
				nocmc=1
				memcm=0
				mkcmc=''
			fi
		fi
	else
		memcm=0
		mkcmc=''
	fi

	tint=`expr ${tint} + 1`

done

((mem=memnc+memec+memcm))
((nocomb=nomrf+noecmwf+nocmc))
ensemble=$mkmrf+$mkecmwf+$mkcmc

if [[ ${nomrf} -eq 1 && ${noecmwf} -eq 1 && ${nocmc} -eq 1 ]]
then
	echo "THERE IS NOT ENOUGH ENSEMBLE $COMIN_setup TO PERFORM THE CALCULATIONS"
	echo "PROGRAM IS ABORTED"
	exit
fi 	

echo "$idim $jdim $mem $memnc $memec $memcm $nvar $mintint $maxtint" > params
export pgm=wsr_calcperts
. prep_step
startmsg

$EXECwsr/wsr_calcperts < params >> $pgmout 2> errfile
export err=$?;err_chk

export pgm=wsr_calcspread
. prep_step
startmsg
$EXECwsr/wsr_calcspread < params >> $pgmout 2> errfile
export err=$?;err_chk

tint=$mintint
while [[ ${tint} -le ${maxtint} ]]
do
	mlt=`expr ${tint} \* 12`
	elt=`expr ${mlt} + 12`

	mfn=`expr 1500 + ${tint}`
	mv fort.${mfn} perts_${ymmdd}_${mlt}.d

	sfn_uv=`expr 1600 + ${tint}`
	sfn_uvt=`expr 1620 + ${tint}`
	sfn_sfc=`expr 1640 + ${tint}`

	mv fort.${sfn_uv} sp${ymmdd}_uv_${mlt}.d
	mv fort.${sfn_uvt} sp${ymmdd}_uvt_${mlt}.d
	mv fort.${sfn_sfc} sp${ymmdd}_sfc_${mlt}.d

	tint=`expr ${tint} + 1`
done

mk2=1
mk3=1
mk4=1
mk5=1
mk6=1
mk7=1
mk8=1
mk9=1
mk10=1
flights_24_[0]=0
flights_36_[0]=0
flights_48_[0]=0
flights_60_[0]=0
flights_72_[0]=0
flights_84_[0]=0
flights_96_[0]=0
flights_108_[0]=0
flights_120_[0]=0
case $ivnorm in
	1) vnormgr='u,v'
		flnmcode='WND';;
	2) vnormgr='u,v,T'
		flnmcode='TE';;
	3) vnormgr='low level'
		flnmcode='LL';;
esac
 
cp ${FIXwsr}/*.ctl $DATA/.

##########################################################################
# LOOP THROUGH BY OBSDATE
##########################################################################

start=`expr ${minlt1} / 12`
finish=`expr ${maxlt1} / 12`

nd_sondes=747
nd_satobs200=2123
nd_satobs500=1360
nd_satobs850=1360
let satobstot=${nd_satobs200}+${nd_satobs500}+${nd_satobs850}
let ndtot=${satobstot}+${nd_sondes}
cp $FIXwsr/wsr_nhsondes.d ./fort.7
cp $FIXwsr/wsr_satobs_locs_200.d ./fort.91
cp $FIXwsr/wsr_satobs_locs_500.d ./fort.92
cp $FIXwsr/wsr_satobs_locs_850.d ./fort.90

while [[ ${start} -le ${finish} ]]
do
	lt1=`expr ${start} \* 12`
	flag=0
	i=1
	while [[ ${i} -le ${cases} ]]
	do
		if [ ${lt1[$i]} -eq ${lt1} ]; then
			flag=1
		fi
		i=`expr ${i} + 1`
	done

	if [ ${flag} -eq 1 ]
	then
		export pgm=wsr_tcoeffuvt
		. prep_step

		let ne9=idim*jdim*nv
		let nvtot=9*nd_sondes+satobstot
		echo "$idim $jdim $jdim $mem $nv $ne9 $start $nd_sondes $nd_satobs200 $nd_satobs500 $nd_satobs850 $nvtot $ndtot" > params

		export XLFUNIT_93="perts_${ymmdd}_${lt1}.d"
		export     FORT93="perts_${ymmdd}_${lt1}.d"

		startmsg
		$EXECwsr/wsr_tcoeffuvt < params >> $pgmout 2> errfile
		export err=$?;err_chk
	fi

	start=`expr ${start} + 1`
done


rm fort.7
rm fort.90
rm fort.91
rm fort.92

##########################################################################
#  LOOP THROUGH EVERY CASE
########################################################################## 

i=1
while [[ ${i} -le ${cases} ]]
do
	obsdate=${obsdate[$i]}
	veridate=${veridate[$i]}
	vrlon=${vrlon[$i]}
	vrlat=${vrlat[$i]}
	lt1=${lt1[$i]}
	lt2=${lt2[$i]}
	ltcode=`expr ${lt1} / 12`


	##########################################################################
	#  SUMMARY MAP
	##########################################################################

	rm fort.301
	rm fort.302

	export pgm=wsr_xvvest_allnorms
	. prep_step

	let ne1=idim*jdim*12
	echo "$idim $jdim $mem $ne1 $jdim $i" > params

	export XLFUNIT_99="perts_${ymmdd}_${lt2}.d"
	export     FORT99="perts_${ymmdd}_${lt2}.d"

	startmsg
	$EXECwsr/wsr_xvvest_allnorms < params >> $pgmout 2> errfile
	export err=$?;err_chk

	export pgm=wsr_summ_allnorms
	. prep_step

	let nd9=9*nd
	let nd12=12*nd
	let georad=6367.
	let ne1=idim*jdim*12
	let n2=idim*jdim
	let nvr12=nvr*12
	let ne9=idim*jdim*nv

	echo "$idim $jdim $jdim $mem $lon1 $lon2 $lat2 $lat1 $vrlon $vrlat ${radvr[$i]} $nd $nd9 $nd12 $georad $ne1 $n2 $nvr $nvr12 $nv $ne9 $ltcode $i $ivnorm" > params

	export XLFUNIT_10="targ_${ymmdd}_${lt1}_${lt2}_${mem}.d"
	export     FORT10="targ_${ymmdd}_${lt1}_${lt2}_${mem}.d"
	export XLFUNIT_301="sigvartrack.d"
	export     FORT301="sigvartrack.d"


	startmsg
	export MP_PROCS=$nlon
	#poe $EXECwsr/wsr_summ_allnorms < params >> $pgmout 2> errfile
	#$wsrmpexec $EXECwsr/wsr_summ_allnorms < params >> $pgmout 2> errfile
	#$wsrmpexec -n 48 -ppn 24 --cpu-bind core --depth 2 $EXECwsr/wsr_summ_allnorms < params >> $pgmout 2> errfile
	#$wsrmpexec -n 48 -ppn 24 $EXECwsr/wsr_summ_allnorms < params >> $pgmout 2> errfile
	$wsrmpexec -n 16 $EXECwsr/wsr_summ_allnorms < params >> $pgmout 2> errfile

	export err=$?;err_chk

	##########################################################################
	# Radiosonde station guidance
	##########################################################################

	if [[ ${RAWINSONDES} = YES ]]
	then

		rm fort.10
		rm fort.102*
		rm fort.105*

		readymax2=1021
		readymin2=1022

		cp $FIXwsr/wsr_stationtable ./station_table
		export pgm=wsr_rawin_allnorms
		. prep_step

		let nd9=9*nd
		let nd12=12*nd
		let georad=6367.
		let ne1=idim*jdim*12
		let n2=idim*jdim
		let nvr12=nvr*12
		let ne9=idim*jdim*nv

		echo "$idim $jdim $jdim $mem $vrlon $vrlat ${radvr[$i]} $nd $nd9 $nd12 $nrawin $georad $ne1 $n2 $nvr $nvr12 $nv $ne9 $ltcode $i $ivnorm" > params

		export XLFUNIT_10="station_table"
		export     FORT10="station_table"
		export XLFUNIT_1020="rawin_${ymmdd}_${lt1}_${lt2}_${mem}.d"
		export     FORT1020="rawin_${ymmdd}_${lt1}_${lt2}_${mem}.d"
		export XLFUNIT_1023="station_${ymmdd}_${lt1}_${lt2}_${mem}.d"
		export     FORT1023="station_${ymmdd}_${lt1}_${lt2}_${mem}.d"
		export XLFUNIT_1050="station_${ymmdd}_${lt1}_${lt2}_${mem}.summary"
		export     FORT1050="station_${ymmdd}_${lt1}_${lt2}_${mem}.summary"

		startmsg
		$EXECwsr/wsr_rawin_allnorms < params >> $pgmout 2> errfile
		export err=$?;err_chk
		read ymax2 < fort.${readymax2}
		read ymin2 < fort.${readymin2}

	fi

	##########################################################################
	#  FLIGHT HISTOGRAM
	##########################################################################

	if [ ${searchareacode} -eq 1 ]
	then

		rm fort.102*
		rm fort.103*
		rm fort.104*

		export pgm=wsr_flights_allnorms
		. prep_step

		let nd9=9*nd
		let nd12=12*nd
		let georad=6367.
		let ne1=idim*jdim*12
		let n2=idim*jdim
		let nvr12=nvr*12
		let ne9=idim*jdim*nv

		echo "$idim $jdim $jdim $mem $vrlon $vrlat ${radvr[$i]} $nd $nd9 $nd12 $nflights $georad $ne1 $n2 $nvr $nvr12 $nv $ne9 $ltcode $i $ivnorm $phase" > params

		export XLFUNIT_1010="fli_${ymmdd}_${lt1}_${lt2}_${mem}.d"
		export     FORT1010="fli_${ymmdd}_${lt1}_${lt2}_${mem}.d"

		startmsg
		$EXECwsr/wsr_flights_allnorms < params >> $pgmout 2> errfile
		export err=$?;err_chk

		readtrack1=1017
		readtrack2=1018
		readtrack3=1019
		readymax1=1040
		readymin1=1041

		read ymax1 < fort.${readymax1}
		read ymin1 < fort.${readymin1}
		read fl1 < fort.${readtrack1}
		read fl2 < fort.${readtrack2}
		read fl3 < fort.${readtrack3}
		caseflightA[$i]=${fl1}
		caseflightB[$i]=${fl2}
		caseflightC[$i]=${fl3}

		#### sort non-repeating flights by obsdate ####
		obcd=`expr ${lt1[$i]} / 12`
		for num in ${readtrack1} ${readtrack2} ${readtrack3}
		do
			read flight < fort.${num}
			case $obcd in
				2) ct=`expr ${mk2} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_24_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_24_[$mk2]=${flight}
						mk2=`expr ${mk2} + 1`
					fi;;
				3) ct=`expr ${mk3} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_36_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_36_[$mk3]=${flight}
						mk3=`expr ${mk3} + 1`
					fi;;
				4) ct=`expr ${mk4} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_48_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_48_[$mk4]=${flight}
						mk4=`expr ${mk4} + 1`
					fi;;
				5) ct=`expr ${mk5} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_60_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_60_[$mk5]=${flight}
						mk5=`expr ${mk5} + 1`
					fi;;
				6) ct=`expr ${mk6} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_72_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_72_[$mk6]=${flight}
						mk6=`expr ${mk6} + 1`
					fi;;
				7) ct=`expr ${mk7} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_84_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_84_[$mk7]=${flight}
						mk7=`expr ${mk7} + 1`
					fi;;
				8) ct=`expr ${mk8} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_96_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_96_[$mk8]=${flight}
						mk8=`expr ${mk8} + 1`
					fi;;
				9) ct=`expr ${mk9} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_108_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_108_[$mk9]=${flight}
						mk9=`expr ${mk9} + 1`
					fi;;
				10) ct=`expr ${mk10} - 1`
					flag=1
					while test ${ct} -ne -1
					do
						if [ ${flight} -eq flights_120_[$ct] ]
						then
							flag=10
						fi
						ct=`expr ${ct} - 1`
					done
					if [ ${flag} -eq 1 ]
					then
						flights_120_[$mk10]=${flight}
						mk10=`expr ${mk10} + 1`
					fi;;
			esac
		done

	else


		ltdiff=`expr ${lt2} - ${lt1}`
		ltdiffsteps=`expr ${ltdiff} / 12`
		if [ ${ltdiffsteps} -lt 7 ]
		then
			ltdiffsteps=7
		fi

		let nd9=9*nd
		let georad=6367.
		let ne9=idim*jdim*9
		echo "$idim $jdim $npts12 $mem $nd $nd9 $lonl $lonu $latu $latl $nflights $georad $ne9 $nv $ltcode $ivnorm $ltdiffsteps" > params

		export pgm=wsr_sigvar_allnorms
		. prep_step

		export XLFUNIT_1100="perts_${ymmdd}_${lt1}.d"
		export     FORT1100="perts_${ymmdd}_${lt1}.d"

		ctr=1
		while [ ${ctr} -le ${ltdiffsteps} ]
		do
			namenum=`expr ${ctr} \* 12 + ${lt1}`
			filenum=`expr ${ctr} + 1100`
			export XLFUNIT_${filenum}="perts_${ymmdd}_${namenum}.d"
			export     FORT${filenum}="perts_${ymmdd}_${namenum}.d"
			ctr=`expr ${ctr} + 1`
		done

		cp sigvartrack.d fort.7

		startmsg
		$EXECwsr/wsr_sigvar_allnorms < params >> $pgmout 2> errfile
		 export err=$?;err_chk

		factor=1200
		counter=0
		cnt2=${lt1}
		while test ${counter} -le ${ltdiffsteps}
		do
			filecode=`expr ${factor} + ${counter}`
			counteraddone=`expr ${counter} + 1`
			cp fort.${filecode} signvar_${ymmdd}_${lt1}_${cnt2}_${mem}.d
			mv fort.${filecode} sig${counteraddone}.d
			counter=`expr ${counter} + 1`
			cnt2=`expr ${cnt2} + 12`
		done

		read tmpdrop < sigvartrack.d
		echo $tmpdrop > dropplot.d
		tail -n$tmpdrop sigvartrack.d | awk '{if ($1 < 0) print s=$1+360.,$2; else print s=$1,$2}' >> dropplot.d

		echo "$lonl $lonu $latu $latl" > params

		ctr=0
		while [ ${ctr} -le ${ltdiffsteps} ]
		do
			ctraddone=`expr ${ctr} + 1`
			export pgm=wsr_sig_pac
			. prep_step

			rm -f sig${ctraddone}.d.gr
			export XLFUNIT_211="sig${ctraddone}.d"
			export     FORT211="sig${ctraddone}.d"
			export XLFUNIT_251="sig${ctraddone}.d.gr"
			export     FORT251="sig${ctraddone}.d.gr"
			startmsg
			$EXECwsr/wsr_sig_pac < params >> $pgmout 2> errfile
			export err=$?;err_chk

			echo "DSET sig${ctraddone}.d.gr" > sig${ctraddone}.ctl
			echo "OPTIONS big_endian template yrev" >> sig${ctraddone}.ctl
			echo "UNDEF -99.0" >> sig${ctraddone}.ctl
			echo "XDEF    ${nlo} linear    ${lonl} 5.000" >> sig${ctraddone}.ctl
			echo "YDEF    ${nla} linear    ${latl} 5.000" >> sig${ctraddone}.ctl
			cat wsr_si_pac.ctl >> sig${ctraddone}.ctl

			ctr=`expr ${ctr} + 1`
		done

		export pgm=wsr_circlevr
		. prep_step

		echo "${vrlon} ${vrlat} ${radvr[$i]}" > fort.105

		 startmsg
		$EXECwsr/wsr_circlevr > circlevr${i}.d 2> errfile
		export err=$?;err_chk
		cp circlevr${i}.d circlevr.d

		if test "$SENDCOM" = "YES"
		then

			ctr=0
			while [ ${ctr} -le ${ltdiffsteps} ]
			do
				ctraddone=`expr ${ctr} + 1`
				cp sig${ctraddone}.ctl $COMOUT/notwsr_case${i}.sig${ctraddone}.ctl
				cp sig${ctraddone}.d.gr $COMOUT/notwsr_case${i}.sig${ctraddone}.d.gr
				ctr=`expr ${ctr} + 1`
			done

			cp dropplot.d $COMOUT/notwsr_case${i}.dropplot.d
			cp circlevr${i}.d $COMOUT/notwsr_case${i}.circlevr${i}.d

			echo "export ensdate=$ensdate"      > $COMOUT/notwsr_case${i}.env
			echo "export obsdate=$obsdate"     >> $COMOUT/notwsr_case${i}.env
			echo "export vnormgr=$vnormgr"       >> $COMOUT/notwsr_case${i}.env
			echo "export ltdiff=$ltdiff"         >> $COMOUT/notwsr_case${i}.env
			echo "export lt1=$lt1"	        >> $COMOUT/notwsr_case${i}.env
			echo "export lt2=$lt2"               >> $COMOUT/notwsr_case${i}.env
			echo "export radvr=${radvr[$i]}"		>> $COMOUT/notwsr_case${i}.env
			echo "export vrlonewest=$vrlonewest"	>> $COMOUT/notwsr_case${i}.env
			echo "export vrlat=$vrlat"		>> $COMOUT/notwsr_case${i}.env
			echo "export flnmcode=$flnmcode"     >> $COMOUT/notwsr_case${i}.env
			echo "export case_id=${case_id[$i]}"     >> $COMOUT/notwsr_case${i}.env
		fi

	fi

	##########################################################################
	#  PLOT SUMMARY MAP
	##########################################################################
	hr1=${obsdate}
	hr2=${veridate}

	### creates verif region file and drop position files for wsr cases only ###
	if [ ${searchareacode} -eq 1 ]; then
		export pgm=wsr_circlevr
		. prep_step

		echo "${vrlon} ${vrlat} ${radvr[$i]}" > fort.105

		startmsg
		$EXECwsr/wsr_circlevr > circlevr${i}.d 2> errfile
		export err=$?;err_chk
		cp circlevr${i}.d circlevr.d

		read ndrops1 < wsr_track.${fl1}
		echo $ndrops1 > dropplot1.d
		tail -n$ndrops1 wsr_track.${fl1} | awk '{ if($1 < 0) print s=$1+360.,$2;else print s=$1,$2}' >> dropplot1.d

		read ndrops2 < wsr_track.${fl2}
		echo $ndrops2 > dropplot2.d
		tail -n$ndrops2 wsr_track.${fl2} | awk '{ if($1 < 0) print s=$1+360.,$2;else print s=$1,$2}' >> dropplot2.d

		read ndrops3 < wsr_track.${fl3}
		echo $ndrops3 > dropplot3.d
		tail -n$ndrops3 wsr_track.${fl3} | awk '{ if($1 < 0) print s=$1+360.,$2;else print s=$1,$2}' >> dropplot3.d
	fi

	#### copies raw data for summary maps for saving purposes
	check_vrlonewest=`echo "$vrlon >180"|bc -l`
	if [[ $check_vrlonewest -eq 1 ]]; then
		vrlonewest=`echo "360 - ${vrlon}"|bc `W
	else
		vrlonewest=${vrlon}E
	fi


	if [ ${searchareacode} -eq 1 ]
	then
		cp targ_${ymmdd}_${lt1}_${lt2}_${mem}.d ${COMOUT}/summarydata_wsr_${lt1}_${lt2}_${vrlonewest}_${vrlat}N.d
	else
		cp targ_${ymmdd}_${lt1}_${lt2}_${mem}.d ${COMOUT}/summarydata_other_${lt1}_${lt2}_${vrlonewest}_${vrlat}N.d
	fi

	cp targ_${ymmdd}_${lt1}_${lt2}_${mem}.d fort.111
	rm fort.121


	#### creating grads-readable data ####

	export pgm=wsr_tgr_special
	. prep_step

	echo "$nlon $nlat" > params

	rm -f targ1.d.gr
	export XLFUNIT_121="targ1.d.gr"
	export     FORT121="targ1.d.gr"

	startmsg
	$EXECwsr/wsr_tgr_special < params >> $pgmout 2> errfile
	export err=$?;err_chk

	## Building the new ctl file ##
	cat $FIXwsr/wsr_targ_flexctl1 > wsr_targ_flex.ctl
	echo "XDEF    ${nlon} linear    ${lon1} 5.000" >> wsr_targ_flex.ctl
	echo "YDEF    ${nlat} linear    ${lat1} 5.000" >> wsr_targ_flex.ctl
	cat $FIXwsr/wsr_targ_flexctl2 >> wsr_targ_flex.ctl

	##########################################################################
	#  FLIGHT HISTOGRAM
	##########################################################################
	if [ ${searchareacode} -eq 1 ]
	then

		cp fli_${ymmdd}_${lt1}_${lt2}_${mem}.d flights.d

		xmin=0.5
		xlow=1
		xmax=${nflights}
		xint=1
		yint=10.0
	fi

	if test "$SENDCOM" = "YES"
	then
		cp circlevr${i}.d     $COMOUT/case${i}.circlevr.d
		cp targ1.d.gr         $COMOUT/case${i}.targ1.gr
		cp flights.d          $COMOUT/case${i}.flights.d

		echo "export COMOUT=$COMOUT"       > $COMOUT/case${i}.env
		echo "export COMIN=$COMOUT"        >> $COMOUT/case${i}.env
		echo "export RAWINSONDES=$RAWINSONDES" >> $COMOUT/case${i}.env
		echo "export FIXwsr=$FIXwsr"       >> $COMOUT/case${i}.env
		echo "export cases=$cases"         >> $COMOUT/case${i}.env
		echo "export hr1=$hr1"             >> $COMOUT/case${i}.env
		echo "export hr2=$hr2"             >> $COMOUT/case${i}.env
		echo "export ensdategr=$ensdategr" >> $COMOUT/case${i}.env
		echo "export lon1=$lon1"           >> $COMOUT/case${i}.env
		echo "export lon2=$lon2"           >> $COMOUT/case${i}.env
		echo "export lat1=$lat1"           >> $COMOUT/case${i}.env
		echo "export lat2=$lat2"           >> $COMOUT/case${i}.env
		echo "export nlon=$nlon"           >> $COMOUT/case${i}.env
		echo "export nlat=$nlat"           >> $COMOUT/case${i}.env
		echo "export ensemble=$ensemble"   >> $COMOUT/case${i}.env
		echo "export mem=$mem"             >> $COMOUT/case${i}.env
		echo "export fl1=$fl1"             >> $COMOUT/case${i}.env
		echo "export fl2=$fl2"             >> $COMOUT/case${i}.env
		echo "export fl3=$fl3"             >> $COMOUT/case${i}.env
		echo "export vrlonewest=$vrlonewest" >> $COMOUT/case${i}.env
		echo "export vrlat=$vrlat"         >> $COMOUT/case${i}.env
		echo "export radvr=${radvr[$i]}"   >> $COMOUT/case${i}.env
		echo "export vnormgr=$vnormgr"     >> $COMOUT/case${i}.env
		echo "export lt1=$lt1"             >> $COMOUT/case${i}.env
		echo "export lt2=$lt2"             >> $COMOUT/case${i}.env
		echo "export xmin=$xmin"           >> $COMOUT/case${i}.env
		echo "export xmax=$xmax"           >> $COMOUT/case${i}.env
		echo "export ymin1=$ymin1"         >> $COMOUT/case${i}.env
		echo "export ymax1=$ymax1"         >> $COMOUT/case${i}.env
		echo "export xlow=$xlow"           >> $COMOUT/case${i}.env
		echo "export xint=$xint"           >> $COMOUT/case${i}.env
		echo "export yint=$yint"           >> $COMOUT/case${i}.env
		echo "export obsdate=$obsdate"     >> $COMOUT/case${i}.env
		echo "export veridate=$veridate"   >> $COMOUT/case${i}.env
		echo "export searchareacode=$searchareacode"   >> $COMOUT/case${i}.env
		echo "export flnmcode=$flnmcode"   >> $COMOUT/case${i}.env
		echo "export case_id=${case_id[$i]}" >> $COMOUT/case${i}.env

		if [[ ${RAWINSONDES} = YES ]]
		then
			cp station_${ymmdd}_${lt1}_${lt2}_${mem}.summary $COMOUT/
			cp station_${ymmdd}_${lt1}_${lt2}_${mem}.d $COMOUT/case${i}.rawinplot.d
			cp rawin_${ymmdd}_${lt1}_${lt2}_${mem}.d   $COMOUT/case${i}.rawinsondes.d
			echo "export ymin2=$ymin2"         >> $COMOUT/case${i}.env
			echo "export ymax2=$ymax2"         >> $COMOUT/case${i}.env
			echo "export xmax2=$nrawin"         >> $COMOUT/case${i}.env
			echo "export xmin2=0.5"         >> $COMOUT/case${i}.env
		fi

	fi


	#################################
	# END LOOP THROUGH EVERY CASE

	i=`expr ${i} + 1`
done

if [ ${searchareacode} -eq 0 ]; then
	#SMS#/nwprod/util/ush/prodllsubmit wx12sm /u/wx12sm/wsr/grads/wsr_grds.sh
	#$HOMEwsr/grads/wsr_grds.sh

	# If Search area is zero, then exit
	exit
fi

##########################################################################
#   LOOP THROUGH BY OBSDATE
##########################################################################

if test "$SENDCOM" = "YES"
then

	echo "export mk2=$mk2"  >> $COMOUT/ltinfo.env
	echo "export mk3=$mk3"  >> $COMOUT/ltinfo.env
	echo "export mk4=$mk4"  >> $COMOUT/ltinfo.env
	echo "export mk5=$mk5"  >> $COMOUT/ltinfo.env
	echo "export mk6=$mk6"  >> $COMOUT/ltinfo.env
	echo "export mk7=$mk7"  >> $COMOUT/ltinfo.env
	echo "export mk8=$mk8"  >> $COMOUT/ltinfo.env
	echo "export mk9=$mk9"  >> $COMOUT/ltinfo.env
	echo "export mk10=$mk10"  >> $COMOUT/ltinfo.env
fi

mk[2]=`expr ${mk2} - 1`
mk[3]=`expr ${mk3} - 1`
mk[4]=`expr ${mk4} - 1`
mk[5]=`expr ${mk5} - 1`
mk[6]=`expr ${mk6} - 1`
mk[7]=`expr ${mk7} - 1`
mk[8]=`expr ${mk8} - 1`
mk[9]=`expr ${mk9} - 1`
mk[10]=`expr ${mk10} - 1`
j=`expr ${minlt1} / 12`
finish=`expr ${maxlt1} / 12`

if [ ${maxlt1} -gt 120 ]
then
	finish=`expr 120 / 12`
fi

while test ${j} -le ${finish}
do
	lt1=`expr ${j} \* 12`
	mark=0
	ct=1
	maxtotlt2=0
	while test ${ct} -le ${cases}
	do
		if [ ${lt1} -eq ${lt1[$ct]} ]
		then
			mark=1
			if [ ${lt2[$ct]} -gt ${maxtotlt2} ]
			then
				maxtotlt2=${lt2[$ct]}
			fi
		fi
	ct=`expr $ct + 1`
	done

	if [ ${mark} -eq 1 ]; then

		##########################################################################
		#  SIGNAL VARIANCE FOR BEST 3 FLIGHTS
		##########################################################################


		ltdiff=`expr ${maxtotlt2} - ${lt1}`
		ltdiffsteps=`expr ${ltdiff} / 12`
		if [ ${ltdiffsteps} -lt 7 ]
		then
			ltdiffsteps=7
		fi

		let nd9=9*nd
		let georad=6367.
		let ne9=idim*jdim*9
		echo "$idim $jdim $npts12 $mem $nd $nd9 $lonl $lonu $latu $latl $nflights $georad $ne9 $nv $j $ivnorm $ltdiffsteps" > params

		k=1
		while test ${k} -le ${mk[$j]}
		do
			export pgm=wsr_sigvar_allnorms
			#SMS#   . prep_step

			export XLFUNIT_1100="perts_${ymmdd}_${lt1}.d"
			export     FORT1100="perts_${ymmdd}_${lt1}.d"

			ctr=1
			while [ ${ctr} -le ${ltdiffsteps} ]
			do
				namenum=`expr ${ctr} \* 12 + ${lt1}`
				filenum=`expr ${ctr} + 1100`
				export XLFUNIT_${filenum}="perts_${ymmdd}_${namenum}.d"
				export     FORT${filenum}="perts_${ymmdd}_${namenum}.d"
				ctr=`expr ${ctr} + 1`
			done

			if [ ${lt1} -eq 24 ]
			then
				cp wsr_track.${flights_24_[$k]} fort.7
				ifl=${flights_24_[$k]}
			fi
			if [ ${lt1} -eq 36 ]
			then
				cp wsr_track.${flights_36_[$k]} fort.7
				ifl=${flights_36_[$k]}
			fi
			if [ ${lt1} -eq 48 ]
			then
				cp wsr_track.${flights_48_[$k]} fort.7
				ifl=${flights_48_[$k]}
			fi
			if [ ${lt1} -eq 60 ]
			then
				cp wsr_track.${flights_60_[$k]} fort.7
				ifl=${flights_60_[$k]}
			fi
			if [ ${lt1} -eq 72 ]
			then
				cp wsr_track.${flights_72_[$k]} fort.7
				ifl=${flights_72_[$k]}
			fi
			if [ ${lt1} -eq 84 ]
			then
				cp wsr_track.${flights_84_[$k]} fort.7
				ifl=${flights_84_[$k]}
			fi
			if [ ${lt1} -eq 96 ]
			then
				cp wsr_track.${flights_96_[$k]} fort.7
				ifl=${flights_96_[$k]}
			fi
			if [ ${lt1} -eq 108 ]
			then
				cp wsr_track.${flights_108_[$k]} fort.7
				ifl=${flights_108_[$k]}
			fi
			if [ ${lt1} -eq 120 ]
			then
				cp wsr_track.${flights_120_[$k]} fort.7
				ifl=${flights_120_[$k]}
			fi

			#SMS#   startmsg
			$EXECwsr/wsr_sigvar_allnorms < params >> $pgmout 2> errfile
			#SMS# export err=$?;err_chk

			factor=1200

			counter=0
			cnt2=${lt1}
			while test ${counter} -le ${ltdiffsteps}
			do
				filecode=`expr ${factor} + ${counter}`
				counteraddone=`expr ${counter} + 1`
				cp fort.${filecode} signvar_${ymmdd}_${lt1}_${cnt2}_fl${ifl}_${mem}.d
				mv fort.${filecode} sig${counteraddone}_fl${ifl}.d
				counter=`expr ${counter} + 1`
				cnt2=`expr ${cnt2} + 12`
			done

			k=`expr ${k} + 1`
		done

		##########################################################################
		#  PLOT SIGNAL VARIANCE FOR 3 FLIGHTS
		##########################################################################

		k=1
		while test ${k} -le ${mk[$j]}
		do
			if [ ${lt1} -eq 24 ]
			then
				ifl=${flights_24_[$k]}
			fi
			if [ ${lt1} -eq 36 ]
			then
				ifl=${flights_36_[$k]}
			fi
			if [ ${lt1} -eq 48 ]
			then
				ifl=${flights_48_[$k]}
			fi
			if [ ${lt1} -eq 60 ]
			then
				ifl=${flights_60_[$k]}
			fi
			if [ ${lt1} -eq 72 ]
			then
				ifl=${flights_72_[$k]}
			fi
			if [ ${lt1} -eq 84 ]
			then
				ifl=${flights_84_[$k]}
			fi
			if [ ${lt1} -eq 96 ]
			then
				ifl=${flights_96_[$k]}
			fi
			if [ ${lt1} -eq 108 ]
			then
				ifl=${flights_108_[$k]}
			fi
			if [ ${lt1} -eq 120 ]
			then
				ifl=${flights_120_[$k]}
			fi

			read tmpdrop < wsr_track.${ifl}
			echo $tmpdrop > dropplot.d
			tail -n$tmpdrop wsr_track.${ifl} | awk '{if ($1 < 0) print s=$1+360.,$2;else print s=$1,$2}' >> dropplot.d

			echo "$lonl $lonu $latu $latl" > params

			ctr=0
			while [ ${ctr} -le ${ltdiffsteps} ]
			do
				ctraddone=`expr ${ctr} + 1`
				export pgm=wsr_sig_pac
				#SMS#       . prep_step

				rm -f sig${ctraddone}.d.gr
				export XLFUNIT_211="sig${ctraddone}_fl${ifl}.d"
				export     FORT211="sig${ctraddone}_fl${ifl}.d"
				export XLFUNIT_251="sig${ctraddone}.d.gr"
				export     FORT251="sig${ctraddone}.d.gr"
				#SMS#       startmsg
				$EXECwsr/wsr_sig_pac < params >> $pgmout 2> errfile
				#SMS#       export err=$?;err_chk

				echo "DSET sig${ctraddone}.d.gr" > sig${ctraddone}.ctl
				echo "OPTIONS big_endian template yrev" >> sig${ctraddone}.ctl
				echo "UNDEF -99.0" >> sig${ctraddone}.ctl
				echo "XDEF    ${nlo} linear    ${lonl} 5.000" >> sig${ctraddone}.ctl
				echo "YDEF    ${nla} linear    ${latl} 5.000" >> sig${ctraddone}.ctl
				cat wsr_si_pac.ctl >> sig${ctraddone}.ctl
				ctr=`expr ${ctr} + 1`
			done

			read ndrops < wsr_track.${ifl}

			i=1
			n=1
			vercase[1]=0
			vercase[2]=0
			vercase[3]=0
			vercase[4]=0
			while test ${i} -le ${cases}
			do
				if [[ ${caseflightA[$i]} -eq ${ifl} && ${lt1[$i]} -eq ${lt1} ]]
				then
					vercase[$n]=${i}
					n=`expr ${n} + 1`
				fi
				if [[ ${caseflightB[$i]} -eq ${ifl} && ${lt1[$i]} -eq ${lt1} ]]
				then
					vercase[$n]=${i}
					n=`expr ${n} + 1`
				fi
				if [[ ${caseflightC[$i]} -eq ${ifl} && ${lt1[$i]} -eq ${lt1} ]]
				then
					vercase[$n]=${i}
					n=`expr ${n} + 1`
				fi
				i=`expr ${i} + 1`
			done

			v=`expr ${n} - 1`
			n=1
			vtime[1]=99
			vtime[2]=99
			vtime[3]=99
			vtime[4]=99
			while test ${n} -le ${v}
			do
				num=${vercase[n]}
				vtime[$n]=`expr ${lt2[$num]} - ${lt1[$num]}`
				n=`expr ${n} + 1`
			done

			num=${vercase[1]}
			obsdate=${obsdate[$num]}

			if test "$SENDCOM" = "YES"
			then

				ctr=0
				while [ ${ctr} -le ${ltdiffsteps} ]
				do
					ctraddone=`expr ${ctr} + 1`
					cp sig${ctraddone}.ctl $COMOUT/flight${k}_${lt1}.sig${ctraddone}.ctl
					cp sig${ctraddone}.d.gr $COMOUT/flight${k}_${lt1}.sig${ctraddone}.d.gr
					ctr=`expr ${ctr} + 1`
				done

				cp dropplot.d $COMOUT/flight${k}_${lt1}.dropplot.d

				i=1
				while [ $i -le $cases ]
				do
					cp circlevr${i}.d $COMOUT/flight${k}_${lt1}.circlevr${i}.d
					i=`expr ${i} + 1`
				done

				echo "export ensdate=$ensdate"      > $COMOUT/flight${k}_${lt1}.env
				echo "export obsdate=$obsdate"     >> $COMOUT/flight${k}_${lt1}.env
				echo "export ifl=$ifl"             >> $COMOUT/flight${k}_${lt1}.env
				echo "export ndrops=$ndrops"       >> $COMOUT/flight${k}_${lt1}.env
				echo "export ensemble=$ensemble"   >> $COMOUT/flight${k}_${lt1}.env
				echo "export mem=$mem"             >> $COMOUT/flight${k}_${lt1}.env
				echo "export vercase[1]=${vercase[1]}" >> $COMOUT/flight${k}_${lt1}.env
				echo "export vercase[2]=${vercase[2]}" >> $COMOUT/flight${k}_${lt1}.env
				echo "export vercase[3]=${vercase[3]}" >> $COMOUT/flight${k}_${lt1}.env
				echo "export vercase[4]=${vercase[4]}" >> $COMOUT/flight${k}_${lt1}.env
				echo "export vtime[1]=${vtime[1]}"     >> $COMOUT/flight${k}_${lt1}.env
				echo "export vtime[2]=${vtime[2]}"     >> $COMOUT/flight${k}_${lt1}.env
				echo "export vtime[3]=${vtime[3]}"     >> $COMOUT/flight${k}_${lt1}.env
				echo "export vtime[4]=${vtime[4]}"     >> $COMOUT/flight${k}_${lt1}.env
				echo "export vnormgr=$vnormgr"       >> $COMOUT/flight${k}_${lt1}.env
				echo "export ltdiff=$ltdiff"	   >> $COMOUT/flight${k}_${lt1}.env
			fi

			k=`expr ${k} + 1`
		done

	fi

	################################
	#  END LOOP THROUGH BY OBSDATE

	j=`expr ${j} + 1`
done

#SMS#/nwprod/util/ush/prodllsubmit wx12sm /u/wx12sm/wsr/grads/wsr_grds.sh
#$HOMEwsr/grads/wsr_grds.sh

#####################################################################
# GOOD RUN
set +x
echo "**************$job  COMPLETED NORMALLY ON THE IBM SP"
set -x
#####################################################################

############## END OF SCRIPT #######################
echo "JOB $job HAS COMPLETED NORMALLY"

exit

