#!/usr/bin/env python
'''
https://github.com/jboynyc/cmus_app
'''
# =======================================================================
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as
#   published by the Free Software Foundation, either version 3 of the
#   License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
# =======================================================================


from optparse import OptionParser
try:
    from configparser import ConfigParser
except ImportError:
    from ConfigParser import SafeConfigParser as ConfigParser
from bottle import abort, post, request, response, route, run, view, static_file
from sh import cmus_remote, ErrorReturnCode_1
import os


class ConfigFileNotFound(IOError):
    '''Raised when the specified config file does not exist or is empty.'''
    pass


class MissingSetting(Exception):
    '''Raised when the config file is missing a required setting.'''
    pass


def read_config(config_file):
    r = {}
    try:
        config_parser = ConfigParser(inline_comment_prefixes=';')
    except TypeError:
        config_parser = ConfigParser()
    n = config_parser.read(config_file)
    if not len(n):
        raise ConfigFileNotFound(config_file)
    section = 'cmus_app'
    fields = ['cmus_host', 'cmus_passwd', 'app_host', 'app_port', 'serve_albumart', 'app_statusrefresh_f','app_statusrefresh_o','app_statusrefresh_s','app_statusrefresh_e','volume_change','show_cmus_settings']
    for field in fields:
        try:
            r[field] = config_parser.get(section, field)
        except:
            raise MissingSetting(field)
    return r


def get_cmus_status():
    try:
        #out = Remote('-Q').stdout.decode('utf-8').split('\n')
        out = Remote('-Q').stdout.split('\n')
        r = {'tag':{},'set':{}}
        for i in out:
            if i.startswith('tag') or i.startswith('set'):
                k, v = i.split()[1], i.split()[2:]
                if len(v): r[i.split()[0]][k] = ' '.join(v)
            elif len(i):
                k, v = i.split()[0], i.split(' ',1)[1]
                if len(v): r[k] = v
        return r
    except ErrorReturnCode_1:
        return false


def get_full_status():
    r = get_cmus_status()
    if r != False:
        #album art
        if settings['serve_albumart'] == 'yes':
            file_path = os.path.dirname(r['file'])
            try:
                foundimages = [fn for fn in os.listdir(file_path) if fn.lower().endswith(('.jpg','.jpeg','.jpe','.bmp','.png','.gif'))]
                if len(foundimages) > 0:
                    imgpriorities = ['cover','front','folder','albumart']
                    foundimg = None
                    for p in imgpriorities:
                        i = [i for i in foundimages if p in i.lower()]
                        if len(i)>0:
                            foundimg = file_path+'/'+i[0]
                            break
                    if foundimg is None:
                        foundimg = file_path+'/'+foundimages[0]
                else:
                    foundimg = False
                r['albumart_file'] = foundimg
            except:
                r['albumart_file'] = False
        else:
            r['albumart_file'] = False

        return r
    else:
        return false




@route('/')
@view('main')
def index():
    return {'host': settings['cmus_host'], 'app_statusrefresh_f': settings['app_statusrefresh_f'], 'app_statusrefresh_o': settings['app_statusrefresh_o'], 'app_statusrefresh_s': settings['app_statusrefresh_e'], 'app_statusrefresh_e': settings['app_statusrefresh_s'], 'show_cmus_settings': settings['show_cmus_settings']}


@post('/cmd')
def run_command():
    command = request.POST.get('command', default=None)
    param = request.POST.get('param', default=None)
    legal_commands = {'Play': 'player-play',
                      'Stop': 'player-stop',
                      'Pause':'player-pause',
                      'Next': 'player-next',
                      'Previous': 'player-prev',
                      'Increase Volume': 'vol +' + settings['volume_change'] + '%',
                      'Reduce Volume': 'vol -' + settings['volume_change'] + '%',
                      'Mute': 'vol 0',
                      'toggle': ''}
    if command in legal_commands:
        if command == 'Mute':
            if param != None:
                param = param.split('|')
                if isinstance(param, list):
                    if int(param[0]) >= 0 and int(param[0]) <= 100 and int(param[1]) >= 0 and int(param[1]) <= 100:
                        legal_commands['Mute'] = 'vol ' + param[0] + '% ' + param[1] + '%'
                    else:
                        abort(400, 'Invalid command.')
        if command == 'toggle':
            legal_toggles = ['aaa_mode','shuffle','repeat','repeat_current']
            if param in legal_toggles:
                legal_commands['toggle'] = 'toggle '+param
            else:
                abort(400, 'Invalid command.')

        try:
            out = Remote('-C', legal_commands[command])
            return {'result': out.exit_code, 'output': out.stdout.decode()}
        except ErrorReturnCode_1:
            abort(503, 'Cmus not running.')
    else:
        abort(400, 'Invalid command.')


@route('/status')
def fetch_status():
    s = get_cmus_status()
    if s != False:
        r = {'status': s['status'], 'position': s['position'], 'file': s['file']}
        return r
    else:
        abort(503, 'Cmus not running.')


@route('/fullstatus')
def fetch_full_status():
    r = get_full_status()
    if r != False:
        return r
    else:
        abort(503, 'Cmus not running.')


#TODO: ajaxbrowser for files (extrat data from lib.pl?) for search and queue


@route('/album_art/<file:re:.*\.(jpg|jpeg|jpe|bmp|png|gif)>')
def album_art_file(file):
    if settings['serve_albumart'] == 'yes':
        status = get_full_status()
        response.set_header('Cache-Control', 'max-age=604800')
        if status['albumart_file'] == file:
            return static_file(file, root='/')
        else:
            return static_file('noalbumart.png', root='static')
    else:
        return static_file('noalbumart.png', root='static')


@route('/static/<file:path>')
def static(file):
    response.set_header('Cache-Control', 'max-age=604800')
    return static_file(file, root='static')


@route('/favicon.ico')
def favicon():
    response.set_header('Cache-Control', 'max-age=604800')
    return static_file('favicon.ico', root='static')


if __name__ == '__main__':
    option_parser = OptionParser()
    option_parser.add_option('-f', '--config', dest='config_file',
                             help='Location of configuration file.')
    option_parser.add_option('-c', '--cmus-host', dest='cmus_host',
                             help='Name of cmus host.',
                             default='localhost')
    option_parser.add_option('-w', '--cmus-passwd', dest='cmus_passwd',
                             help='Cmus password.',
                             default='')
    option_parser.add_option('-a', '--app-host', dest='app_host',
                             help='Name of cmus_app host.',
                             default='localhost')
    option_parser.add_option('-p', '--app-port', dest='app_port',
                             help='Port cmus_app is listening on.',
                             default=8080)
    options, _ = option_parser.parse_args()
    if options.config_file:
        settings = read_config(options.config_file)
    else:
        settings = vars(options)
    Remote = cmus_remote.bake(['--server', settings['cmus_host'],
                               '--passwd', settings['cmus_passwd']])
    run(host=settings['app_host'], port=settings['app_port'])
