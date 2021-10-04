{
  lib,
  stdenv,
  fetchurl,
  curl,
  tzdata,
  autoPatchelfHook,
  fixDarwinDylibNames,
  glibc,
  version,
  hashes,
}: let
  inherit (stdenv) hostPlatform;
  OS =
    if hostPlatform.isDarwin
    then "osx"
    else hostPlatform.parsed.kernel.name;
  MODEL =
    if OS == "osx"
    then ""
    else toString hostPlatform.parsed.cpu.bits;
in
  stdenv.mkDerivation {
    pname = "dmd-binary";
    inherit version;

    src = fetchurl rec {
      name = "dmd.${version}.${OS}.tar.xz";
      url = "http://downloads.dlang.org/releases/2.x/${version}/${name}";
      sha256 = hashes.${OS} or (throw "missing bootstrap sha256 for OS ${OS}");
    };

    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs =
      lib.optional hostPlatform.isLinux autoPatchelfHook
      ++ lib.optional hostPlatform.isDarwin fixDarwinDylibNames;

    propagatedBuildInputs = [curl tzdata] ++ lib.optional hostPlatform.isLinux glibc;

    installPhase = ''
      runHook preInstall

      mkdir -p $out

      # Move `src`, `bin` and `lib` into place:
      mv -v ${OS}/bin${MODEL} $out/bin
      mv -v src ${OS}/lib${MODEL} $out/

      # fix paths in dmd.conf (one level less)
      substituteInPlace $out/bin/dmd.conf --replace "/../../" "/../"

      runHook postInstall
    '';

    # Stripping on Darwin started to break libphobos2.a
    # Undefined symbols for architecture x86_64:
    #   "_rt_envvars_enabled", referenced from:
    #       __D2rt6config16rt_envvarsOptionFNbNiAyaMDFNbNiQkZQnZQq in libphobos2.a(config_99a_6c3.o)
    dontStrip = hostPlatform.isDarwin;

    meta = with lib; {
      description = "Digital Mars D Compiler Package";
      license = licenses.boost;
      maintainers = [maintainers.lionello];
      homepage = "https://dlang.org/";
      platforms = ["x86_64-darwin" "i686-linux" "x86_64-linux"];
    };
  }
