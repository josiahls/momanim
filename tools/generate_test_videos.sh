#!/bin/bash


TEST_DATA_ROOT="test_data"
mkdir -p ${TEST_DATA_ROOT}

OUTPUT_FILE_1="${TEST_DATA_ROOT}/generate_test_videos_src_320x180_30fps_2s.h264"
if [ ! -f ${OUTPUT_FILE_1} ]; then
    echo "Generating ${OUTPUT_FILE_1}"
    ffmpeg -y \
        -f lavfi -i "testsrc2=size=320x180:rate=30" \
        -t 2 \
        -c:v libopenh264 \
        -pix_fmt yuv420p \
        -preset veryfast \
        -crf 23 \
        ${OUTPUT_FILE_1}
fi

OUTPUT_FILE_2="${TEST_DATA_ROOT}/generate_test_videos_testsrc_128x128.png"
if [ ! -f ${OUTPUT_FILE_2} ]; then
    echo "Generating ${OUTPUT_FILE_2}"
    ffmpeg -y \
        -f lavfi -i "testsrc=duration=1:size=128x128:rate=1" \
        -vframes 1 \
        ${OUTPUT_FILE_2}
fi

# 127x127: width*3=381 (not 16/32-byte aligned)
OUTPUT_FILE_2B="${TEST_DATA_ROOT}/generate_test_videos_testsrc_127x127.png"
if [ ! -f ${OUTPUT_FILE_2B} ]; then
    echo "Generating ${OUTPUT_FILE_2B}"
    ffmpeg -y \
        -f lavfi -i "testsrc=duration=1:size=127x127:rate=1" \
        -vframes 1 \
        ${OUTPUT_FILE_2B}
fi

OUTPUT_FILE_3="${TEST_DATA_ROOT}/generate_test_videos_testsrc_320x180_30fps_2s.mp4"
if [ ! -f ${OUTPUT_FILE_3} ]; then
    echo "Generating ${OUTPUT_FILE_3}"
    ffmpeg -y \
        -f lavfi -i "testsrc2=size=320x180:rate=30" \
        -t 2 \
        -c:v libopenh264 \
        -pix_fmt yuv420p \
        -preset fast \
        -crf 23 \
        ${OUTPUT_FILE_3}
fi
