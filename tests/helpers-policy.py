"""Les privilèges Nix doivent suivre exactement les listes des assistants amont."""
import json
from pathlib import Path
import subprocess
import sys

helpers = Path(sys.argv[1]) / "bin"
rules = json.loads(Path(sys.argv[2]).read_text())
commands = {
    command["command"]
    for rule in rules if rule.get("users") == ["testeur"]
    for command in rule["commands"]
}
assert commands and all("ALL" not in command for command in commands)
for name in ("nc-energie-root", "nc-vpn-root"):
    output = subprocess.check_output([str(helpers / name), "sudoers", "testeur"], text=True)
    expected = set(output.strip().split("NOPASSWD: ", 1)[1].split(", "))
    actual = {command for command in commands if f"/bin/{name} " in command}
    assert actual == expected, (name, sorted(actual ^ expected))
print("Règles sudo : listes énergie et VPN conformes à l'amont.")
