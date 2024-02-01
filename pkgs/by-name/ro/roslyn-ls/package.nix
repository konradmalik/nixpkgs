{ lib, fetchFromGitHub, buildDotnetModule, dotnetCorePackages, testers, roslyn-ls }:
let
  pname = "roslyn-ls";
  vsVersion = "2.12.19";
  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  # need sdk on runtime otherwise most function won't work
  dotnet-runtime = dotnet-sdk;
  project = "Microsoft.CodeAnalysis.LanguageServer";
  srcPath = "src/Features/LanguageServer/${project}";
in
buildDotnetModule {
  inherit pname dotnet-sdk dotnet-runtime;

  # versioned independently from vscode-csharp
  # read from https://github.com/dotnet/roslyn/blob/main/eng/Versions.props
  version = "4.9.0-3";

  src = fetchFromGitHub {
    owner = "dotnet";
    repo = "roslyn";
    rev = "VSCode-CSharp-${vsVersion}";
    hash = "sha256-S3bRIgtQ7VIA3PYxnSlo3DxwmwExWsRi1STU+KGrFPM=";
  };

  projectFile = "${srcPath}/${project}.csproj";
  nugetDeps = ./deps.nix;
  dotnetBuildFlags = [ "--output ./out" ];
  useDotnetFromEnv = true;

  # not needed after update
  postPatch = ''
    sed -i 's/"rollForward": "disable"/"rollForward": "patch"/' global.json
  '';

  # override because "error NETSDK1085: The 'NoBuild' property was set to true but the 'Build' target was invoked."
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    mv ./out $out/lib/${pname}

    runHook postInstall
  '';

  postFixup = ''
    mv $out/bin/${project} $out/bin/${pname}
    rm $out/bin/Microsoft*
  '';

  passthru = {
    tests.version = testers.testVersion { package = roslyn-ls; };
  };

  meta = {
    homepage = "https://github.com/dotnet/vscode-csharp";
    description = "The language server behind C# Dev Kit for Visual Studio Code";
    changelog = "https://github.com/dotnet/vscode-csharp/releases/tag/v${vsVersion}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ konradmalik ];
    mainProgram = "roslyn-ls";
  };
}
