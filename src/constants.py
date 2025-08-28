from pathlib import Path
from dotenv import find_dotenv, load_dotenv

# This can be edited if other names are used
HOME_FILE = 'db/home.json'
CONTACT_FILE = 'db/contact.json'
EXPERIENCE_FILE = 'db/experience.json'
PROJECTS_FILE = 'db/projects.json'
# SERVICES_FILE = 'db/services.json'


# Do no edit anything below
current_file_path = Path(__file__).parent

load_dotenv(load_dotenv())

HOME_PATH = current_file_path.joinpath(f'{current_file_path}/{HOME_FILE}')
CONTACT_PATH = current_file_path.joinpath(f'{current_file_path}/{CONTACT_FILE}')
EXPERIENCE_PATH = current_file_path.joinpath(f'{current_file_path}/{EXPERIENCE_FILE}')
PROJECT_PATH = current_file_path.joinpath(f'{current_file_path}/{PROJECTS_FILE}')
# SERVICES_PATH = current_file_path.joinpath(f'{current_file_path}/{SERVICES_FILE}')


if __name__ == "__main__":

    print("HOME_PATH:", HOME_PATH)
    print("CONTACT_PATH:", CONTACT_PATH)
    print("EXPERIENCE_PATH:", EXPERIENCE_PATH)
    print("PROJECT_PATH:", PROJECT_PATH)
