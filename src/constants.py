from pathlib import Path
from loguru import logger
from dotenv import find_dotenv, load_dotenv
import os


HOME_FILE = 'db/home.json'
CONTACT_FILE = 'db/contact.json'
EXPERIENCE_FILE = 'db/experience.json'
PROJECTS_FILE = 'db/projects.json'

load_dotenv(find_dotenv())


def get_data_dir() -> str:
    """Get the directory where the data files are located.

    Returns:
        Path: The path to the data directory.
    """
    # Start with the directory containing this file (constants.py)
    this_file_dir = Path(__file__).parent if '__file__' in globals() else Path.cwd()
    
    # If we can find db/ relative to this file's directory, use it
    if (this_file_dir / 'db').exists():
        return this_file_dir
    
    # Fallback: try current working directory
    cwd = Path.cwd()
    if (cwd / 'db').exists():
        return cwd
    
    # Try src subdirectory from cwd
    if (cwd / 'src' / 'db').exists():
        return cwd / 'src'
    
    # Default to this file's directory
    return this_file_dir


base_path = get_data_dir()

HOME_PATH = base_path / HOME_FILE
CONTACT_PATH = base_path / CONTACT_FILE
EXPERIENCE_PATH = base_path / EXPERIENCE_FILE
PROJECT_PATH = base_path / PROJECTS_FILE

# # Debug info - will show in logs
# logger.debug(f"Current working directory: {os.getcwd()}")
# logger.debug(f"Detected base_path: {base_path}")
# logger.debug(f"PROJECT_PATH: {PROJECT_PATH}")
# logger.debug(f"PROJECT_PATH exists: {PROJECT_PATH.exists()}")

# if base_path.exists():
#     logger.debug(f"Contents of {base_path}: {list(base_path.iterdir())}")
# if (base_path / 'db').exists():
#     logger.debug(f"Contents of db/: {list((base_path / 'db').iterdir())}")


if __name__ == "__main__":
    logger.debug("HOME_PATH:", HOME_PATH)
    logger.debug("CONTACT_PATH:", CONTACT_PATH)
    logger.debug("EXPERIENCE_PATH:", EXPERIENCE_PATH)
    logger.debug("PROJECT_PATH:", PROJECT_PATH)
