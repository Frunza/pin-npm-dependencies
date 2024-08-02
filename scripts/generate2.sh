#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

rm -f package-lock.json

npm install

# Create a tarball of the node_modules directory
tar --sort=name --mtime='UTC 2023-01-01' -cf output/output2.tar node_modules
