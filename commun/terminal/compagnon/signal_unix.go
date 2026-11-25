//go:build unix

package main

import "syscall"

// Le shell reçoit SIGHUP quand la page se ferme, comme à la fermeture d'une fenêtre de terminal.
var sighup = syscall.SIGHUP
