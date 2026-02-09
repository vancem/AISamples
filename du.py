#!/usr/bin/env python3
"""
Disk usage utility. Recursively enumerates a folder, summing file sizes,
and reports inclusive/exclusive sizes per directory, sorted by inclusive size.
"""

import argparse
import os
import stat
import sys
import time
from pathlib import Path
from dataclasses import dataclass, field


HELP_TEXT = """
    Usage: du [folder]

    Summarize the disk usage for a folder (including sub folders)

    Parameters:
        [folder]        The directory to summarize, defaults to the current directory
    Qualifiers:
        [-Percent:Num]   Trim directories to less than this percentage defaults to 1.
"""


@dataclass
class DirUsage:
    """Disk usage for a directory."""
    name: str
    exclusive_size: int = 0
    inclusive_size: int = 0
    children: list["DirUsage"] = field(default_factory=list)


def _preprocess_argv(argv: list[str]) -> list[str]:
    """Support -Percent:5 syntax by splitting into -Percent 5."""
    result: list[str] = []
    for arg in argv:
        if arg.startswith("-Percent:") and len(arg) > len("-Percent:"):
            result.extend(["-Percent", arg[len("-Percent:"):]])
        else:
            result.append(arg)
    return result


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse command line arguments."""
    argv = argv if argv is not None else sys.argv[1:]
    argv = _preprocess_argv(argv)

    if "-?" in argv or "-h" in argv or "--help" in argv:
        print(HELP_TEXT.strip())
        sys.exit(0)

    parser = argparse.ArgumentParser(prog="du", add_help=False)
    parser.add_argument(
        "folder",
        nargs="?",
        default=".",
        help="Directory to summarize (default: current directory)",
    )
    parser.add_argument(
        "-Percent",
        dest="percent",
        metavar="Num",
        type=float,
        default=1.0,
        help="Minimum percentage of root size to include (default: 1)",
    )
    return parser.parse_args(argv)


def compute_du(
    path: Path,
    file_count: list[int],
    dot_callback: tuple[int, int] | None,
) -> DirUsage | None:
    """
    Recursively compute disk usage for a directory.
    Returns None if path is not a directory or on permission error.
    """
    try:
        st = os.stat(path, follow_symlinks=True)
        if not stat.S_ISDIR(st.st_mode):
            print(f"Node {path} is not a directory", file=sys.stderr)
            return None
        entries = list(path.iterdir())
    except OSError as e:
        print(f"Error accessing {path}: {e}", file=sys.stderr)
        return None

    usage = DirUsage(name=str(path))
    children: list[DirUsage] = []

    for entry in sorted(entries, key=lambda p: p.name):
        try:
            st = os.stat(entry, follow_symlinks=False)
            if stat.S_ISREG(st.st_mode):
                size = st.st_size
                usage.exclusive_size += size
                usage.inclusive_size += size
                file_count[0] += 1
                if dot_callback:
                    count, line_len = dot_callback
                    if file_count[0] % 100 == 0:
                        print(".", end="", flush=True)
                        line_len[0] += 1
                        if line_len[0] >= 80:
                            print()
                            line_len[0] = 0
            elif stat.S_ISDIR(st.st_mode):
                child = compute_du(entry, file_count, dot_callback)
                if child is not None:
                    usage.inclusive_size += child.inclusive_size
                    children.append(child)
        except OSError:
            pass

    usage.children = children
    return usage


def flatten_by_percent(
    du: DirUsage,
    min_size: int,
    result: list[DirUsage],
) -> None:
    """Flatten directory tree, keeping only directories >= min_size."""
    if du.inclusive_size < min_size:
        return
    result.append(du)
    for child in du.children:
        flatten_by_percent(child, min_size, result)

# TODO: remove this function, it is not needed.
def format_size_mb(size_bytes: int) -> str:
    """Format size in MB with 2 decimal places."""
    return f"{size_bytes / 1_000_000:.2f}M"

# TODO: simplify this, the output path separator can be whatever is most convenient for the code.  
def format_path(path: Path, base: Path) -> str:
    """Format path for display, using native separators."""
    try:
        rel = path.resolve().relative_to(base.resolve())
        if rel == Path("."):
            return "."
        return "." + os.sep + str(rel).replace("/", os.sep)
    except ValueError:
        return str(path)


def main() -> None:
    args = parse_args()
    folder = Path(args.folder).resolve()
    percent = args.percent

    print(f"Getting disk usage for: {folder}")

    file_count: list[int] = [0]
    line_len: list[int] = [0]
    dot_callback = (file_count, line_len)

    start = time.perf_counter()
    root = compute_du(folder, file_count, dot_callback)

    if line_len[0] > 0:
        print()
    elapsed = time.perf_counter() - start
    hrs = int(elapsed // 3600)
    mins = int((elapsed % 3600) // 60)
    secs = elapsed % 60
    print(f"Elapsed time = {hrs:02d}:{mins:02d}:{secs:05.2f}")

    if root is None:
        sys.exit(1)

    min_size = int(root.inclusive_size * (percent / 100)) if percent > 0 else 0
    flat: list[DirUsage] = []
    flatten_by_percent(root, min_size, flat)
    if root not in flat:
        flat.insert(0, root)

    flat.sort(key=lambda d: d.inclusive_size, reverse=True)

    print()
    print("Inclusive     Exclusive       Directory")
    print("Size           Size")
    print("----------------------------------------------------------------------------")
    for d in flat:
        path_str = format_path(Path(d.name), folder)
        incl = format_size_mb(d.inclusive_size)
        excl = format_size_mb(d.exclusive_size)
        print(f"{incl:>10}  {excl:>10}      {path_str}")


if __name__ == "__main__":
    main()
