#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Linux kernel / U-Boot compliant mtdparts string parsing (and display).

mtdparts string is specified according the following rules:
  mtdparts   := <mtd-def>[;<mtd-def>...]
  <mtd-def>  := <mtd-id>:<part-def>[,<part-def>...]
  <mtd-id>   := unique device tag used by linux kernel to find mtd device
  <part-def> := <size>[@<offset>][<name>][<ro-flag>]
  <size>     := standard linux memsize OR '-' to denote all remaining space
  <offset>   := partition start offset within the device
  <name>     := '(' NAME ')'
  <ro-flag>  := when set to 'ro' makes partition read-only (not used)
"""

import argparse
import os
import sys
import re

class MtdPartStore:
    """Maintain a list of MTD devices and partitions."""

    _devs = []
    _curr_part = {}


    def _curr_busy(self):
        """Return busy area in bytes from start of current device."""

        if len(self._devs[-1]['parts']) == 0:
            # Current device has no registered partition yet.
            return 0
        # Retrieve last registered partition.
        last = self._devs[-1]['parts'][-1]
        # Busy area starts at offset 0 and finishes at last byte of last
        # registered partition.
        return last['off'] + last['size']


    def new_dev(self, mtdid):
        """Register a new device identified by the given argument."""

        # Initialize device with an empty partition list.
        dev = { 'id': mtdid, 'parts': [] }
        # Clear the flag indicating wether the current device is full or not.
        self._curr_full = False
        # Register device to internal device list.
        self._devs.append(dev)


    def init_part(self):
        """Register a new empty partition to the current device."""

        if self._curr_full:
            # Last registered partition filled all current device remaining
            # space...
            raise Exception("Failed to add new partition: "
                            "{} device full".format(self._devs[-1]['id']))
        # Initialize temporary partition with offset starting just after the
        # last filled byte and infinite size.
        self._curr_part = {
            'size' : 0,
            'off'  : self._curr_busy(),
            'name' : None,
            'ro'   : False
        }


    def fini_part(self):
        """Finalize temporary partition and register it to current device."""

        self._devs[-1]['parts'].append(self._curr_part)


    def set_part_size(self, size):
        """Setup temporary partition size."""

        # Infinite size specified: mark current device as full. No additional
        # partition may be registered into this device.
        if size == 0:
            self._curr_full = True
        self._curr_part['size'] = size


    def set_part_off(self, off):
        """Setup temporary partition offset."""

        if off < self._curr_busy():
            # Given offset overlaps with current device busy space...
            raise Exception("Failed to set {} device partition start offset to "
                            "0x{:x}: overlaps with existing registered areas "
                            "[0:0x{:x}]".format(self._devs[-1]['id'],
                                                off,
                                                self._curr_busy() - 1))
        self._curr_part['off'] = off


    def set_part_name(self, name):
        """Setup temporary partition name."""

        self._curr_part['name'] = name


    def set_part_ro(self):
        """Setup temporary partition read-only flag."""

        self._curr_part['ro'] = True


    def get_current_dev_id(self):
        return self._devs[-1]['id']

    def get_part_byname(self, name):
        """Retrieve a registered partition by name and return it."""

        for dev in self._devs:
            for part in dev['parts']:
                if part['name'] == name:
                    return part
        return None


    def get_parts(self):
        """Return the list of registered partitions."""

        for dev in self._devs:
            for part in dev['parts']:
                yield part


class MtdPartView:
    _store = None


    def __init__(self, store):
        self._store = store


    def _display_part(self, part):
        """Print partition given in argument."""

        if part['ro']:
            ro = 'ro'
        else:
            ro = 'rw'
        print("{}\n"
              "  offset   : 0x{:x}\n"
              "  size     : 0x{:x}\n"
              "  read-only: {}".format(part['name'],
                                       part['off'],
                                       part['size'],
                                       part['ro']))


    def display_part_byname(self, name):
        """Retrieve partition by name given in argument and display it."""

        part = self._store.get_part_byname(name)
        if not part:
            raise Exception("'{}' partition not found".format(name))
        self._display_part(part)


    def display_parts(self):
        """Display all registered partitions."""

        for part in self._store.get_parts():
            self._display_part(part)



class MtdPartParser:
    _ctx = None


    def __init__(self, context):
        self._ctx = context


    def _raise_error(self, msg, *args):
        id = self._ctx.get_current_dev_id()
        raise Exception(("device '{}': " + msg).format(id, *args))


    def _parse_part_size(self, partdef):
        tokens = re.split('@|\(|ro', partdef, maxsplit=1)
        nr = len(tokens)
        if nr == 0 or len(tokens[0]) == 0:
            self._raise_error("missing size specification: '{}'", partdef)

        mult = 1
        if tokens[0][0] == '-':
            if len(tokens[0]) > 1:
                self._raise_error("invalid size specification: '{}'", partdef)
            size = 0
        else:
            if tokens[0][-1] == 'g':
                mult = 1024 * 1024 * 1024
            elif tokens[0][-1] == 'm':
                mult = 1024 * 1024
            elif tokens[0][-1] == 'k':
                mult = 1024
            try:
                if mult == 1:
                    size = int(tokens[0], 0)
                else:
                    size = int(tokens[0][:-1], 0)
            except Exception as e:
                self._raise_error("invalid size specification: "
                                  "integer conversion error: '{}'",
                                  partdef)

        self._ctx.set_part_size(size * mult)

        if nr == 1:
            return None
        return partdef[len(tokens[0]):]


    def _parse_part_offset(self, partdef):
        if partdef[0] != '@':
            return partdef

        tokens = re.split('\(|ro', partdef[1:], maxsplit=1)
        nr = len(tokens)
        if nr == 0 or len(tokens[0]) == 0:
            self._raise_error("empty offset specification: '{}'", partdef)

        try:
            off = int(tokens[0], 0)
        except Exception as e:
            self._raise_error("invalid offset specification: "
                              "integer conversion error: '{}'",
                              partdef)

        self._ctx.set_part_off(off)

        if nr == 1:
            return None
        return partdef[(1 + len(tokens[0])):]


    def _parse_part_name(self, partdef):
        if partdef[0] != '(':
            return partdef

        tokens = partdef[1:].split(')', maxsplit=1)
        nr = len(tokens)
        if nr == 0 or len(tokens[0]) == 0:
            self._raise_error("empty name specification: '{}'", partdef)
        if (len(tokens[0]) + 1) >= len(partdef) or \
           partdef[len(tokens[0]) + 1] != ')':
            self._raise_error("invalid name specification: '{}'", partdef)

        self._ctx.set_part_name(tokens[0])

        if nr == 1:
            return None
        return tokens[1]


    def _parse_part_ro(self, partdef):
        if partdef != 'ro':
            return partdef

        self._ctx.set_part_ro()

        if len(partdef) > 2:
            return partdef[2:]
        return None


    def _parse_part_def(self, partdef):
        partdef = self._parse_part_size(partdef)
        if not partdef:
            return
        partdef = self._parse_part_offset(partdef)
        if not partdef:
            return
        partdef = self._parse_part_name(partdef)
        if not partdef:
            return
        partdef = self._parse_part_ro(partdef)
        if partdef:
            self._raise_error("excess elements in partition definition: '{}'",
                              partdef)


    def _parse_mtd_def(self, mtddef):
        tokens = mtddef.split(':')
        if len(tokens) < 2:
            self._raise_error("invalid device specification: '{}'", mtddef)
        if len(tokens[0]) == 0:
            self._raise_error("empty device ID specification: '{}'", mtddef)
        self._ctx.new_dev(tokens[0])

        partlist = tokens[1]
        if len(partlist) == 0:
            self._raise_error("empty partition list specification: '{}'",
                              mtddef)
        for partdef in partlist.split(','):
            self._ctx.init_part()
            self._parse_part_def(partdef)
            self._ctx.fini_part()


    def parse(self, mtdparts):
        if len(mtdparts) == 0:
            raise Exception("empty specification")
        for mtddef in mtdparts.split(';'):
            self._parse_mtd_def(mtddef)


def main():
    parser = argparse.ArgumentParser(description= \
        'Parse and display a Linux kernel / U-Boot compliant mtdparts string '
        'given on stdin.')
    parser.add_argument('part_name',
                        metavar='PART_NAME',
                        type=str,
                        nargs='?',
                        default=None,
                        help='MTD partition name')
    args = parser.parse_args()

    store = MtdPartStore()
    parser = MtdPartParser(store)
    view = MtdPartView(store)

    try:
        line = None
        for line in sys.stdin:
            # Remove leading and trailing space characters...
            parser.parse(line.strip(' \f\n\r\t\v'))
        if not line:
            raise Exception("Null input")

        if args.part_name:
            view.display_part_byname(args.part_name)
        else:
            view.display_parts()
    except KeyboardInterrupt:
        print("\n{}: interrupted.".format(os.path.basename(sys.argv[0])),
              file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print("{}: {}.".format(os.path.basename(sys.argv[0]), e),
              file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
