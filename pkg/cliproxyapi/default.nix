{
  lib,
  buildGo126Module,
  fetchFromGitHub,
}:

buildGo126Module rec {
  pname = "cliproxyapi";
  version = "8.0.24";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-YqyywNAgA7/CAadZuESPIqDMhqxw0pj9RDNPCK4uq0I=";
  };

  vendorHash = "sha256-ju7dRQIDvz/oHP5Y6y0hklEBNPzwrtWqSQ7cr51jwTY=";
  proxyVendor = true;

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=091ff27f31285ec4fd1dd5823b44f7f51fb8f48b"
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
