#!/usr/bin/env python
# -*- coding: utf-8 -*-

from sys import argv
from os import popen
from docker import Client

height, width = popen('stty size', 'r').read().split()
threshold = 128
padding = 1 + int(width) // 80
columns = 4
col = { 'cid': 12, 'image': 0, 'command': 0, 'status': 11, 'names': 0 }

def calc_width(denominator):
    if denominator > 1:
        return (int(width) - sum(col.values()) - padding * columns) // denominator
    else:
        return int(width) - sum(col.values()) - padding * columns

def println(line):
    print '{0[0]:<{cid}}{1:<{padding}}'.format(line, '', **col),
    print '{0[1]:<{image}}{1:<{padding}}'.format(line, '', **col),
    if int(width) >= threshold:
        print '{0[2]:<{command}}{1:<{padding}}'.format(line, '', **col),
    print '{0[3]:<{status}}{1:<{padding}}'.format(line, '', **col),
    print '{0[4]:<{names}}'.format(line, **col)

def main(argv, bool):
    global col, columns
    if int(width) >= threshold:
        columns = 5
        arg = calc_width(11) * 2; col['status'] = arg if arg <= 27 else 27
        col['command'] = calc_width(6)
    arg = calc_width(3); col['names'] = arg if arg <= 32 else 32
    arg = calc_width(1); col['image'] = arg if arg <= 71 else 71
    arg = calc_width(1)
    if arg > 0:
        col['command'] = col['command'] + arg
    col['padding'] = padding - 1
    # print col

    if len(argv) == 0:
        hosts = [ 'n{0:03d}'.format(serial) for serial in range(0,11) ] + [ 'hal011', 'hal012' ]
    else:
        hosts = argv[:]

    for host in hosts:
        try:
            print '=== {}'.format(host)
            cli = Client( base_url = 'tcp://' + host + ':2375',
                          version='auto',
                          timeout=10
                         )
            println([ 'CONTAINER ID', 'IMAGE', 'COMMAND', 'STATUS', 'NAMES' ])
            for container in cli.containers( all=bool ):
                println([ container['Id'][0:col['cid']],
                          container['Image'][0:col['image']],
                          '"' + container['Command'][0:col['command']-2] + '"',
                          container['Status'][0:col['status']],
                          container['Names'][0][1:col['names']+1]
                        ])
        except Exception as e:
            print(e)

if __name__ == "__main__":
    if len(argv) == 1 or argv[1] != '-a':
        main(argv[1:], False)
    else:
        main(argv[2:], True)
