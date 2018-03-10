#!/bin/bash

# Pass escaped aserisk to compute hash for all files in the directory, e.g.:
# sh s3bot.sh create "*" checksums.txt
create_checksums () {
    echo "################################################################################"
    echo "# Creating checksums...                                                        #"
    echo "################################################################################"
    for filename in $1; do
        md5_base64=$(openssl dgst -md5 -binary $filename | openssl enc -base64)
        output="$md5_base64 $filename"
        echo $output
        echo $output >> $2
    done
    echo "################################################################################"
    echo "# Done.                                                                        #"
    echo "################################################################################"
}

# Pass name of file that contains the file names and their checksums, e.g.:
# sh s3bot.sh checksums.txt
verify_checksums () {
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
upload () {
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

echo "################################################################################"
echo "#                                                                              #"
echo "# =====                                                                        #"
echo "# s3bot                                                                        #"
echo "# =====                                                                        #"
echo "# Avoid file corruption on S3                                                  #"
echo "# Obviously poorly written by @lambdarookie                                    #"
echo "#                                                                              #"
echo "################################################################################"


if [ "$1" = "create" ]
then
    create_checksums "$2" "$3"
fi

if [ "$1" = "verify" ]
then
    verify_checksums "$2"
fi

if [ "$1" = "upload" ]
then
    upload $2 $3 $4 $5
fi
