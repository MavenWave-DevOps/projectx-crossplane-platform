#!/bin/sh

SCRIPT_DIR="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"

TENANTS=10

if [ $1 == "create" ]; then
  for i in $(seq 1 $TENANTS); do
    pushd $SCRIPT_DIR/../overlays/local
    kustomize edit set namespace team$i
    kustomize build . | kubectl apply -f -
    popd
  done
fi

if [ $1 == "destroy" ]; then
  for i in $(seq $TENANTS -1 1 ); do
    pushd $SCRIPT_DIR/../overlays/local
    kustomize edit set namespace team$i
    kustomize build . | kubectl delete -f -
    popd
  done
fi