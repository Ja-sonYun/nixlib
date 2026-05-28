{
  lib,
  stdenvNoCC,
  amber-lang,
  makeWrapper,
  age,
  bash,
  bc,
  coreutils,
  gnused,
}:

let
  runtimePath = lib.makeBinPath [
    age
    bash
    bc
    coreutils
    gnused
  ];
in
stdenvNoCC.mkDerivation {
  pname = "agenix-utils";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    amber-lang
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild

    for src in src/*.ab; do
      name="$(basename "$src" .ab)"
      amber build --no-proc=bshchk "$src" "$name"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 encrypt-secret "$out/bin/encrypt-secret"
    install -Dm755 decrypt-secret "$out/bin/decrypt-secret"
    install -Dm755 edit-secret "$out/bin/edit-secret"
    install -Dm755 load-secret "$out/bin/load-secret"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/encrypt-secret" \
      --prefix PATH : ${runtimePath}
    wrapProgram "$out/bin/decrypt-secret" \
      --prefix PATH : ${runtimePath}
    wrapProgram "$out/bin/edit-secret" \
      --prefix PATH : ${runtimePath}
    wrapProgram "$out/bin/load-secret" \
      --prefix PATH : ${runtimePath}
  '';

  meta = {
    description = "Small age helpers for encrypting, decrypting, editing, and loading env secrets";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
