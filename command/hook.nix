{ pkgs, lib, ... }:

{
  package,
  binary,
  hooks ? [ ],
}:
let
  quote = lib.escapeShellArg;
  hookFlag = hook: hook.flag or null;
  sortedHooks = lib.sort (a: b: builtins.length a.path > builtins.length b.path) hooks;
  validHook =
    hook:
    hook ? command
    && hook ? path
    && builtins.isList hook.path
    && hook.path != [ ]
    && lib.all (part: builtins.isString part && part != "") hook.path;
  pathTest =
    path:
    lib.concatStringsSep " && " (
      lib.imap0 (
        i: part:
        ''[ "''${command_hook_original_args[$((command_hook_scan_index + ${toString i}))]-}" = ${quote part} ]''
      ) path
    );
  renderHelp =
    hook:
    lib.optionalString (hook ? help) ''
      if [ "''${command_hook_args[0]-}" = "-h" ] || [ "''${command_hook_args[0]-}" = "--help" ]; then
          printf '%s\n' ${quote hook.help}
          exit 0
      fi
    '';
  hookFunctions = lib.concatStringsSep "\n" (
    lib.imap0 (i: hook: ''
      command_hook_run_${toString i}() {
      ${hook.command}
      }
    '') sortedHooks
  );
  hookDispatch = lib.concatStringsSep "\n" (
    lib.imap0 (
      i: hook:
      let
        pathLength = toString (builtins.length hook.path);
        flag = hookFlag hook;
      in
      ''
        command_hook_path_index=-1
        command_hook_scan_index=0
        command_hook_last_index=$((''${#command_hook_original_args[@]} - ${pathLength}))

        ${
          if hook.matchAnywhere or false then
            ''
              while [ "$command_hook_scan_index" -le "$command_hook_last_index" ]; do
                  if ${pathTest hook.path}; then
                      command_hook_path_index=$command_hook_scan_index
                      break
                  fi
                  command_hook_scan_index=$((command_hook_scan_index + 1))
              done
            ''
          else
            ''
              if ${pathTest hook.path}; then
                  command_hook_path_index=0
              fi
            ''
        }

        if [ "$command_hook_path_index" -ge 0 ]; then
            command_hook_args=()
            for ((command_hook_index = 0; command_hook_index < ''${#command_hook_original_args[@]}; command_hook_index++)); do
                if [ "$command_hook_index" -ge "$command_hook_path_index" ] &&
                   [ "$command_hook_index" -lt "$((command_hook_path_index + ${pathLength}))" ]; then
                    continue
                fi
                command_hook_args+=("''${command_hook_original_args[command_hook_index]}")
            done

        ${
          if flag == null then
            ''
              ${renderHelp hook}
              command_hook_run_${toString i} "''${command_hook_args[@]}"
              exit $?
            ''
          else
            ''
              command_hook_flag_args=()
              command_hook_flag_index=-1
              command_hook_index=0

              for command_hook_arg in "''${command_hook_args[@]}"; do
                  if [ "$command_hook_arg" = ${quote flag} ]; then
                      if [ "$command_hook_flag_index" -eq -1 ]; then
                          command_hook_flag_index=$command_hook_index
                      fi
                  else
                      command_hook_flag_args+=("$command_hook_arg")
                  fi
                  command_hook_index=$((command_hook_index + 1))
              done

              if [ "$command_hook_flag_index" -ge 0 ]; then
                  command_hook_args=("''${command_hook_flag_args[@]}")
                  ${renderHelp hook}
                  COMMAND_HOOK_FLAG_INDEX="$command_hook_flag_index" \
                    command_hook_run_${toString i} "''${command_hook_args[@]}"
                  exit $?
              fi
            ''
        }
        fi
      ''
    ) sortedHooks
  );
in
assert binary != "" && !(lib.hasInfix "/" binary);
assert lib.all validHook hooks;
(pkgs.writeShellScriptBin binary ''
  set -euo pipefail

  command_hook_original() {
      ${package}/bin/${binary} "$@"
  }

  ${hookFunctions}

  command_hook_original_args=("$@")

  ${hookDispatch}

  exec ${package}/bin/${binary} "$@"
'').overrideAttrs
  (
    _:
    lib.optionalAttrs (package ? version) {
      inherit (package) version;
    }
  )
