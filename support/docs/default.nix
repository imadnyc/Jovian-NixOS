# This package provides the documentation
{ stdenv
, callPackage
, runCommand
, writeText
, documentationPath ? ../../docs
, pagefind
}:

let
  # Options
  evalOptions = callPackage ./lib/eval-options.nix { };
  makeOptionsDoc = callPackage ./lib/options-doc.nix  { };
  options = evalOptions { path = ../../modules; };
  inherit (
    (makeOptionsDoc { options = options.jovian; prefix = ../../.; })
  ) optionsJSON;
  optionsJSONFile = "${optionsJSON}/share/doc/nixos/options.json";

  # Documentation resources
  styles = callPackage "${./styles}" { };

  # Documentation build
  output = callPackage (
    { runCommand
    , cmark-gfm
    , ruby
    , documentationPath
    , styles
    }:

    runCommand "Jovian-NixOS-documentation" {
      src = documentationPath;
      nativeBuildInputs = [
        cmark-gfm
        (ruby.withPackages (pkgs: with pkgs; [ nokogiri rouge ]))
        pagefind
      ];
    } ''
      export LANG="C.UTF-8"
      export LC_ALL="C.UTF-8"

      (PS4=" $ "; set -x
      cp --no-preserve=mode -r $src src
      chmod -R +w src

      ruby ${./converter}/options.rb \
        ${./template} ${optionsJSONFile} src/options.md

      ruby ${./converter}/options.rb \
        --namespace jovian.steam --level 3 \
        ${./template} ${optionsJSONFile} src/steam.md

      ruby ${./converter}/main.rb ${./template} src/ $out/
      cp -r ${styles} $out/styles
      )

      # Pagefind indexing
      (PS4=" $ "; set -x
      cd $out

      OPT_OUT=(
        sitemap
        search
      )

      for p in "''${OPT_OUT[@]}"; do
        mv -v $p.html $p.xxx
      done

      # https://pagefind.app/docs/hosting/#hosting-on-github-pages
      pagefind \
        --verbose \
        --bundle-dir !pagefind \
        --root-selector 'body > main' \
        --keep-index-url \
        --source .

      for p in "''${OPT_OUT[@]}"; do
        mv -v $p.xxx $p.html
      done

      )
    ''

  ) {
    inherit documentationPath styles;
  };

  archive = callPackage (
    { runCommand, docs, name }:
      runCommand "${name}.tar.xz" {
        dir = name;
      } ''
        PS4=" $ "
        (set -x
        cp --no-preserve=mode,owner -r ${docs} $dir
        tar -vcJf $out $dir
        )
      ''
    ) {
    docs = output;
    name = "docs.tar.xz";
  };

in
output // {
  inherit archive;
}
