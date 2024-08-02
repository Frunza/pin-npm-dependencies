#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

npm clean-install

# Create a tarball of the node_modules directory
tar --sort=name --mtime='UTC 2023-01-01' -cf output/output1.tar node_modules
