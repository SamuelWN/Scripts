#!/usr/bin/env python3.10

import argparse
import datetime
import logging
import sys
from pathlib import Path
from typing import List, Optional, Tuple

# Requires:
# ffmpeg-python
import ffmpeg
from ffmpeg import Error as FFmpegError

# Configure logging
logging.basicConfig(stream=sys.stderr, level=logging.WARNING)
logger = logging.getLogger(__name__)


def main():
    """Main entry point for the m4b2oga conversion tool."""
    args = parse_arguments()
    configure_logging(args.log_level)

    for input_file in args.audio_files:
        process_audio_file(input_file.name)


def process_audio_file(input_path: str) -> None:
    """
    Process a single audio file through the conversion pipeline.
    
    Calls child-functions to process the file:
        1. `convert_to_opus`
        2. `extract_cover_art`
        3. `extract_description_to_file`
        4. `generate_cue_sheet`

    Args:
        input_path: Original audio file (`m4b`)
    """
    try:
        base_path = Path(input_path)
        oga_path = base_path.with_suffix('.oga')
        cue_path = base_path.with_suffix('.cue')

        if not oga_path.exists():
            convert_to_opus(input_path, oga_path)

        extract_cover_art(base_path)
        extract_description_to_file(base_path)
        generate_cue_sheet(input_path, oga_path, cue_path)

    except FFmpegError as e:
        logger.error(f"FFmpeg error processing {input_path}: {e.stderr.decode()}")
    except Exception as e:
        logger.error(f"Error processing {input_path}: {str(e)}", exc_info=True)


def convert_to_opus(input_path: str, output_path: Path) -> None:
    """Convert input file to Opus format using FFmpeg."""
    (
        ffmpeg.input(input_path)
        .output(str(output_path),
                acodec='libopus',
                audio_bitrate='48k',
                map_metadata=0)
        .overwrite_output()
        .run()
    )


def get_metadata(file_path: str) -> Tuple[str, str]:
    """Extract performer and title metadata from audio file."""
    try:
        tags = ffmpeg.probe(file_path)['format']['tags']
        tag_map = {k.lower(): v for k, v in tags.items()}

        performer = tag_map.get('artist') or tag_map.get('performer') or ''
        title = tag_map.get('album') or tag_map.get('title') or Path(file_path).stem

        return performer, title
    except KeyError:
        return '', Path(file_path).stem


def get_chapters(file_path: str) -> List[dict]:
    """Retrieve chapters from media file."""
    try:
        return ffmpeg.probe(file_path, show_chapters=None).get('chapters', [])
    except FFmpegError:
        return []


def should_regenerate_cue(cue_path: Path, oga_path: Path) -> Tuple[bool, Path]:
    """
    Determine if we need to generate a new CUE file and which path to use.
    
    Returns:
        Tuple of (should_regenerate: bool, target_cue_path: Path)
    """
    target_path = cue_path
    regenerate = True
    oga_filename = oga_path.name
    
    if not oga_path.exists():
        logger.warning(f"OGA file not found at {oga_path}, forcing regeneration")
        return True, target_path

    try:
        if cue_path.exists():
            with cue_path.open('r') as f:
                cue_content = f.read()
                
                # Check if existing CUE is associated with OGA file
                if f'FILE "{oga_filename}" OGA' not in cue_content:
                    # Create new CUE path for OGA version
                    target_path = cue_path.with_stem(f"{cue_path.stem}_oga")
                    logger.debug(f"Creating new CUE path: {target_path}")
                    
                    # Only regenerate if target doesn't exist
                    regenerate = not target_path.exists()
                # else:
                #     # Check if existing CUE needs update
                #     source_mtime = oga_path.stat().st_mtime
                #     cue_mtime = cue_path.stat().st_mtime
                #     regenerate = cue_mtime < source_mtime

        return regenerate, target_path
    except FileNotFoundError:
        logger.debug("Missing file during CUE check, forcing regeneration")
        return True, target_path


