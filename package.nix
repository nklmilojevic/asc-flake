{
  lib,
  stdenv,
  fetchurl,
}:
let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  platform =
    sources.platforms.${stdenv.hostPlatform.system}
      or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "asc";
  version = sources.version;

  src = fetchurl {
    url = platform.url;
    hash = platform.hash;
  };

  dontUnpack = true;

  # The Linux artifacts are static Go binaries and the macOS ones link only
  # system frameworks, so nothing has to be patched; keeping them byte-identical
  # also preserves the Developer ID signature on the Mach-O builds.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -m755 -D $src $out/bin/asc
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" ASC_TELEMETRY_DISABLED=1 $out/bin/asc --version | grep -q "${sources.version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Unofficial CLI for App Store Connect";
    homepage = "https://asccli.sh";
    changelog = "https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/${sources.version}";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "asc";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
