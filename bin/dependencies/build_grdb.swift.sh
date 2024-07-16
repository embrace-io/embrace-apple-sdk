REPO_DIR=$1
BUILD_DIR=$2

make --directory "$REPO_DIR" test_universal_xcframework

mv -v "$(PWD)/Tests/products/GRDB.xcframework" "$BUILD_DIR"
rm -rf "$(PWD)/Tests/products"
