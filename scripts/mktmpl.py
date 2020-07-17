#!/usr/bin/python
# -*- coding: utf-8 -*-

from argparse import ArgumentParser, FileType
from sys import argv, exit
from os import environ
from shlex import split
from Cheetah.Template import Template
from Cheetah import NameMapper

def main():
    parser = ArgumentParser(description='Generate content given a ' \
                                        'template definition.')
    parser.add_argument('template',
                        metavar='TEMPLATE_PATH',
                        type=str,
                        help='template input file path')
    parser.add_argument('--output',
                        type=str,
                        help='output file path (defaults to stdout)')
    args = parser.parse_args()

    try:
        utsin = Template(file=args.template, namespaces=[environ])
        if args.output:
            with open(args.output, 'w') as out:
                out.write(str(utsin))
        else:
            print(utsin)
    except NameMapper.NotFound as e:
        print("{}: Substition failed: {}.".format(argv[0], e))
        exit(1)
    except Exception as e:
        print("{}: {}.".format(argv[0], e))
        exit(1)

if __name__ == "__main__":
    main()
