#!/bin/bash

###############################################################################
# To all DEV around the world :)                                              #
# to build this kernel you need to be ROOT and to have bash as script loader  #
# do this:                                                                    #
# cd /bin                                                                     #
# rm -f sh                                                                    #
# ln -s bash sh                                                               #
# now go back to kernel folder and run:                                       # 
#                                                         		      #
# sh clean_kernel.sh                                                          #
#                                                                             #
# Now you can build my kernel.                                                #
# using bash will make your life easy. so it's best that way.                 #
# Have fun and update me if something nice can be added to my source.         #
###############################################################################

# Time of build startup
res1=$(date +%s.%N)

echo "${bldcya}***** Setting up Environment *****${txtrst}";

. ./env_setup.sh ${1} || exit 1;


# Generate Ramdisk
echo "${bldcya}***** Generating Ramdisk *****${txtrst}"
echo "0" > $TMPFILE;

(

	# check xml-config for "NXTweaks"-app
#	XML2CHECK="${INITRAMFS_SOURCE}/res/customconfig/customconfig.xml";
#	xmllint --noout $XML2CHECK;
#	if [ $? == 1 ]; then
#        	echo "${bldred} WARNING for NXTweaks XML: $XML2CHECK ${txtrst}";
#	fi;

	# remove previous initramfs files
	if [ -d $INITRAMFS_TMP ]; then
		echo "${bldcya}***** Removing old temp initramfs_source *****${txtrst}";
		rm -rf $INITRAMFS_TMP;
	fi;

	mkdir -p $INITRAMFS_TMP;
	cp -ax $INITRAMFS_SOURCE/* $INITRAMFS_TMP;
	# clear git repository from tmp-initramfs
	if [ -d $INITRAMFS_TMP/.git ]; then
		rm -rf $INITRAMFS_TMP/.git;
	fi;
	
	# clear mercurial repository from tmp-initramfs
	if [ -d $INITRAMFS_TMP/.hg ]; then
		rm -rf $INITRAMFS_TMP/.hg;
	fi;

	# remove empty directory placeholders from tmp-initramfs
	find $INITRAMFS_TMP -name EMPTY_DIRECTORY | parallel rm -rf {};

	# remove more from from tmp-initramfs ...
	rm -f $INITRAMFS_TMP/update* >> /dev/null;

	#./utilities/mkbootfs $INITRAMFS_TMP | gzip > ramdisk.gz

	echo "1" > $TMPFILE;
	echo "${bldcya}***** Ramdisk Generation Completed Successfully *****${txtrst}"
)&

if [ ! -f $KERNELDIR/.config ]; then
	echo "${bldcya}***** Clean Build Initiating *****${txtrst}";
	cp $KERNELDIR/arch/arm/configs/$KERNEL_CONFIG .config;
	make $KERNEL_CONFIG;
else
	echo "${bldcya}***** Dirty Build Initiating *****${txtrst}";	
	# remove previous files which should regenerate
	rm -f $KERNELDIR/arch/arm/boot/*.dtb >> /dev/null;
	rm -f $KERNELDIR/arch/arm/boot/*.cmd >> /dev/null;
	rm -f $KERNELDIR/arch/arm/boot/zImage >> /dev/null;
	rm -f $KERNELDIR/arch/arm/boot/zImage-dtb >> /dev/null;
	rm -f $KERNELDIR/arch/arm/boot/Image >> /dev/null;
	rm -f $KERNELDIR/zImage >> /dev/null;
	rm -f $KERNELDIR/zImage-dtb >> /dev/null;
	rm -f $KERNELDIR/boot.img >> /dev/null;
	rm -rf $KERNELDIR/out/temp >> /dev/null;
	rm -rf $KERNELDIR/out/FLASHZIP >> /dev/null;
fi;

. $KERNELDIR/.config
GETVER=`grep 'Hybrid_v.*' $KERNELDIR/.config | sed 's/.*_.//g' | sed 's/".*//g'`
echo "${bldcya}Building => NUBIA NX505J ${txtrst}";

# wait for the successful ramdisk generation
while [ $(cat ${TMPFILE}) == 0 ]; do
	echo "${bldblu}Waiting for Ramdisk generation completion.${txtrst}";
	sleep 2;
done;

# make zImage
echo "${bldcya}***** Compiling kernel *****${txtrst}"
if [ $USER != "root" ]; then
	make -j$NUMBEROFCPUS #zImage-dtb
else
	nice -n -15 make -j$NUMBEROFCPUS #zImage-dtb
fi;

if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	echo "--- Copying necessary files to temp directory ---"
	mkdir $KERNELDIR/out/temp;
	mkdir $KERNELDIR/out/temp/MKBOOT;
	cp -pr $KERNELDIR/utilities/MKBOOT/* -t $KERNELDIR/out/temp/MKBOOT/;

	#echo "${bldcya}***** Final Touch for Kernel *****${txtrst}"
	cp $KERNELDIR/arch/arm/boot/zImage $KERNELDIR/out/temp/MKBOOT/ramdisk/zImage;

	echo "--- Creating dt.img ---"
	$KERNELDIR/dtbToolCM --force-v2 -o $KERNELDIR/out/temp/MKBOOT/ramdisk/dt.img -s 2048 -p $KERNELDIR/scripts/dtc/ $KERNELDIR/arch/arm/boot/;

	echo "--- Copying RAMDISK ---"
	#mkdir $KERNELDIR/out/temp/MKBOOT/ramdisk;
	mkdir $KERNELDIR/out/temp/MKBOOT/ramdisk/ramdisk;
	cp -pr $KERNELDIR/../ramdisks/NX505J/F2FS/* -t $KERNELDIR/out/temp/MKBOOT/ramdisk/ramdisk/;
	
	echo "--- Creating boot.img ---"
	mkdir $KERNELDIR/out/FLASHZIP;
	cd out;
	cd temp;
	cd MKBOOT;
	./mkboot ramdisk boot.img;
	cp ./boot.img ../../FLASHZIP/boot.img;
	cd ..;
	cd ..;
	cd ..;
	
	cp -pr $KERNELDIR/utilities/FLASHZIP/* -t $KERNELDIR/out/FLASHZIP/;
	find . -name "*.ko" -type f -exec cp {} ./out/FLASHZIP/system/lib/modules/ \;;
	#zip -r new.zip ./out/FLASHZIP/*;
	cd out;
	cd FLASHZIP;
	zip -r ../NGIAKERNEL.zip ./;
	cd ..;
	cd ..;
	
	exit 0;
else
	echo "${bldred}Kernel STUCK in BUILD!${txtrst}"
fi;