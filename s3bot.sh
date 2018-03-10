#!/bin/bash

###################################################################################################
#                                                                                                 #
# s3bot                                                                                           #
# Assisting to ensure file integrity with S3                                                      #
#                                                                                                 #
# (C) 2018                                                                                        #
#                                                                                                 #
###################################################################################################

###################################################################################################
# Global variables                                                                                #
###################################################################################################

hr1="================================================================================"
hr2="--------------------------------------------------------------------------------"

###################################################################################################
# Functions                                                                                       #
###################################################################################################

# Compute checksums (md5, base64 encoded) for all files in a given source directory and write them
# into a given source file.
# $1 - Source directory containing files for which checksums will be computed
# $2 - Target file into which the checksums (and respective file names) will be written

function compute_checksums {
    printf "%s\n"                   \
           "$hr2"                   \
           "Computing checksums..." \
           "$hr2"                   \
           "Source directory: $1"   \
           "Target file:      $2"   \
           "$hr2"                   \
	   ""

    cd $1 > /dev/null
    for file in *; do
	checksum=$(openssl dgst -md5 -binary $file | openssl enc -base64)
	cd - > /dev/null
	printf "%s %s\n" "$checksum" "$file" | tee -a $2
	cd $1 > /dev/null
    done
    cd - > /dev/null

    printf "%s\n"                      \
	   ""                          \
	   "$hr2"                      \
           "Done computing checksums!" \
	   "$hr2"                      \
	   ""
}

function verify_checksums {
    echo "################################################################################"
    echo "# Verifing checksums...                                                        #"
    echo "################################################################################"
    while read line
    do
        filename=$(echo $line | awk {'print $2'})
        old_hash=$(echo $line | awk {'print $1'})
        new_hash=$(openssl dgst -md5 -binary $filename | openssl enc -base64)
        if [ "$old_hash" = "$new_hash" ]
        then
            echo "$filename: OK"
        else 
            echo "$filename: FAIL"
        fi
    done < $1
    echo "################################################################################"
    echo "# Done.                                                                        #"
    echo "################################################################################"
}

# $1 checksums_file
# $2 target_bucket
# $3 target_folder
# $4 log_file
function upload_files {
    echo "################################################################################"
    echo "# Uploading files...                                                           #"
    echo "################################################################################"
    while read line
    do
        filename=$(echo $line | awk {'print $2'})
        hash=$(echo $line | awk {'print $1'})
        put_cmd="aws s3api put-object\
             --bucket $2\
             --key $3/$filename\
             --body $filename\
             --metadata md5chksum=$hash\
             --content-md5 $hash"
        head_cmd="aws s3api head-object
             --bucket $2
             --key $3/$filename"

        echo "================================================================================" | tee -a $4
        echo "Uploading $filename with checksum $hash..." | tee -a $4
        echo "================================================================================"| tee -a $4
        $put_cmd   2>&1 | tee -a $4
        $head_cmd  2>&1 | tee -a $4
    done < $1
    echo "################################################################################"
    echo "# Done.                                                                        #"
    echo "################################################################################"
}

###################################################################################################
# control flow                                                                                    #
###################################################################################################

printf "%s\n"                                       \
       "$hr1"                                       \
       ""                                           \
       "s3bot"                                      \
       "Assisting to ensure file integrity with S3" \
       ""                                           \
       "(C) 2018"                                   \
       ""                                           \
       "$hr1"                                       \
       ""

if [ "$1" = "compute_checksums" ]
then
    compute_checksums ${2%/} "${2%/}/$(basename $2).md5base64"
fi

if [ "$1" = "verify_checksums" ]
then
    verify_checksums "$2"
fi

if [ "$1" = "upload_files" ]
then
    upload_files $2 $3 $4 $5
fi
