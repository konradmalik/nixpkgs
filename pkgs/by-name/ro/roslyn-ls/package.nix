{ lib, fetchFromGitHub, buildDotnetModule, dotnetCorePackages, stdenvNoCC, testers, roslyn-ls }:
let
  pname = "roslyn-ls";
  vsVersion = "2.16.24";
  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  # need sdk on runtime as well
  dotnet-runtime = dotnet-sdk;

  project = "Microsoft.CodeAnalysis.LanguageServer";

in
buildDotnetModule {
  inherit pname dotnet-sdk dotnet-runtime;

  src = fetchFromGitHub {
    owner = "dotnet";
    repo = "roslyn";
    rev = "VSCode-CSharp-${vsVersion}";
    hash = "sha256-pTZ8cEqDupfZn6SfVd38mJnDEABvXW1S3xaRd0LryoY=";
  };

  # versioned independently from vscode-csharp
  # read from https://github.com/dotnet/roslyn/blob/main/eng/Versions.props
  version = "4.10.0-1";
  projectFile = "src/Features/LanguageServer/${project}/${project}.csproj";
  useDotnetFromEnv = true;
  nugetDeps = ./deps.nix;

  postPatch = ''
    substituteInPlace $projectFile \
      --replace-fail \
        '<RuntimeIdentifiers>win-x64;win-x86;win-arm64;linux-x64;linux-arm64;alpine-x64;alpine-arm64;osx-x64;osx-arm64</RuntimeIdentifiers>' \
        '<RuntimeIdentifiers>linux-x64;linux-arm64;osx-x64;osx-arm64</RuntimeIdentifiers>'
  '';

  # custom installPhase with --no-build removed
  # BuildHost project within roslyn is running Build target during publish
  installPhase =
    let
      rid = dotnetCorePackages.systemToDotnetRid stdenvNoCC.targetPlatform.system;
    in
    ''
      runHook preInstall

      dotnet publish $projectFile \
          -p:ContinuousIntegrationBuild=true \
          -p:Deterministic=true \
          -p:InformationalVersion=$version \
          -p:UseAppHost=true \
          -p:PublishTrimmed=false \
          --no-self-contained \
          --output "$out/lib/$pname" \
          --runtime ${rid}

      runHook postInstall
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
    mainProgram = project;
  };
}
