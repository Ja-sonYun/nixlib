{
  lib,
  buildGo126Module,
  fetchFromGitHub,
}:

buildGo126Module rec {
  pname = "cliproxyapi";
  version = "8.0.77";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-8C6m5aSrQN4HiGcNhCJDvoepFHy/bAYOPnrGdrUnSiU=";
  };

  vendorHash = "sha256-MlSvPcUOQsCwFo/SAn+L5aK2C6RoaPF5HGNlSvshbbQ=";
  proxyVendor = true;

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=a5e8f69e56309e1ef6d6872e667da81fdfbce2ce"
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
