import json
import os
import subprocess
import sys
import tempfile
from collections.abc import MutableMapping, MutableSequence
from pathlib import Path

import tomlkit
import yaml

LOADERS = {
    "json": json.loads,
    "toml": tomlkit.parse,
    "yaml": yaml.safe_load,
}

DUMPERS = {
    "json": json.dumps,
    "toml": tomlkit.dumps,
    "yaml": lambda value: yaml.safe_dump(value, allow_unicode=True, sort_keys=False),
}


def expand(path):
    if "$" not in path:
        return path
    return subprocess.run(
        ["/bin/sh", "-c", f'printf "%s" "{path}"'],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout


def read_secret(path):
    value = Path(expand(path)).read_text(encoding="utf-8").rstrip("\r\n")
    if not value:
        raise ValueError("empty secret")
    return value


def resolve(value):
    if isinstance(value, MutableMapping):
        if "_secret" in value:
            if list(value) != ["_secret"] or not isinstance(value["_secret"], str):
                raise ValueError("invalid _secret value")
            return read_secret(value["_secret"])
        for key in list(value):
            value[key] = resolve(value[key])
    elif isinstance(value, MutableSequence):
        for index, item in enumerate(value):
            value[index] = resolve(item)
    return value


def write(destination, text):
    if destination == "-":
        sys.stdout.write(text)
        return
    path = Path(destination)
    descriptor, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            output.write(text)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def main():
    input_format, output_format, source, destination = sys.argv[1:]
    text = (
        sys.stdin.read() if source == "-" else Path(source).read_text(encoding="utf-8")
    )
    settings = resolve(LOADERS[input_format](text))
    write(destination, DUMPERS[output_format](settings))


if __name__ == "__main__":
    sys.excepthook = lambda kind, _error, _trace: print(
        f"Could not resolve secrets ({kind.__name__})", file=sys.stderr
    )
    main()
