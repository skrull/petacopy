#!/bin/bash
#

#
# petacopy
# (c) skrull
#
# 2013-12-18 v0.1 - rewritten from scratch.
#

# stat, pv, md5sum, dd, tee, cat, cut
#

for dep in stat pv md5sum dd tee cat cut; do
	which $dep &>/dev/null
	[ $? = 1 ] && echo "$0: $dep is a missing dependency. aborted." && exit 1
done



# bug on dest="dir/file" if dir doesnt exist

do_ow=0
do_abort_on_error=0
pv_options="-pterabB 1048576"
#dd_flags="conv=noerror,fdatasync,fsync iflag=direct,nocache,dsync,sync oflag=direct,nocache,dsync,sync bs=1M"
tmpdir="$(mktemp -dp /dev/shm/ --suff=.petacopy)"
tmpfifo="$tmpdir/petacopy-fifo"

[ ! -d "$tmpdir" ] && mkdir "$tmpdir"
[  -e "$tmpfifo" ] && rm "$tmpfifo"

mkfifo "$tmpfifo"

while getopts "fnq" opt; do
	case $opt in
		f)
			echo "overwriting mode." 1>&2
			do_ow=1
			;;
		n)
			echo "skip existing files." 1>&2
			do_ow=0
			;;
		e)
			echo "abort on error." 1>&2
			do_abort_on_error=1
			# todo
			;;
		q)	
			echo "quiet mode." 1>&2
			pv_options="-qB 1048576"
			;;
	esac
done	
shift $((OPTIND-1))

source="$1"
dest="$2"

if [ ! -f "$source" ]; then
	echo "source does not exist. aborted." 1>&2
	exit 1
fi

if [ -f "$source" ]; then

	filesize=$(stat -c "%s" "$source")
	file=$(basename "$source")

	if [ $do_ow = 0 ] && [ -f "$dest" ]; then
		echo "destination exists. aborted." 1>&2
		exit 1
	fi
	
	if [ -d "$dest" ]; then
		echo "sending to directory." 1>&2
		dest="$dest/$file"
	fi

 	if [ "`echo "$dest"|grep '/'`" != "" ] && [ ! -d "`dirname "$dest"`" ]; then
 		echo "destination directory does not exist. aborted." 1>&2
 		exit 1
 	fi

	# copy file to dest and to md5sum fifo
	# ok
	#dd if="$source" $dd_options 2>/dev/null | pv $pv_options -s $filesize -N "$file" | tee /tmp/pv/teste > "$dest" &
	#sum_source=$(cat /tmp/pv/teste | md5sum | cut -c 1-32)
	
	# ver dd flags
	dd if="$tmpfifo" of="$dest" 2>/dev/null &
	sum_source="`dd if="$source" 2>/dev/null | pv $pv_options -s $filesize -N "$file" | tee "$tmpfifo" | md5sum | cut -c 1-32`"
	wait
	
	
	# calculate destination file sum.
	#
	sum_dest=$(dd if="./$dest" $dd_options 2>/dev/null | md5sum | cut -c 1-32)


	rm "$tmpfifo"
	rmdir "$tmpdir"
	# output ok or failed.
	#	
	if [ "$sum_source" = "$sum_dest" ]; then
		echo "$dest: OK" 1>&2
		exit 0
	else
		echo"$dest: FAILED" 1>&2
		exit 1
	fi
fi
