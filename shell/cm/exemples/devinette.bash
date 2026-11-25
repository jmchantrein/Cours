#!/bin/bash
compter() {
    total=$((total + 1))
    local message="appel n° $total"
    echo "$message"
}

main() {
    local total=10
    compter
    compter
    ( compter )
    echo "main : total=$total, message=${message:-vide}"
}

main "$@"
echo "script : total=${total:-vide}"
