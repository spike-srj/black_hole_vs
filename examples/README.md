Put example/legacy entry points here (e.g., main0.cpp, main1.cpp, openGLFW.cpp).

To build examples, enable -DBUILD_EXAMPLES=ON and add them in examples/CMakeLists.txt
using the add_blackhole_example() helper.

Note: Some of the existing example files are in a non-UTF8 encoding.
Migrate them carefully (convert to UTF-8) before moving into this folder.

