#!/usr/bin/python
# -*- coding: utf-8 -*-

from __future__ import print_function
from argparse import ArgumentParser, RawTextHelpFormatter
from sys import argv, exit, stderr
from os import path
from shlex import split
from Cheetah.Template import Template
from Cheetah import NameMapper

def parse_spec(config, expr):
    var = expr.split('=', 1)
    if len(var) == 2 and (len(var[0]) > 0):
        config[var[0]]=var[1]
        return

    print("{}: '{}': Invalid '{}' variable definition." \
          .format(argv[0], expr, var[0]), file=stderr)
    exit(1)

def main():
    parser = ArgumentParser(description='Output content out of a template '
                                        'according to configuration variables.',
                            epilog='where:\n'
                                   '  CONFIG_SPEC ::= CONFIG_PATH | CONFIG_EXPR\n'
                                   '  CONFIG_EXPR ::= CONFIG_VAR=CONFIG_VAL\n'
                                   '\n'
                                   'with:\n'
                                   '  CONFIG_PATH      path to template configuration file containing one\n'
                                   '                   CONFIG_EXPR per line\n'
                                   '  CONFIG_VAR       name of a variable used by TEMPLATE_PATH\n'
                                   '  CONFIG_VAL       value assigned to CONFIG_VAR',
                            formatter_class=RawTextHelpFormatter)
    parser.add_argument('template',
                        metavar='TEMPLATE_PATH',
                        type=str,
                        help='template input file path')
    parser.add_argument('spec',
                        metavar='CONFIG_SPEC',
                        type=str,
                        nargs='+',
                        help='template configuration specification')
    parser.add_argument('--output',
                        type=str,
                        help='output file path (defaults to stdout)')
    args = parser.parse_args()

    config={}
    for spec in args.spec:
        expr = spec.split('=', 1)
        if len(expr) != 2:
            try:
                with open(spec, 'r') as infile:
                    for line in infile:
                        for expr in split(line, comments=True):
                            parse_spec(config, expr)
            except Exception as e:
                print("{}: {}.".format(argv[0], e), file=stderr)
                exit(1)
        else:
            parse_spec(config, spec)

    try:
        prod = Template(file=args.template, namespaces=[config])
        if args.output:
            with open(args.output, 'w') as out:
                out.write(str(prod))
        else:
            print(prod)
    except NameMapper.NotFound as e:
        print("{}: Substition failed: {}.".format(argv[0], e), file=stderr)
        exit(1)
    except Exception as e:
        print("{}: {}.".format(argv[0], e), file=stderr)
        exit(1)

if __name__ == "__main__":
    main()
