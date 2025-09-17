#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import hashlib
import os
import re
import sys
from pathlib import Path
from typing import List, Tuple

# ----------------------------------------------------------------------
# Error codes (mirroring the Bash definitions)
# ----------------------------------------------------------------------
CFG_OK             = 0
CFG_INTERNAL_ERR   = 11
CFG_SYNTAX_ERROR   = 12
CFG_EXTNAME_ERROR  = 13
CFG_KEYWORD_ERROR  = 14
CFG_INVALID_CHAR   = 15
CFG_MISSING_FILE   = 16
CFG_DUPLICATE_TYPE = 17
CFG_DUPLICATE_KEY  = 18
CFG_UNSUPPORTED    = 19
CFG_MISSING_PATH   = 20

# ----------------------------------------------------------------------
# Global strings / numbers
# ----------------------------------------------------------------------

INDENT   = 24          # description indent for help lines
LINELEN  = 80          # output line length
BUF_SIZE = 65536       # read files in 64kb chunks!

# ----------------------------------------------------------------------
# Regular expressions used by the original script
# ----------------------------------------------------------------------
EXTERNAL_REGEX = r"[A-Za-z][A-Za-z0-9_]*"
VERSION_REGEX  = r"[1-9][0-9]*\.[0-9]*\.[0-9]*"

def file_hash(filepath: str) -> str:
    """
    Return a deterministic hash string for *filepath*.
    """
    sha1 = hashlib.sha1()
    with open(filepath, 'rb') as hfile:
    while True:
        data = hfile.read(BUF_SIZE)
        if not data:
            break
        # end if
        sha1.update(data)
    # end while
    return sha1.hexdigest()

def strip_arg(*parts: str) -> str:
    """Join *parts*, trim outer whitespace and squeeze inner spaces."""
    joined = " ".join(parts)
    # split() removes any amount of whitespace, then join with a single space
    return " ".join(joined.split())

def parse_keyword_value(line: str) -> str:
    """Extract the key and value of a ``key = value`` line."""
    return strip_arg(line.split("=", 1))

def valid_string(value: str, regex: str) -> int:
    """
    Return 0 if *value* matches *regex*, otherwise return CFG_INVALID_CHAR.
    Mirrors the Bash ``[[ "$1" =~ $2 ]]`` test.
    """
    if re.fullmatch(regex, value):
        return CFG_OK
    # end if
    return CFG_INVALID_CHAR

def bool_to_string(flag: bool, true_val: str = "True", false_val: str = "False") -> str:
    """
    Return ``true_val`` when *flag* is truthy, otherwise ``false_val``.
    If only *true_val* is supplied, the default ``False`` string is used.
    """
    return true_val if flag else false_val

def check_file(context_msg: str, path: str) -> None:
    """
    Return ``CFG_OK`` if *path* exists and is a file.
    Return``CFG_MISSING_FILE`` if *path* does not exist.
    """
    if Path(path).is_file():
        return CFG_OK
    # end if
    print(f"ERROR: {context_msg}, '{path}', not found", file=sys.stderr)
    return CFG_MISSING_FILE


def check_path(context_msg: str, path: str) -> None:
    """
    Return ``CFG_OK`` if *path* exists and is a directory.
    Return ``CFG_MISSING_PATH`` if *path* is not a directory.
    """
    if Path(path).is_dir():
        return CFG_OK
    # end if
    print(f"ERROR: {context_msg}, '{path}', not found", file=sys.stderr)
    return CFG_MISSING_PATH

def _indent_str() -> str:
    """Return a string consisting of INDENT spaces."""
    return " " * INDENT


def format_line(descriptor: str, description: str) -> None:
    """
    Print *descriptor* followed by *description* wrapped at LINELEN.
    The descriptor is padded/truncated to INDENT columns.
    """
    ind = _indent_str()
    # Ensure descriptor fits within the indent column
    if len(descriptor) <= INDENT - 4:          # keep a few spare spaces
        line = descriptor.ljust(INDENT)
    else:
        # Descriptor too long → print it on its own line
        print(descriptor)
        line = ind

    # Now wrap the description
    words = description.split()
    cur_len = len(line)
    for word in words:
        # If adding the next word exceeds LINELEN, break the line
        if cur_len + len(word) + 1 > LINELEN:
            print(line.rstrip())
            line = ind + word + " "
            cur_len = len(ind) + len(word) + 1
        else:
            line += word + " "
            cur_len += len(word) + 1
    # Print whatever is left
    print(line.rstrip())


def help_screen(header: str, help_options: List[Tuple[str, str, str, str]]) -> None:
    """
    Render a help screen.
    *header* – introductory text (usually the program description).
    *help_options* – a list of 4‑tuples:
        (option_names, hint, description, action_placeholder)
    The placeholder is ignored – it mirrors the Bash signature.
    """
    print(header)
    printed_options = printed_positional = False

    for opt_name, hint, desc, _ in help_options:
        if opt_name == POSITIONAL_KEY:
            if not printed_positional:
                print("\npositional arguments:")
                printed_positional = True
            format_line(hint, desc)
        else:
            if not printed_options:
                print("\noptions:")
                printed_options = True
            format_line(f"{opt_name} {hint}".strip(), desc)
