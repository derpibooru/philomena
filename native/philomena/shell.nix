let
  pkgs = import <nixos> {};
in pkgs.mkShell {
  buildInputs = [
    pkgs.cargo 
    pkgs.rustc
    pkgs.rustfmt
    pkgs.clippy
    pkgs.rust-analyzer
  ];
}
