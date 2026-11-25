#!/bin/bash
# sshd_config, exercice 1 : les directives actives, sans les commentaires ni les lignes vides.
sed '/^#/d; /^$/d' sshd_config
