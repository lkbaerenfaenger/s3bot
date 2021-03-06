#!/bin/bash

####################################################################################################
#                                                                                                  #
# s3bot                                                                                            #
# A simple command-line tool to preserve file integrity while uploading to S3                      #
#                                                                                                  #
# Free to use -- at your own risk!                                                                  #
# (C) Lucas Baerenfaenger 2018                                                                     #
#                                                                                                  #
####################################################################################################

####################################################################################################
# Global variables                                                                                 #
####################################################################################################

hr1="================================================================================"
hr2="--------------------------------------------------------------------------------"

####################################################################################################
# Functions                                                                                        #
####################################################################################################

# compute_checksums
#
# Description:
# Compute checksums (md5, base64-encoded) for all files in a given source directory and write them
# into a given target file.
#
# Parameters:
# $1 - Source directory (where the files live for which checksums will be computed)
# $2 - Target file (into which the names and checksums of these files will be written)
#
# Sample call:
# compute_checksums ~/Documents/Books/ ~/Documents/Books.md5base64

function compute_checksums {
    printf "%s\n"                \
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

    printf "%s\n"                   \
        ""                          \
        "$hr2"                      \
        "Done computing checksums!" \
        "$hr2"                      \
        ""
}

# verify_checksums
#
# Description:
# Given a source file that contains the names and checksums of files, and a source directory in
# which these files live, verify that these have not been corrupted, i.e, still correspond to the
# given checksums.
#
# Parameters:
# $1 - Source file (which contains the names and checksums of the files which will be verified)
# $2 - Source directory (where these files live)
#
# Sample call:
# verify_checksums ~/Documents/Books.md5base64 ~/Documents/Books

function verify_checksums {
    printf "%s\n"                \
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

    printf "%s\n"                   \
        ""                          \
        "$hr2"                      \
        "Done verifying checksums!" \
        "$hr2"                      \
        ""
}

# upload_files
#
# Given a source file that contains the names and checksums of files, and a source directory in
# which these files live, upload them as well as the checksums file to S3, into a given target
# folder within a given target bucket. Also, log the process into a given target file.
#
# Parameters:
# $1 - Source file (which contains the names and checksums of the files which will be uploaded)
# $2 - Source directory (where these files live)
# $3 - Target bucket (into which these files will be uploaded)
# $4 - Target folder (into which these files will be uploaded)
# $5 - Target file (into which logs of the upload process will be written)
#
# Sample call:
# upload_files ~/Documents/Books.md5base64 ~/Documents/Books s3bucket s3folder ~/Documents/Books.log

function upload_files {
    printf "%s\n"              \
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

        printf "%s\n"                 \
            "==> File:     $file"     \
            "==> Checksum: $checksum" \
            "" | tee -a $5

        $put_cmd  2>&1 | tee -a $5
        $head_cmd 2>&1 | tee -a $5

        printf "\n" | tee -a $5
    done < $1

    checksums_file=$(basename $1)
    put_cmd_checksums_file="aws s3api put-object --bucket $3 --key $4/$checksums_file --body $1"
    get_cmd_checksums_file="aws s3api head-object --bucket $3 --key $4/$checksums_file"
    printf "%s\n"                       \
        "==> File:     $checksums_file" \
        "" | tee -a $5
    $put_cmd_checksums_file 2>&1 | tee -a $5
    $get_cmd_checksums_file 2>&1 | tee -a $5

    printf "%s\n"               \
        ""                      \
        "$hr2"                  \
        "Done uploading files!" \
        "$hr2"                  \
        "" | tee -a $5
}

###################################################################################################
# Control flow                                                                                    #
###################################################################################################

printf "%s\n"                                                                     \
    "$hr1"                                                                        \
    ""                                                                            \
    "s3bot"                                                                       \
    "A simple command-line tool to preserve file integrity while uploading to S3" \
    ""                                                                            \
    "Free to use -- at your own risk!"                                            \
    "(C) Lucas Baerenfaenger 2018"                                                \
    ""                                                                            \
    "$hr1"                                                                        \
    ""

if [ "$1" = "compute_checksums" ]; then
    # Parameters:     source directory | target file
    compute_checksums $2                 $3
fi

if [ "$1" = "verify_checksums" ]; then
    # Parameters:    source file | source directory
    verify_checksums $2            $3
fi

if [ "$1" = "upload_files" ]; then
    # Parameters: source file | source directory | target bucket | target folder | target file
    upload_files  $2            $3                 $4              $5              $6
fi

# quick_run
#
# Description:
# Given a source directory containing files, and a target S3 bucket into which these files are to be
# uploaded, a quick run performs the following steps:
# 1. Compute checksums (md5, base64-encoded) for all the files and write them (along with the
#    respective file names) into a file called <name_of_the_folder_containing_the_files>.md5base64,
#    which will be placed next to the files inside the given source directory.
# 2. Verify that for each file name listed in the previously created checksums file, the checksum
#    stated next to the file name is still the checksum of the corresponding file. At this point,
#    this is obviously unnecessary, as the checksums file has been created shortly before, and it is
#    unlikely that any file has been corrupted since then. However, calling this function later is
#    very useful, e.g., after downloading the files back from S3.
# 3. All the files listed in the checksums file (i.e., all the files in the given source directory)
#    are uploaded to S3, along with their checksums. The checksums file itself is also being
#    uploaded. If something goes wrong, an error message is being displayed. More details on how the
#    files are uploaded along with their checksums can be found here:
#    https://aws.amazon.com/premiumsupport/knowledge-center/data-integrity-s3/
#    All the output that is being displayed while uploading is logged into a file called
#    <name_of_the_folder_containing_the_files>.logs, which will also be placed into the given
#    source directory, but not uploaded.
# The quick run option exists for convenience purposes, only two arguments are expected. Each of the
# three steps may also be called individually, allowing for more flexibility.
#
# Parameters:
# $2 - Source directory (where the files that are to be uploaded live)
# $3 - Target bucket (into which these will be uploaded)
#
# Sample call:
# bash s3bot.sh quick_run ~/Documents/Books s3bucket

if [ "$1" = "quick_run" ]; then
    src_dir_base=$(basename $2)
    checksums_file="${2%/}/$src_dir_base.md5base64"
    logs_file="${2%/}/$src_dir_base.logs"

    # Parameters:     source directory | target file
    compute_checksums $2                 $checksums_file

    # Parameters:    source file     | source directory
    verify_checksums $checksums_file   $2

    read -p "Continue? (y/n) " cont
    if [ "$cont" = "n" ]; then
        exit
    fi

    printf "\n"

    # Parameters: source file     | source directory | target bucket | target folder | target file
    upload_files  $checksums_file   $2                 $3              $src_dir_base   $logs_file
fi
