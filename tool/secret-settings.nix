{ lib, pkgs, ... }:

with lib;

let
  secretPrefix = "@nix-secret-";

  pathToString = path: if builtins.isPath path then toString path else path;

  secretName = path: "secret-${builtins.hashString "sha256" (pathToString path)}";

  secretPlaceholder = path: "${secretPrefix}${builtins.hashString "sha256" (pathToString path)}@";

  isSecret = value: builtins.isAttrs value && value ? _secret;

  isValidSecret =
    value:
    isSecret value
    && builtins.attrNames value == [ "_secret" ]
    && (builtins.isString value._secret || builtins.isPath value._secret);

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
      secretPlaceholder value._secret
    else if builtins.isAttrs value then
      mapAttrs (_: replaceSecrets) value
    else if builtins.isList value then
      map replaceSecrets value
    else
      value;
in
settings:
let
  secretValues = collectSecrets settings;
  secretPaths = unique (map pathToString secretValues);
  usesSecretsFrom =
    secrets:
    let
      paths = mapAttrsToList (_: secret: pathToString secret.path) secrets;
    in
    any (path: elem path paths) secretPaths;
in
{
  inherit secretPaths usesSecretsFrom;

  value = replaceSecrets settings;

  invalidSecretPaths = collectInvalid [ ] settings;

  restartTriggers = filter builtins.isPath secretValues;

  credentials = map (path: "${secretName path}:${path}") secretPaths;

  agenixDependencies =
    { config, options }:
    let
      ageSecrets = if options ? age && options.age ? secrets then config.age.secrets else { };
    in
    optional (usesSecretsFrom ageSecrets) "agenix-install-secrets.service";

  replacementScript =
    runtimeConfigFile:
    concatMapStringsSep "\n" (path: ''
      ${pkgs.replace-secret}/bin/replace-secret ${escapeShellArg (secretPlaceholder path)} "$CREDENTIALS_DIRECTORY/${secretName path}" ${escapeShellArg runtimeConfigFile}
    '') secretPaths;
}
