#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

SHA1=$(sha256sum output/output1.tar | awk '{print $1}')
SHA2=$(sha256sum output/output2.tar | awk '{print $1}')

echo "Printing the hashes of the generated node_modules tarballs, with and without package-lock.json:"
echo $SHA1
echo $SHA2
