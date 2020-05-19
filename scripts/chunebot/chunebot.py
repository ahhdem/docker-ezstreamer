#!/usr/bin/python3

import discord
from discord.ext import commands
from subprocess import run
from urllib import request
from xmltodict import parse as xmlparse

debug = True
LOG_ROOT = '/var/log/ezstreamer'
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


async def nowPlaying(stream='radio'):
    current = ''
    while current == '':
        now_playing = '%s/now-playing-%s' % (LOG_ROOT, stream)
        with open(now_playing, 'r') as f:
            x = f.readlines()
            try:
                current = x[0]
            except:
                continue

    path_bits=current.split('/')
    return '/'.join(path_bits[2:])


async def skipTo(song='', stream='radio'):
    if (song):
       await setNextTrack(song, stream)
    skipped=await nowPlaying(stream)
    current=skipped
    run(['/next', stream])
    if (song == 'now-playing'):
        # Dont wait for song change if restarting
        return (skipped, current)
    # Wait for the song to change
    while current == skipped:
        current = await nowPlaying(stream)

    return (skipped, current)


async def setNextTrack(track, stream):
    run(['cp','%s/%s' % (LOG_ROOT, track), '%s/next-%s' % (LOG_ROOT, stream)])
    return True

@bot.event
async def on_ready():
    print('Logged in as %s (uid: %d)' % (bot.user.name, bot.user.id))

# Ensure context in message events (enables bot chatter)
@bot.event
async def on_message(message):
    ctx = await bot.get_context(message)
    await bot.invoke(ctx)

@bot.command()
async def next(ctx, stream="radio"):
    """Skips to next song"""
    print("Skipping track")
    await ctx.send('Skipped %s - Now playing: %s' % await skipTo(stream=stream))


@bot.command()
async def playing(ctx, stream='radio'):
    """Show currently playing track"""
    await ctx.send('Now playing: %s' % (await nowPlaying(stream)))


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
async def yt(ctx, stream='radio'):
    """Triggers fmbot to search youtube for current track by filename """
    # TODO provide switch between file and metadata
    path = await nowPlaying(stream)
    print("got path: %s" % path)
    terms = path[-1].split('.')[0]
    print("got terms: %s" % terms)
    
    await ctx.send('.fmyt %s' % terms)


@bot.command()
async def stats(ctx):
    """Gets current stream stats"""
    print("Fetching stats")
    status = await getStreamStatus()
    creator=status['creator'] if 'creator' in status else 'Unknown'
    title=status['title'] if 'title' in status else 'Unknown'
    listeners=status['Current Listeners'] if 'Current Listeners' in status else 'Unknown'
    bitrate=status['Bitrate'] if 'Bitrate' in status else 'Unknown'

    msg = 'Tune in!  STREAM_URL\nNow Playing: {creator} - {title}\nListeners: {listeners}\nQuality: {bitrate}kbps'.format(
        stream='live', #status['stream'],
        creator=creator,
        title=title,
        listeners=listeners,
        bitrate=bitrate)

    await ctx.send(msg)


bot.run('CHUNEBOT_TOKEN')
