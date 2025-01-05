#!/bin/bash
# This patches the current example code from BlackMagic to build on modern CentOS-derived OS

ed x264_encoder_plugin/.mk.defs << ENDOFPATCH
8c
CFLAGS = -fPIC -stdlib=libstdc++ -std=c++11 -Wall -I\$(PLUGIN_DEF_DIR)
.
wq
ENDOFPATCH
ed x264_encoder_plugin/Makefile << ENDOFPATCH
56a

install:
	mkdir -p \$(BUNDLE_DIR)/Contents/Linux-x86-64
	cp bin/x264_encoder_plugin.dvcp \$(BUNDLE_DIR)/Contents/Linux-x86-64
	mkdir -p /opt/resolve/IOPlugins
	cp -r \$(BUNDLE_DIR) /opt/resolve/IOPlugins
.
44a
	rm -rf \$(BUNDLE_DIR)
	rm -rf /opt/resolve/IOPlugins
.
19c
# (need to install zlib1g-dev on debian or zlib-devel on centos)
LDFLAGS += -L\$(X264_DIR) -lx264 -lz
.
12c
LDFLAGS = -shared '-Wl,-rpath,\$\$ORIGIN' -Wl,-z,origin -lpthread -stdlib=libstdc++
.
9c
CFLAGS += -I\$(X264_DIR) -I/usr/include/c++/11 -I/usr/include/c++/11/x86_64-redhat-linux

BUNDLE_DIR = \$(BASEDIR)x264_encoder_plugin.dvcp.bundle
.
wq
ENDOFPATCH
ed x264_encoder_plugin/audio_encoder.h << ENDOFPATCH
3a
#include <memory>
.
wq
ENDOFPATCH
ed x264_encoder_plugin/x264_encoder.cpp << ENDOFPATCH
408c
    const char* pCodecGroup = "AVC (plugin)";
.
405c
    const char* pCodecName = "x264 (plugin)";
.
342a
            case 5:
                pProfile = x264_profile_names[5];
.
199a
            textsVec.push_back("High 444");
            valuesVec.push_back(5);
.
wq
ENDOFPATCH

