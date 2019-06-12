#!/bin/bash
set -ueo pipefail

channel="${CHANNEL:-unstable}"
product="${PRODUCT:-push-jobs-client}"
version="${VERSION:-latest}"

export INSTALL_DIR=/opt/push-jobs-client

echo "--- Removing previous install of $product"

download_url="$(mixlib-install download --url --channel "$channel" "$product" --version "$version")"

FILE_TYPE="${download_url##*.}"
case "$FILE_TYPE" in
  "bff")
    sudo installp -u $product || true
    ;;
esac

sudo rm -rf "/opt/$INSTALL_DIR"

echo "--- Installing $channel $product $version"

download_dir="$(pwd)"
mixlib-install install-script | sudo bash -s -- -d "$download_dir" -l "$download_url"

echo "--- Verifying omnibus package is signed"

package_file="${download_dir%/}/${download_url##*/}"
case "$package_file" in
  *.dmg)
    echo "--- Checking that $package_file contains a signed package."
    hdiutil detach "/Volumes/chef_software" >/dev/null 2>&1 || true
    hdiutil attach "$package_file" -mountpoint "/Volumes/chef_software"
    pkg_file="$(find "/Volumes/chef_software" -name "*.pkg")"
    result=$(pkgutil --check-signature "$pkg_file" 2>&1 | grep -c "Status: signed")
    hdiutil detach "/Volumes/chef_software"
    if [[ $result -eq 1 ]]; then
      echo "Verified $package_file contains a signed package."
    else
      echo "Exiting with an error because $package_file does not contain a signed package. Check your omnibus project config."
      exit 1
    fi
    ;;
  *.rpm)
    echo "--- Checking that $package_file has been signed."
    if [[ $(rpm -qpi "$package_file" 2>&1 | grep -c "Signature.*Key ID") -eq 1 ]]; then
      echo "Verified $package_file has been signed."
    else
      echo "Exiting with an error because $package_file has not been signed. Check your omnibus project config."
      exit 1
    fi
    ;;
  *)
    echo "Skipping signed package verification. '$package_file' is not a dmg or rpm."
    exit 0
esac

rm -f "$package_file"

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
