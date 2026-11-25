import yaml
from ruamel.yaml import YAML
a = yaml.safe_load(open("matrice.yaml"))
b = YAML(typ="safe").load(open("matrice.yaml"))
print("%-6s %-28s %s" % ("cle", "PyYAML", "ruamel.yaml (typ safe)"))
for k in a:
    print("%-6s %-28r %r" % (k, a[k], b[k]))
