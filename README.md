# s3bot

A simple command-line tool to preserve file integrity while uploading to S3

> Free to use - at your own risk!<br>
> (C) Lucas Baerenfaenger 2018

![s3bot](s3bot.png)

## Why?
AWS S3 is great for storing your files -- it's cheap and durable!
And once you have your files there, you can use the even cheaper long-term storage service Glacier!
However, to preserve file integrity while uploading to S3, you have to supply md5 checksums that are base64-encoded.
Furthermore, with the AWS CLI, it is tedious to upload files alongside their checksums.
The s3bot command-line tools sets out to remedy the situation by automating the checksum computation/verification as well as the upload process.
In fact, with the `quick_run` option, all you have to do is specify a source directory containing files that you want to upload, as well as a target bucket!
The only prerequisite is a configured AWS CLI.
Enjoy!

## How?

### `quick_run`

> Parameters:<br>
> $1 - Source directory (where the files that are to be uploaded live)<br>
> $2 - Target bucket (into which these will be uploaded)

> Sample call:<br>
> `bash s3bot.sh quick_run ~/Documents/Books s3bucket`

Given a source directory containing files, and a target S3 bucket into which these files are to be uploaded, a quick run performs the following steps:

1. Compute checksums (md5, base64 encoded) for all the files and write them (along with the respective file names) into a file called `<name_of_the_folder_containing_the_files>.md5base64`, which will be placed next to the files inside the given source directory.

2. Verify that for each file name listed in the previously created checksums file, the checksum stated next to the file name is still the checksum of the corresponding file.
   At this point, this is obviously unnecessary, as the checksums file has been created shortly before, and it is unlikely that any file has been corrupted since then.
   However, calling this function later is very useful, e.g., after downloading the files back from S3.

3. All the files listed in the checksums file (i.e., all the files in the given source directory) are uploaded to S3, along with their checksums.
   The checksums file itself is also being uploaded.
   If something goes wrong, an error message is being displayed.
   More details on how the files are uploaded along with their checksums can be found here:
   https://aws.amazon.com/premiumsupport/knowledge-center/data-integrity-s3/
   All the output that is being displayed while uploading is logged into a file called `<name_of__the_folder_containing_the_files>.logs`, which will also be placed into the given source directory, but not uploaded.

The quick run option exists for convenience purposes, only two arguments are expected.
Each of the three steps may also be called individually, allowing for more flexibility.

### `compute_checksums`

> Parameters:<br>
> $1 - Source directory (where the files live for which checksums will be computed)<br>
> $2 - Target file (into which the names and checksums of these files will be written)

> Sample call:<br>
> `bash s3bot.sh compute_checksums ~/Documents/Books/ ~/Documents/Books.md5base64`

Compute checksums (md5, base64 encoded) for all files in a given source directory and write them into a given target file.

### `verify_checksums`

> Parameters:<br>
> $1 Source file (which contains the names and checksums of the files which will be verified)<br>
> $2 Source directory (where these files live)

> Sample call:<br>
> `bash s3bot.sh verify_checksums ~/Documents/Books.md5base64 ~/Documents/Books`

Given a source file that contains the names and checksums of files, and a source directory in which these files live, verify that these have not been corrupted, i.e, still correspond to the given checksums.

### `upload_files`

> Parameters:<br>
> $1 - Source file (which contains the names and checksums of the files which will be uploaded)<br>
> $2 - Source directory (where these files live)<br>
> $3 - Target bucket (into which these files will be uploaded)<br>
> $4 - Target folder (into which these files will be uploaded)<br>
> $5 - Target file (into which logs of the upload process will be written)

> Sample call:<br>
> `bash s3bot.sh upload_files ~/Documents/Books.md5base64 ~/Documents/Books s3bucket s3folder ~/Documents/Books.log`

Given a source file that contains the names and checksums of files, and a source directory in which these files live, upload them as well as the checksums file to S3, into a given target folder within a given target bucket. Also, log the process into a given target file.
