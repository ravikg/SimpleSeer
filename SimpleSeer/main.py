#!/usr/bin/env python
import os
import sys
import time
import gevent
import argparse
from argparse import ArgumentParser
import cProfile
import threading
from pprint import pprint
import pkg_resources

parser_dict = dict()
subcommand_list = list()
help_dict = dict()

def prettyCommandList():
    cmds = "\n\nAvailable Commands:\n\r"
    max = 0  # So doc strings are left justified.
    for s in subcommand_list:
        if len(s) > max:
            max = len(s)
    for s in sorted(subcommand_list):
        docs = help_dict[s] or ''
        if len(docs.split('\n')):
            docs = docs.split('\n')[0]
        docs = docs.strip()
        s = s + ' ' * (max - len(s))
        msg = '\t' + s + '\t\t' + docs + '\n'
        cmds += msg
    return cmds


class MyArgumentParser(ArgumentParser):

    def error(self, message):
        message = prettyCommandList()
        call = self._get_kwargs()[0][1]
        pattern = call.split(' ')
        if len(pattern) > 1:
            command = pattern[1]
            if command and command in subcommand_list:
                parser_dict[command].print_help()
                sys.exit(2)
        super(MyArgumentParser, self).error(message)
        return


def main():
    parser = MyArgumentParser()
    parser.add_argument('-l', '--logging', dest='logging',
                        default='simpleseer-logging.cfg')
    parser.add_argument('-c', '--config', dest='config', default='.')
    parser.add_argument('-p', '--profile', action='store_true')
    parser.add_argument('--profile-heap', action='store_true')
    parser.add_argument('--config-override', dest='config_override', default="{}")

    subparsers = parser.add_subparsers(title='subcommands',
            description='valid subcommands', help = argparse.SUPPRESS)

    # Load commands

    for ep in pkg_resources.iter_entry_points('seer.commands'):
        cls = ep.load()
        sp = subparsers.add_parser(ep.name, description=cls.__doc__)
        subcommand_list.append(ep.name)
        parser_dict[ep.name] = sp
        help_dict[ep.name] = cls.__doc__
        cmd = cls(sp)
        sp.set_defaults(command=ep.name)
        sp.set_defaults(subcommand=cmd)

    # parse args
    options = parser.parse_args()
    options.config_override = eval(options.config_override)
    options.subcommand.configure(options)

    if options.profile:
        log = logging.getLogger('simpleseer')
        fn = options.command + '.profile'
        log.info('Running under profiler. Stats saved to %s', fn)
        cProfile.runctx('options.subcommand.run()', globals=globals(),
                        locals=locals(), filename=fn)
    else:
        options.subcommand.run()


if __name__ == '__main__':
    main()
