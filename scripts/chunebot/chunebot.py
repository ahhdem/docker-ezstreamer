#!/usr/bin/python3

import discord
from discord.ext import commands
from subprocess import run
from urllib import request
from xmltodict import parse as xmlparse

description = '''An example bot to showcase the discord.ext.commands extension
module.

There are a number of utility commands being showcased here.'''
bot = commands.Bot(command_prefix='?', description=description)

async def findStream(stream):
    url = 'http://STREAM_HOST:STREAM_PORT/%s.xspf' % stream
    file = request.urlopen(url)
    data = file.read()
    file.close()

    data = xmlparse(data)
    stats = data['playlist']['trackList']['track']
    stats['stream'] =  stream

    return stats if stats['title'] else None


async def getStreamStatus():
    streams = ['live', 'radio']
    for stream in streams:
        details = await findStream(stream)
        if details:
            break;

    a_list = [ stat for stat in details['annotation'].split('\n')]
    for stat in a_list:
        s = stat.split(':')
        details[s[0]] = s[1]

    return details


async def nowPlaying():
    current = ''
    while current == '':
        current = run(['/bin/cat', '/config/now-playing'], capture_output=True, text=True).stdout

    path_bits=current.split('/')
    return '/'.join(path_bits[5:])


async def skipTo(song='', stream='radio'):
    if (song):
       await setNextTrack(song)
    skipped=await nowPlaying()
    current=skipped
    run(['/next', stream])
    if (song == 'now-playing'):
        # Dont wait for song change if restarting
        return (skipped, current)
    # Wait for the song to change
    while current == skipped:
        current = await nowPlaying()

    return (skipped, current)


async def setNextTrack(track):
    run(['cp','/config/%s' % track, '/config/next'])
    return True

@bot.event
async def on_ready():
    print('Logged in as %s (uid: %d)' % (bot.user.name, bot.user.id))


@bot.command()
async def next(ctx, stream="radio"):
    """Skips to next song"""
    print("Skipping track")
    await ctx.send('Skipped %s - Now playing: %s' % await skipTo(stream=stream))


@bot.command()
async def playing(ctx):
    """Show currently playing track"""
    await ctx.send('Now playing: %s' % (await nowPlaying()))


@bot.command()
async def back(ctx, stream='radio'):
    """Restarts current radio song"""
    print("Restarting track")
    (skipped, current) = await skipTo('now-playing', stream)
    await ctx.send('Restarting: %s' % current)


@bot.command()
async def prev(ctx, stream='radio'):
    """Restarts current radio song (there is no back!)"""
    print("Playing previous track")
    await ctx.send('Skipped %s - Now playing: %s' % await skipTo('previous', stream))

@bot.command()
async def stats(ctx):
    """Gets current stream stats"""
    print("Fetching stats")
    status = await getStreamStatus()
    msg = 'Tune in!  STREAM_URL\nNow Playing: {creator} - {title}\nListeners: {listeners}\nQuality: {bitrate}kbps'.format(
            stream='live', #status['stream'],
            creator=status['creator'],
            title=status['title'],
            listeners=status['Current Listeners'],
            bitrate=status['Bitrate'])

    await ctx.send(msg)


bot.run('CHUNEBOT_TOKEN')
