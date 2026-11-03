{
  lib,
  stdenv,
  cmake,
  ninja,
  sdl3,
  boost,
  catch2_3,
  cpp-jwt,
  cubeb,
  enet,
  fetchFromGitHub,
  ffmpeg-headless,
  fmt_11,
  frozen-containers,
  gamemode,
  glslang,
  httplib,
  kdePackages,
  libopus,
  libusb1,
  lz4,
  nlohmann_json,
  oaknut,
  openssl,
  pkg-config,
  python3,
  qt6,
  simpleini,
  sirit,
  spirv-headers,
  stb,
  unordered_dense,
  vulkan-headers,
  vulkan-loader,
  vulkan-memory-allocator,
  vulkan-utility-libraries,
  xbyak,
  zlib,
  zstd,
  callPackage,
  wrapGAppsHook3,
}:

# Lichii (https://github.com/zortos293/Lichii): fork de Eden/Eglantine para
# Switch y Switch 2. El fork solo publica builds de Windows para la GUI, y los
# AppImage de Linux que aparecen en sus releases son de Eglantine, no de Lichii,
# así que se compila desde fuente. Base: eglantine-mkw.nix (mismas dependencias
# de CPM sustituidas por las de nixpkgs). Para actualizar: cambiar `rev` y `hash`.
let
  nx_tzdb = callPackage ../eglantine/nx_tzdb.nix { };

  # Sin acceso a red en el sandbox: zbic (solo código fuente, no está en
  # nixpkgs) se fija aquí. CPM lo buscaría con find_package y falla, así que
  # postPatch apunta su directorio fuente directamente.
  zbic = fetchFromGitHub {
    owner = "kinnay";
    repo = "zbic";
    rev = "11b08f2712264bbed731545085cbd9702096ceb7";
    hash = "sha256-pHvxa1gkUvQo6mUgmLWtj1kcu01BLdGmttZyb8ZAj/o=";
  };

  # zstd_CUSTOM_DIR evita que CPM descargue zstd.
  zstd-src = fetchFromGitHub {
    owner = "facebook";
    repo = "zstd";
    rev = "33618c89e511637f8a6ef955b3501766d71feb53";
    hash = "sha256-UP99PUq8N+fmU972Jxim4f9u//T+4hRW+wuTZzWg3uI=";
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "lichii";
  version = "nx2-29571ea";

  src = fetchFromGitHub {
    owner = "zortos293";
    repo = "Lichii";
    rev = "29571ea9d74b0999ac900255220a40f90a865cec";
    hash = "sha256-VW9Mf4BKiIcTgdEBFv+kqC3723Tk90kI8SOxbr16WIA=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    cmake
    ninja
    glslang
    pkg-config
    python3
    qt6.qttools
    qt6.wrapQtAppsHook
    wrapGAppsHook3
  ];

  buildInputs = [
    boost
    cpp-jwt
    cubeb
    enet
    ffmpeg-headless
    fmt_11
    frozen-containers
    gamemode
    httplib
    kdePackages.quazip
    libopus
    libusb1
    lz4
    nlohmann_json
    openssl
    qt6.qtbase
    qt6.qtmultimedia
    qt6.qtwayland
    qt6.qtwebengine
    qt6.qtcharts
    sdl3
    stb
    simpleini
    sirit
    spirv-headers
    vulkan-headers
    vulkan-memory-allocator
    vulkan-utility-libraries
    unordered_dense
    xbyak
    zlib
    zstd
  ];

  doCheck = false;

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "YUZU_TESTS" false)
    (lib.cmakeBool "YUZU_CMD" true)

    # usar paquetes del sistema
    (lib.cmakeBool "CPMUTIL_FORCE_SYSTEM" true)
    (lib.cmakeBool "ENABLE_RESHADE" false)

    # Ryzen 7 2700X (Zen+): znver1 da AVX2 y BMI2 sin instrucciones de Zen 2.
    # -march=native no sirve: el sandbox de Nix lo elimina (NIX_ENFORCE_NO_NATIVE).
    (lib.cmakeFeature "CMAKE_C_FLAGS" "-march=znver1 -mtune=znver1")
    (lib.cmakeFeature "CMAKE_CXX_FLAGS" "-march=znver1 -mtune=znver1")
    (lib.cmakeFeature "zstd_CUSTOM_DIR" "${zstd-src}")
    (lib.cmakeFeature "YUZU_TZDB_PATH" "${nx_tzdb}")

    # opciones opcionales
    (lib.cmakeBool "YUZU_USE_QT_WEB_ENGINE" true)
    (lib.cmakeBool "YUZU_USE_QT_MULTIMEDIA" true)
    (lib.cmakeBool "ENABLE_QT_TRANSLATION" true)
    (lib.cmakeBool "ENABLE_LTO" true)
    (lib.cmakeBool "ENABLE_UPDATE_CHECKER" false)
    (lib.cmakeBool "USE_DISCORD_PRESENCE" false)
    (lib.cmakeBool "YUZU_ENABLE_COMPATIBILITY_REPORTING" false)
  ];

  postPatch = ''
    substituteInPlace externals/CMakeLists.txt \
      --replace-fail 'AddJsonPackage(NAME zbic DOWNLOAD_ONLY)' 'set(zbic_SOURCE_DIR ${zbic})'
  '';

  preFixup = ''
    qtWrapperArgs+=(--prefix LD_LIBRARY_PATH : ${
      lib.makeLibraryPath [
        vulkan-loader
      ]
    })
  '';

  meta = {
    description = "Experimental Nintendo Switch and Switch 2 emulator (Lichii, Eglantine/Eden fork)";
    homepage = "https://github.com/zortos293/Lichii";
    mainProgram = "lichii";
    license = with lib.licenses; [
      gpl3Plus
      gpl2Plus
    ];
    platforms = [ "x86_64-linux" ];
  };
})
