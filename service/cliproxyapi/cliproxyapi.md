# CLIProxyAPI {#module-services-cliproxyapi}

Enable the CLIProxyAPI service with:

```nix
{
  services.cliproxyapi.enable = true;
}
```

The service defaults to `127.0.0.1:8317` and runs with a systemd dynamic user.
It generates `/run/cliproxyapi/config.yaml` from
[](#opt-services.cliproxyapi.settings) at startup. Configure the service through
NixOS options; edits to the generated file are replaced at the next start.

## Authentication {#module-services-cliproxyapi-authentication}

Provider authentication files are stored in `/var/lib/cliproxyapi/auth` by default.
The `auth-dir` setting selects this directory. Keep authentication files readable
by the service's dynamic user.

Values in [](#opt-services.cliproxyapi.settings) are written to the Nix store.
Use `{ _secret = "/path/to/file"; }` for secret values. The module loads these
files through systemd credentials and substitutes their contents into the runtime
configuration before starting the service.

### Management API {#module-services-cliproxyapi-authentication-management-api}

Configure a management secret through a runtime file:

```nix
{
  services.cliproxyapi.settings.remote-management.secret-key._secret =
    "/run/secrets/cliproxyapi-management-key";
}
```

Remote management access and the control panel are disabled by default through
`remote-management.allow-remote = false` and
`remote-management.disable-control-panel = true`.

### Command-line login {#module-services-cliproxyapi-authentication-cli}

Use the CLI from [](#opt-services.cliproxyapi.package) for provider login options.
Interactive commands outside the systemd service do not inherit its credentials
or filesystem access. Configure them to use the service's `auth-dir` and ensure
the resulting authentication files remain accessible to the service.

The managed configuration is `/run/cliproxyapi/config.yaml`, not a file under
`/var/lib/cliproxyapi`. It is generated when the service starts and is private to
the service user.
