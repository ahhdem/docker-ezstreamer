#!/usr/bin/python3

import discord
from discord.ext import commands
from json import loads as json_loads
from subprocess import run
from urllib import request
from youtube_search import YoutubeSearch
from xmltodict import parse as xmlparse
import csv

debug = True
LOG_ROOT = '/var/log/ezstreamer'
description = '''An example bot to showcase the discord.ext.commands extension
module.

There are a number of utility commands being showcased here.'''
bot = commands.Bot(command_prefix='?', description=description)

# Returns results of GET on URI against icecast host
async def getIcecast(uri):
    url = 'http://STREAM_HOST:STREAM_PORT/%s' % uri
    file = request.urlopen(url)
    data = file.read()
    file.close()

    return data


async def findStream(stream):
    stats = []
    uri = '%s.xspf' % stream
    data = xmlparse(await getIcecast(uri))

    if 'playlist' in data and 'trackList' in data['playlist'] and data['playlist']['trackList']:
        stats = data['playlist']['trackList']['track']
        stats['stream'] = stream

    return stats if 'title' in stats else None

async def getStreams():
    data = await getIcecast('status3.xsl')

    return data


async def getStreamStatus(stream=''):
    streams = ['live', 'radio']
    if stream: 
        details = await findStream(stream)
    else:
        for stream in streams:
            details = await findStream(stream)
            if details:
                break;

    # build resultset from annotations 
    if details:
        a_list = [ stat for stat in details['annotation'].split('\n')]
        for stat in a_list:
            s = stat.split(':')
            details[s[0]] = s[1]

    return details


async def nowPlaying(stream='radio'):
    current = ''
    #print("Fetching playing song for %s" % stream)
    while current == '':
        now_playing = '%s/now-playing-%s' % (LOG_ROOT, stream)
        with open(now_playing, 'r') as f:
            x = f.readlines()
            try:
                current = x[0]
            except:
                continue

    path_bits=current.split('/')
    return '/'.join(path_bits[2:]).rstrip()


async def skipTo(song='', stream='radio'):
    if (song):
       await setNextTrack(song, stream)
    skipped=await nowPlaying(stream)
    current=skipped
    run(['/next', stream])
    if (song == 'now-playing-%s' % stream):
        # Dont wait for song change if restarting
        return (skipped, current)
    # Wait for the song to change
    print("Fetching playing song for %s" % stream)
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
    print("Skipping track on %s" % stream)
    await ctx.send("""~~%s~~ ➜ \n ▶ %s""" % await skipTo(stream=stream))


@bot.command()
async def playing(ctx, stream='radio'):
    """Show currently playing track"""
    print("Requesting playing song for %s" % stream)
    await ctx.send('Now playing: %s' % (await nowPlaying(stream)))


@bot.command()
async def back(ctx, stream='radio'):
    """Restarts current radio song"""
    print("Restarting track on %s" % stream)
    (skipped, current) = await skipTo('now-playing-%s' % stream, stream)
    await ctx.send('⏎  %s' % current)


@bot.command()
async def prev(ctx, stream='radio'):
    """Restarts current radio song (there is no back!)"""
    print("Playing previous track on %s" % stream)
    await ctx.send('Skipped %s - Now playing: %s' % await skipTo('previous-%s' % stream, stream))


@bot.command()
async def yt(ctx, stream='radio'):
    """Triggers fmbot to search youtube for current track by filename """
    # TODO provide switch between file and metadata
    status = await getStreamStatus(stream)
    if 'creator' in status or 'title' in status:
        creator = status['creator'] if 'creator' in status else ""
        title = status['title'] if 'title' in status else ""
        terms = "%s - %s" % (creator, title)

    else:
        path = await nowPlaying(stream)
        print("No metadata available, using path: %s" % path)
        terms = path.split('/')[-2].split('.')[0].replace('/', ' - ')

    
    print("Searching YouTube with terms: %s" % terms)
    results = json_loads(YoutubeSearch(terms, max_results=10).to_json())
    #print("Got results: %s" % results)
    if len(results['videos']) > 0: 
#        description = "Multiple results found, please choose one" if len(results['videos']) > 1 else "Best match:"
        vid = results['videos'][0]
        title_bits = vid['title'].split('-')
        artist = title_bits[0]
        track = '-'.join(title_bits[1:])
        embed = discord.Embed(
                title="Searching for: %s" % terms, 
                description=artist)
                #color='0xff0000')
        thumb_url = 'https://img.youtube.com/vi/%s/0.jpg' % vid['id']
        embed.set_thumbnail(url=thumb_url)
        if creator: embed.set_author(name=creator)

        await ctx.send(embed=embed)
        await ctx.send('https://youtu.be/%s' % vid['id']) 
    else:
        await ctx.send("No matches found for %s" % terms)
   

@bot.command()
async def streams(ctx):
    """Gets streams from icecast"""
    print("Fetching streamlist from icecast server")
    data = await getStreams()
    rows = data.decode("utf-8").split('\n')
    data = {}

    rows.pop(0) # remove empty entry
    # TODO: list comp?
    headers = rows.pop(0).split(',')
    for row in rows:
        i=0
        # split by comma, ignore quoted comma
        values = [ '"{}"'.format(x) for x in list(csv.reader([row], delimiter=','))[0] ]
        for value in values: 
            value = value.replace('"', '')
            if not value: continue
            if i==0: 
                stream=value
                data[stream] = {}
            data[stream][headers[i]] = value
            i += 1

    embed = discord.Embed(
            title="Stream status")
    for k, v in data.items():
        print(v)
        if 'title' not in v: continue
        listeners = v['listeners'] if 'listeners' in v else "Unknown"
        title = v['title'] if 'title' in v else 'Unknown'
        artist = v['artist'] if 'artist' in v else 'Unknown'
        msg = "Listening: {listeners}\n**Playing**: *{artist}* - *{title}*\nhttps://STREAM_URL{stream}".format(
                listeners=listeners,
                artist=artist,
                title=title,
                stream=k)
        embed.add_field(name=v['name'], value=msg)

    await ctx.send(embed=embed)


@bot.command()
async def stats(ctx, stream='radio'):
    """Gets current stream stats"""
    print("Fetching stats for stream %s" % stream)
    status = await getStreamStatus(stream)
    if status:
        creator=status['creator'] if 'creator' in status else 'Unknown'
        title=status['title'] if 'title' in status else 'Unknown'
        listeners=status['Current Listeners'] if 'Current Listeners' in status else 'Unknown'
        bitrate=status['Bitrate'] if 'Bitrate' in status else 'Unknown'
        stream_source=status['stream'] if 'stream' in status else 'Unknown'

        msg = 'Tune in! https://STREAM_URL/{stream}\nNow Playing: {creator} - {title}\nListeners: {listeners}\nQuality: {bitrate}kbps'.format(
            stream=status['stream'],
            creator=creator,
            title=title,
            listeners=listeners,
            bitrate=bitrate)
    else:
        msg = "Hmmm.. it doesnt look like anything is playing there right now :(  Try https://STREAM_URL/live to automatically find a channel" 

    await ctx.send(msg)


bot.run('CHUNEBOT_TOKEN')
