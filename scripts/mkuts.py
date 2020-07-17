#!/usr/bin/python
# -*- coding: utf-8 -*-

from argparse import ArgumentParser, FileType
from sys import argv, exit
from os import environ
from shlex import split
from Cheetah.Template import Template
from Cheetah import NameMapper

def main():
    parser = ArgumentParser(description='Generate Flat Upgrade Tree ' \
                                        'specification given a ' \
                                        'template definition.')
    parser.add_argument('template',
                        metavar='TEMPLATE_PATH',
                        type=str,
                        help='UTS template input file path')
    parser.add_argument('config',
                        metavar='CONFIG_PATH',
                        type=FileType('r'),
                        help='UTS template configuration file path')
    parser.add_argument('--output',
                        type=str,
                        help='UTS output file path (defaults to stdout)')
    args = parser.parse_args()

    config={}
    for line in args.config:
        for expr in split(line, comments=True):
            assign=expr.split('=', 1)
            if len(assign) == 2:
                config[assign[0]]=assign[1]

    try:
        utsin = Template(file=args.template, namespaces=[config, environ])
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
