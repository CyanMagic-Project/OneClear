#!/bin/bash
set -e

# スクリプトがある場所へ移動
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"

# 🌟 大元のソースフォルダを絶対パスで固定（道迷い防止）
FFMPEG_DIR="/Users/yoshikawatatsuya/Desktop/native_engineのコピー/ffmpeg_source"
MIN_IOS_VERSION=15.0

# 🌟 出力フォルダ（BUILD_DIR）をOneClear.B専用の名前にして完全隔離
BUILD_DIR="$SCRIPT_DIR/../build_oneclear_b"

# 🌟 出荷ターゲットのベースフォルダ
APP_NATIVE_ENGINE_DIR="/Users/yoshikawatatsuya/Desktop/CyanSeed/OneClear.B/ios/native_engine"

# 🌟 デスクトップの SoXR パス
SOXR_DIR="/Users/yoshikawatatsuya/Desktop/soxr_for_ios"

# 【OneClear Engine .B 最終構成】
COMMON_FLAGS="
--enable-cross-compile
--disable-gpl
--enable-version3
--enable-static
--disable-shared
--disable-programs
--disable-doc
--disable-everything
--enable-libsoxr
--enable-avcodec
--enable-avformat
--enable-avfilter
--enable-swresample
--enable-videotoolbox
--enable-hwaccels
--enable-protocol=file,pipe
--enable-filter=aresample,aformat,abuffer,abuffersink,anull,setpts,asetpts,settb,asettb,scale,crop,fps
--enable-demuxer=wav,mov,mp4,m4v,aac,mjpeg
--enable-muxer=wav,mp4,mov,adts,mjpeg,image2
--enable-decoder=pcm_s16le,pcm_f32le,aac,h264,hevc,h264_videotoolbox,hevc_videotoolbox,mjpeg
--enable-encoder=pcm_s16le,pcm_f32le,aac,h264_videotoolbox,mjpeg
--enable-parser=aac,h264,hevc,mjpeg
"

build_arch () {
  ARCH=$1
  PLATFORM=$2
  TARGET=$3
  
  SDK=$(xcrun --sdk $PLATFORM --show-sdk-path)
  OUTPUT="${BUILD_DIR}/${PLATFORM}/${ARCH}"
  
  echo "----------------------------------------"
  echo "Building for ${PLATFORM} ${ARCH} (${TARGET}) for OneClear Engine..."
  echo "----------------------------------------"
  
  cd "$FFMPEG_DIR"
  make distclean || true

  ./configure \
    --prefix="$OUTPUT" \
    --arch="$ARCH" \
    --target-os=darwin \
    --cc="xcrun -sdk $PLATFORM clang" \
    --sysroot="$SDK" \
    --extra-cflags="-arch $ARCH -target $TARGET -mios-version-min=$MIN_IOS_VERSION -I$SOXR_DIR/include" \
    --extra-ldflags="-arch $ARCH -target $TARGET -mios-version-min=$MIN_IOS_VERSION -L$SOXR_DIR -lsoxr -framework VideoToolbox -framework CoreMedia -framework CoreVideo" \
    $COMMON_FLAGS

  make -j$(sysctl -n hw.ncpu)
  make install
  
  # 🌟 3. ビルドされた成果物を指定の構造に分離して自動出荷
  echo "----------------------------------------"
  echo "Deploying built libraries with BUILD_INFO to OneClear.B project..."
  echo "----------------------------------------"
  
  # 出荷先フォルダを定義：ios/libs/ffmpeg
  DEST_DIR="${APP_NATIVE_ENGINE_DIR}/libs/ffmpeg"
  
  # 古い出荷先を一度完全クリア
  rm -rf "$DEST_DIR"
  
  # 提案通りの分離構造フォルダを作成
  mkdir -p "${DEST_DIR}/lib"
  mkdir -p "${DEST_DIR}/include"
  
  # 分離して格納
  cp -R "${OUTPUT}/lib/"*.a "${DEST_DIR}/lib/"
  cp -R "${OUTPUT}/include/"* "${DEST_DIR}/include/"
  
  # 🌟 4. 管理用ラベル「BUILD_INFO.txt」の自動生成
  cat <<EOF > "${DEST_DIR}/BUILD_INFO.txt"
FFmpeg 8.0.2
VideoToolbox & Image Debugger enabled
SoXR realtime stable
built: $(date '+%Y-%m-%d %H:%M:%S')
---
Target: OneClear.B (Best)
---
EOF

  echo "Successfully deployed to $DEST_DIR"
  cd "$SCRIPT_DIR"
}

# 実行（実機用arm64）
build_arch "arm64" "iphoneos" "arm64-apple-ios$MIN_IOS_VERSION"

echo "========================================"
echo "OneClear.B Isolated Build & Deploy Complete with Metadata!"
echo "========================================"
