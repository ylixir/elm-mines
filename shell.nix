{ pkgs ? import <nixpkgs> {} }:
with pkgs;
stdenv.mkDerivation {
  name = "elm-mines";
  buildInputs = import ./default.nix;
}
