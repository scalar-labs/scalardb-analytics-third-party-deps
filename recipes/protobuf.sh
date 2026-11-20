# shellcheck shell=sh disable=SC2154 # work, prefix, and jobs are set by build.sh
# Recipe of the protobuf artifact for scripts/build.sh: abseil and protobuf as
# static, position-independent libraries for C++17, which the ScalarDB
# Analytics DuckDB extension links, with protoc, which generates its Substrait
# types. protobuf is built without zlib, so that a consumer need not find one.

cmake -S "$work/abseil-cpp" -B "$work/build/abseil-cpp" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$prefix" \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_CXX_STANDARD=17 \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DBUILD_SHARED_LIBS=OFF \
	-DBUILD_TESTING=OFF \
	-DABSL_PROPAGATE_CXX_STD=ON
cmake --build "$work/build/abseil-cpp" --parallel "$jobs"
cmake --install "$work/build/abseil-cpp"

cmake -S "$work/protobuf" -B "$work/build/protobuf" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$prefix" \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_PREFIX_PATH="$prefix" \
	-DCMAKE_CXX_STANDARD=17 \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DBUILD_SHARED_LIBS=OFF \
	-Dprotobuf_BUILD_SHARED_LIBS=OFF \
	-Dprotobuf_BUILD_TESTS=OFF \
	-Dprotobuf_WITH_ZLIB=OFF \
	-Dprotobuf_ABSL_PROVIDER=package
cmake --build "$work/build/protobuf" --parallel "$jobs"
cmake --install "$work/build/protobuf"
