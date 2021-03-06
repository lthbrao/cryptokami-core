let
  localLib = import ./lib.nix;
in
{ system ? builtins.currentSystem
, config ? {}
, gitrev ? localLib.commitIdFromGitRepo ./.git
, pkgs ? (import (localLib.fetchNixPkgs) { inherit system config; })
# profiling slows down performance by 50% so we don't enable it by default
, enableProfiling ? false
, enableDebugging ? false
}:

with pkgs.lib;
with pkgs.haskell.lib;

let
  addGitRev = subject: subject.overrideAttrs (drv: { GITREV = gitrev; });
  addRealTimeTestLogs = drv: overrideCabal drv (attrs: {
    testTarget = "--log=test.log || (sleep 10 && kill $TAILPID && false)";
    preCheck = ''
      mkdir -p dist/test
      touch dist/test/test.log
      tail -F dist/test/test.log &
      export TAILPID=$!
    '';
    postCheck = ''
      sleep 10
      kill $TAILPID
    '';
  });
  cryptokamiPkgs = ((import ./pkgs { inherit pkgs; }).override {
    overrides = self: super: {
      cryptokami-sl-core = overrideCabal super.cryptokami-sl-core (drv: {
        configureFlags = (drv.configureFlags or []) ++ [
          "-f-asserts"
        ];
      });

      cryptokami-core = overrideCabal super.cryptokami-core (drv: {
        # production full nodes shouldn't use wallet as it means different constants
        configureFlags = (drv.configureFlags or []) ++ [
          "-f-asserts"
        ];
        # waiting on load-command size fix in dyld
        doCheck = ! pkgs.stdenv.isDarwin;
        passthru = {
          inherit enableProfiling;
        };
      });

      cryptokami-sl-networking = dontCheck super.cryptokami-sl-networking;
      cryptokami-sl-client = addRealTimeTestLogs super.cryptokami-sl-client;
      cryptokami-sl-generator = addRealTimeTestLogs super.cryptokami-sl-generator;
      cryptokami-sl-auxx = addGitRev (justStaticExecutables super.cryptokami-sl-auxx);
      cryptokami-sl-node = addGitRev super.cryptokami-sl-node;
      cryptokami-sl-wallet = addGitRev (justStaticExecutables super.cryptokami-sl-wallet);
      cryptokami-sl-tools = addGitRev (justStaticExecutables (overrideCabal super.cryptokami-sl-tools (drv: {
        # waiting on load-command size fix in dyld
        doCheck = ! pkgs.stdenv.isDarwin;
      })));

      cryptokami-sl-node-static = justStaticExecutables self.cryptokami-sl-node;
      cryptokami-sl-explorer-static = addGitRev (justStaticExecutables self.cryptokami-sl-explorer);
      cryptokami-report-server-static = justStaticExecutables self.cryptokami-report-server;

      # Undo configuration-nix.nix change to hardcode security binary on darwin
      # This is needed for macOS binary not to fail during update system (using http-client-tls)
      # Instead, now the binary is just looked up in $PATH as it should be installed on any macOS
      x509-system = overrideDerivation super.x509-system (drv: {
        postPatch = ":";
      });

      # TODO: get rid of pthreads option once cryptonite 0.25 is released
      # DEVOPS-393: https://github.com/haskell-crypto/cryptonite/issues/193
      cryptonite = appendPatch (appendConfigureFlag super.cryptonite "--ghc-option=-optl-pthread") ./pkgs/cryptonite-segfault-blake.patch;

      # Due to https://github.com/CryptoKami/stack2nix/issues/56
      hfsevents = self.callPackage ./pkgs/hfsevents.nix { inherit (pkgs.darwin.apple_sdk.frameworks) Cocoa CoreServices; };

      mkDerivation = args: super.mkDerivation (args // {
        enableLibraryProfiling = enableProfiling;
        enableExecutableProfiling = enableProfiling;
      } // optionalAttrs enableDebugging {
        # TODO: DEVOPS-355
        dontStrip = true;
        configureFlags = (args.configureFlags or []) ++ [ "--ghc-options=-g --disable-executable-stripping --disable-library-stripping" "--profiling-detail=toplevel-functions"];
      });
    };
  });
  connect = let
      walletConfigFile = ./custom-wallet-config.nix;
      walletConfig = if builtins.pathExists walletConfigFile then import walletConfigFile else {};
    in
      args: import ./scripts/launch/connect-to-cluster (args // walletConfig // { inherit gitrev; });
  other = rec {
    mkDocker = { environment, connectArgs ? {} }: import ./docker.nix { inherit environment connect gitrev pkgs connectArgs; };
    stack2nix = import (pkgs.fetchFromGitHub {
      owner = "CryptoKami";
      repo = "stack2nix";
      rev = "3b1807dc5011704ae6a045e612a679c6fbf9ceb3";
      sha256 = "0p545wbfrg569hspcdpw9v6zd9ngifdj2wsvxpxsdypw124j3jdl";
    }) { inherit pkgs; };
    inherit (pkgs) purescript;
    connectScripts = {
      mainnetWallet = connect {};
      mainnetExplorer = connect { executable = "explorer"; };
      stagingWallet = connect { environment = "mainnet-staging"; };
      stagingExplorer = connect { executable = "explorer"; environment = "mainnet-staging"; };
    };
    dockerImages = {
      mainnetWallet = mkDocker { environment = "mainnet"; };
      stagingWallet = mkDocker { environment = "mainnet-staging"; };
    };
  };
in cryptokamiPkgs // other
