{ inputs, ... }:
{
  flake = {
    herculesCI.ciSystems = [ "x86_64-linux" ];
    effects = let
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      hci-effects = inputs.hercules-ci-effects.lib.withPkgs pkgs;
    in { branch, rev, ... }: {
      macos-repeatability-test = hci-effects.mkEffect {
        __hci_effect_mounts = builtins.toJSON {
          "/hostTmp" = "hostTmp";
        };
        secretsMap."ipfsBasicAuth" = "ipfsBasicAuth";
        buildInputs = with pkgs; [ libwebp gnutar curl nix jq coreutils-full ];
        effectScript = ''
          getStateFile macos-repeatability-test-outpath previousOutpath
          if [[ "$(cat previousOutpath)" == "$out" ]]
          then
            echo "Effect outpath: $out"
            echo "Effect inputs are the same as the last successful run, skipping"
            exit 0
          fi

          readSecretString ipfsBasicAuth .basicauth > .basicauth
          export NIX_CONFIG="experimental-features = nix-command flakes"

          # How many times to build macOS
          max_iterations=3
          iteration=0

          function build {
            set +e
            nix build '${inputs.self.packages.x86_64-linux.macos-ventura-image.drvPath}^*' --timeout 20000 --keep-failed -L 2>&1 | tee /dev/stderr
          }
          function rebuild {
            set +e
            nix build '${inputs.self.packages.x86_64-linux.macos-ventura-image.drvPath}^*' --timeout 20000 --keep-failed --rebuild -L 2>&1 | tee /dev/stderr
          }

          function upload_failure {
            export TMPDIR="/hostTmp"
            export DRVNAME=$(basename $1)
            export IMAGESPATH="$TMPDIR/$DRVNAME"
            mkdir images
            for i in $TMPDIR/$DRVNAME/tmp*/*.png
            do
              echo converting "$i" into webp
              ( cwebp -quiet -q 10 $i -o images/$(basename $i).webp ) &
            done
            wait
            tar -cf nixtheplanet-macos-debug.tar images
            export RESPONSE=$(curl -H @.basicauth -F file=@nixtheplanet-macos-debug.tar https://ipfs-api.croughan.sh/api/v0/add)
            export CID=$(echo "$RESPONSE" | jq -r .Hash)
            export ADDRESS="https://ipfs.croughan.sh/ipfs/$CID"

            echo NixThePlanet: Failure screen capture is available at: "$ADDRESS"
            exit 254
          }
          echo 'Running Nix for the first time'
          set +e
          nix_output=$(build)
          build_dir=$(grep -oP "keeping build directory '.*?'" <<< "$nix_output" | awk -F"'" '{print $2}')
          set -e
          if [[ "$nix_output" == *"/tmp"* && "$nix_output" != *"deterministic"* ]]
          then
            upload_failure $build_dir
            echo NixThePlanet: first nix build failed, but this should have been cached!? Something weird is going on.
            exit 1
          fi

          while [ $iteration -lt $max_iterations ]
          do
            echo Running Nix iteration "$iteration"
            set +e
            nix_output=$(rebuild)
            build_dir=$(grep -oP "keeping build directory '.*?'" <<< "$nix_output" | awk -F"'" '{print $2}')
            set -e
            if [[ "$nix_output" == *"/tmp"* && "$nix_output" != *"deterministic"* ]]
            then
              upload_failure $build_dir
              echo NixThePlanet: iteration "$iteration" failed
              exit 1
            fi
            echo NixThePlanet: iteration "$iteration" succeeded
            ((++iteration))
          done
          putStateFile macos-repeatability-test-outpath <(echo "$out")
        '';
      };
    };
  };
}
