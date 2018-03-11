#!/bin/bash

###################################################################################################
#                                                                                                 #
# s3bot                                                                                           #
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

# compute_checksums
#
# Compute checksums (md5, base64 encoded) for all files in a given source directory and write them
# into a given source file.
#
# $1 - Source directory
# $2 - Target file
#
# Sample call:
# compute_checksums ~/Documents/Books/ ~/Documents/Books.md5base64

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

# verify_checksums
#
# Given a source file that contains the names and checksums of files, and a source directory in
# which these files live, verify that they have not been corrupted, i.e, still correspond to the
# given checksums.
#
# $1 - Source file
# $2 - Source directory
#
# Sample call: verify_checksums ~/Documents/Books.md5base64 ~/Documents/Books

function verify_checksums {
    printf "%s\n"                   \
           "$hr2"                   \
           "Verifying checksums..." \
           "$hr2"                   \
           "Source file:      $1"   \
           "Source directory: $2"   \
	   "$hr2"                   \
	   ""

    cd $2 > /dev/null

    while read line; do
        file=$(printf "%s" "$line" | awk {'print $2'})
        source_checksum=$(printf "%s" "$line" | awk {'print $1'})
        current_checksum=$(openssl dgst -md5 -binary $file | openssl enc -base64)
        if [ "$source_checksum" = "$current_checksum" ]; then
            printf "PASS: %s\n" "$file"
        else 
            printf "FAIL: %s\n" "$file"
        fi
    done < $1

    cd - > /dev/null

    printf "%s\n"                      \
	   ""                          \
	   "$hr2"                      \
           "Done verifying checksums!" \
	   "$hr2"                      \
	   ""
}

# upload_files
#
# Given a source file that contains the names and checksums of files, and a source directory in
# which these files live, upload them to S3, into a given target folder within a given target
# bucket. Also, log the process into a given target file.
# 
# $1 - source file
# $2 - source directory
# $3 - target bucket
# $4 - target folder
# $5 - target file
#
# Sample call:
# upload_files ~/Documents/Books ~/Documents/Books.md5base64 bucket folder ~/Documents/Books.log

function upload_files {
    printf "%s\n"                 \
           "$hr2"                 \
           "Uploading files..."   \
           "$hr2"                 \
           "Source file:      $1" \
           "Source directory: $2" \
	   "Target bucket:    $3" \
	   "Target folder:    $4" \
	   "Target file:      $5" \
	   "$hr2"                 \
	   "" | tee -a $5
    
    while read line; do
        file=$(printf "%s" "$line" | awk {'print $2'})
        checksum=$(printf "%s" "$line" | awk {'print $1'})
        
	put_cmd="aws s3api put-object
             --bucket $3
             --key $4/$file
             --body $2/$file
             --metadata md5chksum=$checksum
             --content-md5 $checksum"
        head_cmd="aws s3api head-object
             --bucket $3
             --key $4/$file"
    
        printf "%s\n"                    \
               "==> File:     $file"     \
               "==> Checksum: $checksum" \
               "" | tee -a $5

        $put_cmd  2>&1 | tee -a $5
	$head_cmd 2>&1 | tee -a $5

	printf "\n" | tee -a $5
    done < $1
 
    printf "%s\n"                  \
	   "$hr2"                  \
           "Done uploading files!" \
	   "$hr2"                  \
	   "" | tee -a $5
}

###################################################################################################
# Control flow                                                                                    #
###################################################################################################

printf "%s\n"                                       \
       "$hr1"                                       \
       ""                                           \
       "s3bot"                                      \
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
    verify_checksums "$2" "$(dirname $2)"
fi

if [ "$1" = "upload_files" ]
then
    upload_files $2 $3 $4 $5 $6
fi

