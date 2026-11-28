{ lib, pkgs, ... }:

with lib;

let
  isSecret = value: builtins.isAttrs value && value ? _secret;

  isValidSecret =
    value:
    isSecret value && builtins.attrNames value == [ "_secret" ] && builtins.isString value._secret;

  pathToString = path: if builtins.isPath path then toString path else path;

  secretName = path: "secret-${builtins.hashString "sha256" path}";

  showPath = path: if path == [ ] then "<root>" else concatStringsSep "." path;

  collectInvalid =
    path: value:
    if isSecret value && !isValidSecret value then
      [ (showPath path) ]
    else if builtins.isAttrs value then
      concatLists (mapAttrsToList (name: collectInvalid (path ++ [ name ])) value)
    else if builtins.isList value then
      concatLists (imap0 (index: collectInvalid (path ++ [ "[${toString index}]" ])) value)
    else
      [ ];

  collectSecrets =
    value:
    if isValidSecret value then
      [ value._secret ]
    else if builtins.isAttrs value then
      concatLists (mapAttrsToList (_: collectSecrets) value)
    else if builtins.isList value then
      concatMap collectSecrets value
    else
      [ ];

  replaceSecrets =
    value:
    if isValidSecret value then
      { _secret = "$CREDENTIALS_DIRECTORY/${secretName value._secret}"; }
    else if builtins.isAttrs value then
      mapAttrs (_: replaceSecrets) value
    else if builtins.isList value then
      map replaceSecrets value
    else
      value;

  paths = settings: unique (collectSecrets settings);

  readSecret = pkgs.writeShellScript "read-secret" ''
    mode=$1
    timeout=$2
    path=$3
    elapsed=0
    while :; do
      if value=$(${pkgs.coreutils}/bin/cat -- "$path" 2>/dev/null) && [ -n "$value" ]; then
        printf '%s' "$value"
        exit 0
      fi
      case $mode in
        empty) exit 0 ;;
        fail) break ;;
      esac
      if [ -n "$timeout" ] && [ "$elapsed" -ge "$timeout" ]; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 1
      elapsed=$((elapsed + 1))
    done
    printf "secret file '%s' is missing or empty\n" "$path" >&2
    exit 1
  '';

  resolver = pkgs.writeShellScriptBin "resolve-secrets" ''
    exec ${
      pkgs.python3.withPackages (ps: [
        ps.tomlkit
        ps.pyyaml
      ])
    }/bin/python3 ${./resolve-secrets.py} "$@"
  '';
in
{
  inherit
    isSecret
    isValidSecret
    paths
    resolver
    ;

  readCommand =
    {
      mode,
      timeout ? null,
    }:
    path:
    assert elem mode [
      "empty"
      "fail"
      "wait"
    ];
    "${readSecret} ${mode} ${escapeShellArg (toString timeout)} \"${path}\"";

  type = types.addCheck (types.attrsOf types.str) isValidSecret;

  invalidPaths = settings: collectInvalid [ ] settings;

  credentials = settings: map (path: "${secretName path}:${path}") (paths settings);

  agenixDependencies =
    settings:
    { config, options }:
    let
      ageSecrets = if options ? age && options.age ? secrets then config.age.secrets else { };
      agePaths = mapAttrsToList (_: secret: pathToString secret.path) ageSecrets;
    in
    optional (any (path: elem path agePaths) (paths settings)) "agenix-install-secrets.service";

  installConfig =
    settings: format: destination:
    let
      template = pkgs.writeText "${baseNameOf destination}.json" (
        builtins.toJSON (replaceSecrets settings)
      );
    in
    "${getExe resolver} json ${format} ${template} ${escapeShellArg destination}";
}
