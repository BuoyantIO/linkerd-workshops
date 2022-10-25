{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkShell {
  buildInputs = [
    bat
    kube3d
    kubernetes-helm
    linkerd
    step-cli
  ];
}
