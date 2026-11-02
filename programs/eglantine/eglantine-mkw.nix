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

# Eglantine-MKW (https://github.com/Wael3rd/Eglantine-MKW): rama mkw-eglantine,
# el nx2 de Eglantine con cambios para Mario Kart World. Solo publica builds de
# Windows, así que se compila desde fuente. Base: el paquete de nixpkgs de eden,
# adaptado a la rama del fork (dependencias de CPM sustituidas por las de nixpkgs
# o por fuentes fijadas aquí). Para actualizar: cambiar `rev` y los hashes.
let
  nx_tzdb = callPackage ./nx_tzdb.nix { };

  # Sin acceso a red en el sandbox: zbic (solo código fuente, no está en
  # nixpkgs) se fija aquí. CPM lo buscaría con find_package y falla, así que
  # postPatch apunta su directorio fuente directamente.
  zbic = fetchFromGitHub {
    owner = "kinnay";
    repo = "zbic";
    rev = "11b08f2712264bbed731545085cbd9702096ceb7";
    hash = "sha256-pHvxa1gkUvQo6mUgmLWtj1kcu01BLdGmttZyb8ZAj/o=";
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "eglantine";
  version = "mkw-2108c0e";

  src = fetchFromGitHub {
    owner = "Wael3rd";
    repo = "Eglantine-MKW";
    rev = "2108c0ea93b74976070fa128dc8164eec9c0a304";
    hash = "sha256-8PjZHVRY/4lJSg3EPix6c1h16jd9N9UzjESD3LF5qxI=";
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

  postInstall = ''
    install -Dm444 $src/dist/72-eden-input.rules $out/lib/udev/rules.d/72-eden-input.rules
    install -Dm444 $src/dist/Eglantine.png $out/share/pixmaps/dev.eglantine.eglantine.png
  '';

  preFixup = ''
    qtWrapperArgs+=(--prefix LD_LIBRARY_PATH : ${
      lib.makeLibraryPath [
        vulkan-loader
      ]
    })
  '';

  meta = {
    description = "Switch 2 emulator (experimental), Eglantine fork with Mario Kart World changes";
    homepage = "https://github.com/Wael3rd/Eglantine-MKW";
    mainProgram = "eglantine";
    license = with lib.licenses; [
      gpl3Plus
      gpl2Plus
    ];
    platforms = [ "x86_64-linux" ];
  };
})
