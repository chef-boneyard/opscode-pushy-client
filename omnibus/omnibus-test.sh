#!/bin/bash
set -ueo pipefail

channel="${CHANNEL:-unstable}"
product="${PRODUCT:-push-jobs-client}"
version="${VERSION:-latest}"

export INSTALL_DIR=/opt/push-jobs-client

echo "--- Installing $channel $product $version"
package_file="$(/opt/omnibus-toolchain/bin/install-omnibus-product -c "$channel" -P "$product" -v "$version" | tail -n 1)"

echo "--- Verifying omnibus package is signed"
/opt/omnibus-toolchain/bin/check-omnibus-package-signed "$package_file"

sudo rm -f "$package_file"

echo "--- Verifying ownership of package files"

NONROOT_FILES="$(find "$INSTALL_DIR" ! -user 0 -print)"
if [[ "$NONROOT_FILES" == "" ]]; then
  echo "Packages files are owned by root.  Continuing verification."
else
  echo "Exiting with an error because the following files are not owned by root:"
  echo "$NONROOT_FILES"
  exit 1
fi

echo "--- Running verification for $channel $product $version"
export PATH="$INSTALL_DIR/bin:$PATH"
