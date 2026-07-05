{
  lib,
  buildGo126Module,
  fetchFromGitHub,
}:

buildGo126Module rec {
  pname = "cliproxyapi";
  version = "7.2.50";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-MSKLk+vAVOBSvZpxalgE7hL2vOzBb7IsR4Wqt1QPYGY=";
  };

  vendorHash = "sha256-wrPg5VzbUS4rMpcqPVzDU0RIKHCq0/86fLi3p4DNf9Y=";
  proxyVendor = true;

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=5afc0f1d5e9ed8d47809a1bd1f54834bc7e75375"
    "-X main.BuildDate=unknown"
  ];

  postInstall = ''
    mv $out/bin/server $out/bin/cliproxyapi
  '';

  meta = {
    description = "OpenAI/Gemini/Claude/Codex/Grok compatible API proxy for CLI tools";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = "cliproxyapi";
  };
}
