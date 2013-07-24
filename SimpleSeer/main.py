#!/usr/bin/env python
import os
import sys
import time
import gevent
import argparse
import cProfile
import threading
from pprint import pprint

import pkg_resources

subcommand_list = list()

class MyArgumentParser(argparse.ArgumentParser):
  def error(self, message):
      message = "\n\nAvailable Commands:\n\r"
      for s in sorted(subcommand_list):
        msg = "\t" + s + "\n"
        message += msg
      super(MyArgumentParser, self).error(message)
      
        
def main():
    parser = MyArgumentParser()
    parser.add_argument('-l', '--logging', dest='logging', default='simpleseer-logging.cfg')
    parser.add_argument(
        '-c', '--config', dest='config', default='.')
    parser.add_argument('-p', '--profile', action='store_true')
    parser.add_argument('--profile-heap', action='store_true')
    
    subparsers = parser.add_subparsers(
        title='subcommands',
        description='valid subcommands',
        help=argparse.SUPPRESS
        )
    
    # Load commands
    for ep in pkg_resources.iter_entry_points('seer.commands'):
        cls = ep.load()
        sp = subparsers.add_parser(
            ep.name, description=cls.__doc__)
        subcommand_list.append(ep.name)
        cmd = cls(sp)
        sp.set_defaults(command=ep.name)
        sp.set_defaults(subcommand=cmd)

    # parse args
    options = parser.parse_args()
    options.subcommand.configure(options)
    
    if options.profile:
        log = logging.getLogger('simpleseer')
        fn = options.command + '.profile'
        log.info('Running under profiler. Stats saved to %s', fn)
        cProfile.runctx('options.subcommand.run()',
                        globals=globals(),
                        locals=locals(),
                        filename=fn)
    else:
        options.subcommand.run()

    
    
if __name__ == '__main__':
   main()

