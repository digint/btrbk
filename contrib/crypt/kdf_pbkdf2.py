#!/usr/bin/env python3
#
# kdf_pbkdf2.py - (kdf_backend for btrbk)
#
# Copyright (c) 2017 Axel Burri
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ---------------------------------------------------------------------
# The official btrbk website is located at:
# http://digint.ch/btrbk/
#
# Author:
# Axel Burri <axel@tty0.ch>
# ---------------------------------------------------------------------

import sys
import os
import getpass
import hashlib

def passprompt():
    pprompt = lambda: (getpass.getpass("Passphrase: "), getpass.getpass("Retype passphrase: "))
    p1, p2 = pprompt()
    while p1 != p2:
        print("No match, please try again", file=sys.stderr)
        p1, p2 = pprompt()
    return p1

if len(sys.argv) <= 1:
    print("Usage: {} <dklen>".format(sys.argv[0]), file=sys.stderr)
    sys.exit(1)

hash_name = "sha256"
iterations = 300000
dklen = int(sys.argv[1])
salt = os.urandom(16)
password = passprompt().encode("utf-8")

dk = hashlib.pbkdf2_hmac(hash_name=hash_name, password=password, salt=salt, iterations=iterations, dklen=dklen)

salt_hex = "".join(["{:02x}".format(x) for x in salt])
dk_hex = "".join(["{:02x}".format(x) for x in dk])

print("KEY=" + dk_hex);
print("algoritm=pbkdf2_hmac");
print("hash_name=" + hash_name);
print("salt=" + salt_hex);
print("iterations=" + str(iterations));
