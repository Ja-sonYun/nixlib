{
  lib,
  buildGo126Module,
  fetchFromGitHub,
}:

buildGo126Module rec {
  pname = "cliproxyapi";
  version = "7.1.19";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-Fzc1jXvTVrnTfO4tuEtRjBSUYivqpGDZUIbLQQxaG+k=";
  };

  vendorHash = "sha256-wy6Tf7n7+T/GR/RbXrQSxVz6KCuwffRKPRPoDy6SO9I=";
  proxyVendor = true;

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=21fad9dbb447a2ab70d51d0ac3e3d032525a6054"
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
