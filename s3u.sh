#!/bin/bash
#
# Script to upload a file to Amazon S3 bucket
#
# Amazon S3 onfiguration is read from (in this order):
#   1. the working directory
#   2. The user's home directory
# (in that order)
#
# SHELLS3_BUCKET="your_amazon_bucket"
# SHELLS3_AWS_ACCESS_KEY_ID="your_s3_key"
# SHELLS3_AWS_SECRET_ACCESS_KEY="your_secret"
# SHELLS3_AWS_REGION=${SHELLS3_AWS_REGION:-"us-east-1"}
#

MIMEPATTERN="[0-9a-zA-Z-]/[0-9a-zA-Z-]"

# read property file
config_file=".s3u.conf"
if [ -f "$(pwd)/$config_file" ]; then
  source "$(pwd)/$config_file"
elif [ -f "$HOME/$config_file" ]; then
  source "$HOME/$config_file"
fi

bucket=$SHELLS3_BUCKET
key=$SHELLS3_AWS_ACCESS_KEY_ID
secret=$SHELLS3_AWS_SECRET_ACCESS_KEY

# check if bucket, key and secret have non-empty values
if [ -z "$bucket" ]; then
    echo "bucket is empty"
    exit 1
fi
if [ -z "$key" ]; then
    echo "key is empty"
    exit 1
fi
if [ -z "$secret" ]; then
    echo "secret is empty"
    exit 1
fi

# configure the endpoint
endpoint=""
case "$SHELLS3_AWS_REGION" in
us-east-1) endpoint="s3.amazonaws.com"
;;
*)  endpoint="s3-$SHELLS3_AWS_REGION.amazonaws.com"
;;
esac


function putS3 {
  sourcePath=$1
  targetPath=$2

  filename=$(basename "$sourcePath")

  # get content type
  content_type=$(filename --mime-type -b "${sourcePath}")
  if [[ ! "$content_type" =~ $MIMEPATTERN ]]
  then
    content_type="application/octet-stream"
  fi

  date=$(date +"%a, %d %b %Y %T %z")
  acl="x-amz-acl:public-read"
  cache_control="public, max-age=315360000"

  if [[ "$targetPath" =~ ^/.* ]]; then
    targetPath=$targetPath
  else
    targetPath="/"${targetPath}
  fi

  url="https://$endpoint/$bucket$targetPath"

  string="PUT\n\n$content_type\n$date\n$acl\n/$bucket$targetPath"
  signature=$(echo -en "${string}" | openssl sha1 -hmac "${secret}" -binary | base64)

  curl -X PUT -T "$sourcePath" \
    -H "Host: $endpoint" \
    -H "Date: $date" \
    -H "Cache-Control: $cache_control" \
    -H "Content-Type: $content_type" \
    -H "$acl" \
    -H "Authorization: AWS ${key}:$signature" \
    "$url"

  case "$?" in
    0)
    ;;
    *) echo "Something went wrong"
    ;;
  esac
}

# main script

if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]] ; then
  cat <<EOS
Usage:
   s3u file
   s3u file /targetFolder/
   s3u file /targetFolder/targetName
EOS
    exit 1
fi

# source file path
source=$1
target=$2
filename=$(basename "$source")

# create target path
echo "$target" | grep -qE "/$"
if [[ $? -eq  0 ]]; then
  targetFile="$target$filename"
elif [[ -z  $target  ]]; then
  targetFile=$filename
else
  targetFile=$target
fi

putS3 "$source" "$targetFile"


