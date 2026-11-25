# Cours « Fondements de la virtualisation de machines »

- `cm/` : les diapos, avec les notes de l’orateur, dans `virtualisation.typ`. PDF compilé :
  [`virtualisation-projection.pdf`](https://jmchantrein.github.io/Cours/virtualisation/cm/virtualisation-projection.pdf). `cm/rejouer-tp.sh` rejoue les sorties
  du mini TP sur une machine avec KVM ; `cm/rejouer-libvirt.sh` celles de la partie « Administrer avec libvirt » (avec `cm/invite-acpi.sh`, un invité minimal
  qui obéit à `virsh shutdown`, sans rien installer).
- `tp/libvirt/` : le TP « Administrer des VM avec libvirt ». `libvirt.typ` contient l’énoncé (page web),
  `corrige/` les corrigés (XML de domaine et de réseaux, scripts), et `tester.sh` les vérifie :
  `--lint` (schémas libvirt, shellcheck), `--up` (cycle complet d’une VM sur `qemu:///system`, en émulation,
  sans `/dev/kvm`).

Compilation et charte : voir le [README racine](../README.md) et [`../commun/README.md`](../commun/README.md).