def generate_cue_sheet(m4b_path: str, oga_path: Path, cue_path: Path) -> None:
    """Generate or update CUE sheet for the converted audio file."""
    performer, title = get_metadata(m4b_path)
    chapters = get_chapters(m4b_path)

    # Ensure OGA file exists before proceeding
    if not oga_path.exists():
        raise FileNotFoundError(f"OGA file not found at {oga_path}")

    regenerate, target_cue_path = should_regenerate_cue(cue_path, oga_path)
    
    if regenerate:
        cue_content = build_cue_content(performer, title, oga_path.name, chapters)
        write_cue_file(target_cue_path, cue_content)
        logger.info(f"Generated CUE sheet at {target_cue_path}")
    else:
        logger.info(f"Using existing CUE sheet at {target_cue_path}")


def build_cue_content(performer: str, title: str, oga_filename: str, chapters: List[dict]) -> str:
    """Construct CUE sheet content from metadata and chapters."""
    cue_lines = [
        f'PERFORMER "{performer}"',
        f'TITLE "{title}"',
        f'FILE "{oga_filename}" OGA'
    ]

    for idx, chapter in enumerate(chapters, start=1):
        start_time = datetime.timedelta(seconds=float(chapter['start_time']))
        cue_lines.extend(format_cue_entry(idx, chapter['tags']['title'], start_time))

    return '\n'.join(cue_lines) + '\n'


def format_cue_entry(track_number: int, title: str, start_time: datetime.timedelta) -> List[str]:
    """Format individual CUE track entry."""
    total_seconds = start_time.total_seconds()
    minutes = int(total_seconds // 60)
    seconds = int(total_seconds % 60)
    frames = int((total_seconds - int(total_seconds)) * 75)

    return [
        f'  TRACK {track_number:02} AUDIO',
        f'    TITLE "{title}"',
        f'    INDEX 01 {minutes:02}:{seconds:02}:{frames:02}'
    ]


def write_cue_file(cue_path: Path, content: str) -> None:
    """Write CUE content to file with proper error handling."""
    try:
        cue_path.parent.mkdir(parents=True, exist_ok=True)
        with cue_path.open('w') as f:
            f.write(content)
    except IOError as e:
        logger.error(f"Failed to write CUE file: {str(e)}")


def extract_cover_art(base_path: Path) -> Optional[Path]:
    """Extract embedded cover art from audio file."""

    cover_path = base_path.with_name('cover.jpg')
    
    # If "cover.jpg" already exists:
    if cover_path.exists():
        # Remove the extension and append "_cover.jpg"
        cover_path = base_path.with_stem(base_path.stem + "_cover").with_suffix(".jpg")
    
    try:
        (
            ffmpeg.input(base_path.absolute())
            .output(str(cover_path), map='0:v', vframes=1)
            .overwrite_output()
            .run(quiet=True)
        )
        return cover_path if cover_path.exists() else None
    except FFmpegError:
        return None


def extract_description_to_file(base_path: Path) -> Optional[Path]:
    """Extract description metadata to text file."""
    
    info_path = base_path.with_name('info.txt')
    
    # If `info.txt` already exists: 
    if info_path.exists():
        # Remove the extension and append "_info.txt"
        info_path = base_path.with_stem(base_path.stem + "_info").with_suffix(".txt")
    
    description_fields = ['description', 'comment', 'synopsis', 'summary']

    try:
        tags = ffmpeg.probe(base_path.absolute())['format']['tags']
        content = next((tags[k] for k in tags if k.lower() in description_fields), None)
        
        if content:
            info_path.write_text(content)
            return info_path
    except Exception:
        return None


def parse_arguments():
    """Configure and parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Convert M4B audiobooks to Opus format with CUE chapters'
    )
    parser.add_argument('audio_files', nargs='+', type=argparse.FileType('r'),
                       help='Input M4B file(s) to process')
    parser.add_argument('--debug', dest='log_level', action='store_const',
                       const=logging.DEBUG, default=logging.WARNING)
    return parser.parse_args()


def configure_logging(level: int) -> None:
    """Configure logging subsystem."""
    logger.setLevel(level)
    ffmpeg_logger = logging.getLogger('ffmpeg')
    ffmpeg_logger.setLevel(logging.WARNING if level == logging.DEBUG else logging.ERROR)


if __name__ == '__main__':
    main()
