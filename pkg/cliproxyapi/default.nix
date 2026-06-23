{
  lib,
  buildGo126Module,
  fetchFromGitHub,
}:

buildGo126Module rec {
  pname = "cliproxyapi";
  version = "7.2.30";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-7kdzuWJNdJf90ZCICmIx7NDN8M2cq6WLfHXUIb30qL0=";
  };

  vendorHash = "sha256-wrPg5VzbUS4rMpcqPVzDU0RIKHCq0/86fLi3p4DNf9Y=";
  proxyVendor = true;

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=f1ed8912bbed42e72499b4065c0eb93667123f98"
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
