{ pkgs, lib, ... }:

with lib;

let
  isBinaryName = name: name != "" && !(hasInfix "/" name);

  renderCondition =
    rule:
    let
      blockAiAgent = rule.blockAiAgent or false;
      conditions = [
        "nixenvs_guard_matches ${escapeShellArg (rule.match or ".*")}"
      ]
      ++ optional blockAiAgent "nixenvs_guard_is_ai_agent";
    in
    concatStringsSep " && " conditions;

  renderAction =
    rule:
    let
      inherit (rule) action;
      message = action.message or "Command blocked by guard rule ${rule.name or "unnamed"}.";
    in
    if action.type == "block" then
      ''
        echo ${escapeShellArg message} >&2
        exit 1
      ''
    else if action.type == "confirm" then
      let
        prompt = action.prompt or "Type 'yes' to continue: ";
        confirm = action.confirm or "yes";
      in
      ''
        echo ${escapeShellArg message} >&2
        printf %s ${escapeShellArg prompt} >&2
        IFS= read -r nixenvs_guard_answer || exit 1
        if [ "$nixenvs_guard_answer" != ${escapeShellArg confirm} ]; then
          echo "Aborted." >&2
          exit 1
        fi
        return 0
      ''
    else
      throw "Unsupported guard action type: ${action.type}";

  renderRule =
    rule:
    let
      condition = renderCondition rule;
    in
    ''
      if ${condition}; then
        ${renderAction rule}
      fi
    '';
in
{
  /**
    Create a guarded wrapper for a binary.

    `mkGuard` returns a package that exposes `/bin/${binary}`. The wrapper checks
    command-line arguments against rules before delegating to the original binary
    from `package`.

    # Inputs

    - `package`: The package that provides the original binary.
    - `binary`: The binary name to wrap. This must be a simple binary name, not a path.
    - `rules`: A list of guard rules to evaluate in order (default: empty list).

    # Rule options

    Each rule supports:

    - `name`: Optional rule name used for fallback messages.
    - `match`: Extended regular expression matched against the normalized argv string (default: `".*"`).
    - `blockAiAgent`: Apply this rule only when the process looks like an AI agent.
    - `action`: The action to run when the rule matches.

    The normalized argv string is `"$@"` joined with a single space after shell
    parsing. For example, `terraform apply out.tfplan` is matched as
    `"apply out.tfplan"`.

    `action` supports:

    - `type = "block"`: Print `message` to stderr and exit 1.
    - `type = "confirm"`: Print `message`, read a response, and continue only when it matches `confirm`.
    - `message`: Message printed before blocking or prompting.
    - `prompt`: Prompt text for `confirm` actions (default: "Type 'yes' to continue: ").
    - `confirm`: Required response for `confirm` actions (default: "yes").

    # Output

    A package containing the guarded binary.

    # Example usage

    ```
    guardedTerraform = guards.mkGuard {
      package = pkgs.terraform;
      binary = "terraform";
      rules = [
        {
          name = "block-ai-agent-risky-command";
          match = "^(apply|destroy|import|taint|untaint|state( |$)|force-unlock|init( .*)? -(migrate-state|reconfigure|upgrade)(=true)?($| ))";
          blockAiAgent = true;
          action = {
            type = "block";
            message = "This Terraform command is blocked for AI agents. Ask the user to run it manually.";
          };
        }
        {
          name = "block-auto-approve";
          match = "^(apply|destroy)( .*)? -auto-approve(=true)?($| )";
          action = {
            type = "block";
            message = "terraform -auto-approve is blocked.";
          };
        }
        {
          name = "confirm-migrate-state";
          match = "^init( .*)? -migrate-state(=true)?($| )";
          action = {
            type = "confirm";
            message = "terraform init -migrate-state may migrate backend state metadata.";
            prompt = "Type 'yes' to continue: ";
            confirm = "yes";
          };
        }
      ];
    };
    ```
  */
  mkGuard =
    {
      package,
      binary,
      rules ? [ ],
    }:
    assert isBinaryName binary || throw "mkGuard binary must be a binary name";
    pkgs.writeShellScriptBin binary ''
      nixenvs_guard_argv=""

      for nixenvs_guard_arg in "$@"; do
        if [ -z "$nixenvs_guard_argv" ]; then
          nixenvs_guard_argv="$nixenvs_guard_arg"
        else
          nixenvs_guard_argv="$nixenvs_guard_argv $nixenvs_guard_arg"
        fi
      done

      nixenvs_guard_check() {
        ${concatMapStringsSep "\n" renderRule rules}
        return 0
      }

      nixenvs_guard_matches() {
        printf '%s\n' "$nixenvs_guard_argv" | ${pkgs.gnugrep}/bin/grep -Eq "$1"
      }

      nixenvs_guard_has_any_env() {
        for nixenvs_guard_env_name in "$@"; do
          if nixenvs_guard_env_value="$(${pkgs.coreutils}/bin/printenv "$nixenvs_guard_env_name")" \
            && [ -n "$nixenvs_guard_env_value" ]; then
            return 0
          fi
        done

        return 1
      }

      nixenvs_guard_is_ai_agent() {
        nixenvs_guard_has_any_env \
          CODEX_CI \
          CODEX_SANDBOX \
          CODEX_THREAD_ID \
          CLAUDECODE \
          CURSOR_AGENT
      }

      nixenvs_guard_check "$@"
      exec ${package}/bin/${binary} "$@"
    '';
}
