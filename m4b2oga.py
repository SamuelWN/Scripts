#!/usr/bin/env python3

# Converts m4b audio file to an opus oga + cue file
#
# Adapted from script by TheMetalCenter:
#   https://github.com/TheMetalCenter/m4b-mp3-chapters-from-cuesheets/blob/main/export-cue.py
#
# Usage:
#  m4b2oga.py <input>.m4b
#
# Requires:
#  ffmpeg-python


import argparse
import datetime
import logging
import os
import sys
import ffmpeg

try:
    from ffmpeg import probe as ffprobe
except ImportError:
    from ffmpeg import _probe
    ffprobe = _probe.probe



def m4b2opus(m4b_file):
    """
    Generate a Ogg Audio (.oga) file from the provided M4B audio file.

    Parameters:
    m4b_file (str): The path to the input M4B audio file.

    Returns:
    str: The path to the generated OGA audio file.
    """
    oga_file = os.path.splitext(m4b_file)[0] + '.oga'
    (
        ffmpeg
        .input(m4b_file)
        .output(oga_file,
                acodec='libopus', audio_bitrate='48k',
                map_metadata=0
            )
        .overwrite_output()
        .run()
    )
    return oga_file


def get_chapters(m4b_file):
    """
    Retrieve the chapters from the specified m4b file.

    Parameters:
    m4b_file (str): The path to the m4b file.

    Returns:
    list: A list of chapters extracted from the m4b file.
    """
    return ffprobe(m4b_file, show_chapters=None)['chapters']


def book_info(file):
    """
    Extracts the performer and title information from an audio file using ffprobe.

    Parameters:
        file (str): The path to the audio file.

    Returns:
        tuple: A tuple containing the performer (str) and title (str) extracted from the audio file.
               If the performer cannot be extracted, an empty string is returned.
               If the title cannot be extracted, the basename of the audio file is used.
    """
    tags = ffprobe(file)['format']['tags']
    keys = list(tags.keys())
    keys_upper = list(map(str.upper, keys))

    title = "placeholder"

    try:
        performer=tags[keys[keys_upper.index('ARTIST')]]
    except ValueError:
        try:
            performer=tags[keys[keys_upper.index('PERFORMER')]]
        except ValueError:
            try:
                performer=str(tags['performer'])
            except ValueError:
                performer=''
    try:
        title=tags[keys[keys_upper.index('ALBUM')]]
    except ValueError:
        try:
            title=tags[keys[keys_upper.index('TITLE')]]
        except ValueError:
            title=os.path.splitext(os.path.basename(file))[0]
    return performer, title

def create_cue_sheet(names, track_times, timebases, start_time=datetime.timedelta(seconds=0)):
    """Yields the next cue sheet entry given the track names, times.

    Args:
        names: List of track names.
        track_times: List of timdeltas containing the track times.
        timebases: List of timebases per track
        performers: List of performers to associate with each cue entry.
        start_time: The initial time to start the first track at.

    The lengths of names and track times should be the same.
    """
    accumulated_time = start_time


    for track_index, (name, track_time, timebase) in enumerate(
            zip(names, track_times, timebases)):
        minutes = int(accumulated_time.total_seconds() / (timebase*60))
        seconds = int((int(accumulated_time.total_seconds() % (timebase*60))) / timebase)
        frames = int(float(float((int(accumulated_time.total_seconds() % (timebase*60))) / timebase) % 1) * 75)

        cue_sheet_entry = '''  TRACK {:02} AUDIO
    TITLE "{}"
    INDEX 01 {:02d}:{:02d}:{:02d}'''.format(track_index, name, minutes, seconds, frames)
        accumulated_time += track_time
        yield cue_sheet_entry


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Creates a cue sheet given a track list.')
    parser.add_argument('audio_file', nargs='+', type=argparse.FileType('r'),
                        default=sys.stdin,
                        help='The audio file corresponding to cue sheet this '
                        'script will generate. This file will be used to infer '
                        'its name for the cue sheet FILE attribute.')
    parser.add_argument('--debug', dest='log_level', default=logging.WARNING,
                        action='store_const', const=logging.DEBUG,
                        help='Print debug log statements.')
    args = parser.parse_args()
    logging.basicConfig(stream=sys.stderr, level=args.log_level)
    logger = logging.getLogger(__name__)

    for file in args.audio_file:
        performer, title = book_info(file.name)
        oga_file = os.path.splitext(file.name)[0] + '.oga'

        if not os.path.isfile(oga_file):
            oga_file = m4b2opus(file.name)

        track_times = []
        names = []
        performers = []
        timebases = []


        for aChap in get_chapters(file.name):
            try:
                names.append(aChap['tags']['title'])
                performers.append(performer)
                track_times.append(
                                datetime.timedelta(
                                    seconds=(int(aChap['end']) - int(aChap['start']))
                                )
                            )
                timebase = int(aChap['time_base'].split('/')[1])
                if timebase > 10000:
                    timebase=1000
                timebases.append(timebase)
            except ValueError as v:
               logger.error(v)


        output_file = open(os.path.splitext(oga_file)[0] + '.cue', "w")
        output_file.writelines('PERFORMER "{}"\n'.format(performer))
        output_file.writelines('TITLE "{}"\n'.format(title))

        audio_file_extension = os.path.splitext(oga_file)[1][1:].upper()
        output_file.writelines('FILE "{}" {}\n'.format(os.path.basename(oga_file), audio_file_extension))

        output_file.writelines(
                '{}\n'.format(cue_entry
            ) for cue_entry in create_cue_sheet(
                        names, track_times, timebases
                    )
        )
