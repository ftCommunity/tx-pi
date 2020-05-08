# -*- coding: utf-8 -*-
#
# TX-Pi website.
#
# To the extent possible under law, the author(s) have dedicated all copyright
# and related and neighboring rights to this software to the public domain
# worldwide. This software is distributed without any warranty.
# You should have received a copy of the CC0 Public Domain Dedication along
# with this software.
#
# If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
#
"""\
TX-Pi website.

This is meant to generate static pages, do not run this app on a public server,
user inputs are not checked.
"""
import os
import uuid
from flask import Flask, render_template, request
from flask_misaka import Misaka
import jinja2

app = Flask(__name__)
Misaka(app)

# Strictly, the secret key isn't needed for our purposes (mainly used for session management)
# Generate a random key anyway.
app.config['SECRET_KEY'] = str(uuid.uuid4()).encode('utf-8')

# Let template rendering fail if Jinja encounters undefined variables
app.jinja_env.undefined = jinja2.StrictUndefined

# Available TX-Pi images
import configparser
import json
TXPI_IMAGES = configparser.ConfigParser()
TXPI_IMAGES.read(os.path.join(os.path.dirname(__file__), 'images.ini'))
# Convert to dict for an easier access
TXPI_IMAGES = json.loads(json.dumps(TXPI_IMAGES._sections))
del configparser
del json

_GITHUB_URL = 'https://github.com/ftCommunity/tx-pi'


@app.route('/')
def index():
    """\
    The root page.
    """
    return '''<!DOCTYPE html>
<html>
  <head>
    <script type="text/javascript">
      var lang = (navigator.language || navigator.userLanguage);
      if (lang && lang.substr(0, 2).toLowerCase() === "de") {
        window.location = "/de/"
      }
    </script>
    <meta http-equiv="refresh" content="0; url=/en/">
  </head>
</html>
'''


@app.route('/images/')
def images_root():
    """\
    Handle /images/ and redirect to /en/images/ or /de/images/
    """
    return '''<!DOCTYPE html>
<html>
  <head>
    <script type="text/javascript">
      var lang = (navigator.language || navigator.userLanguage);
      if (lang && lang.substr(0, 2).toLowerCase() === "de") {
        window.location = "/de/images/"
      }
    </script>
    <meta http-equiv="refresh" content="0; url=/en/images/">
  </head>
</html>
'''


@app.route('/<lang>/')
def home(lang):
    """\
    Homepage.
    """
    return render_template('home_{0}.html'.format(lang))


@app.route('/<lang>/images/')
def images(lang):
    """\
    Renders a page about the images.
    """
    images = TXPI_IMAGES
    return render_template('images_{0}.html'.format(lang), images=images)


@app.route('/<lang>/installation/')
def installation(lang):
    """\
    Installation hints.
    """
    return render_template('installation_{0}.html'.format(lang))


_MAIN_MENU = (
    ('Installation', 'installation'),
    ('Images', 'images'),
    ('Github', _GITHUB_URL),
)

@app.context_processor
def inject_defaults():
    """\
    Set some default Jinja variables.
    """
    is_en = not request.path.startswith('/de/')
    # Create a (modifiable) copy of the _MAIN_MENU
    main_menu = list(_MAIN_MENU)
    main_menu.append(('Deutsch', '/de/') if is_en else ('English', '/en/'))
    # Uses upper case names to distinguish them from variables set by the endpoints
    return { # Variables mainly used for skel.html
            'LANG': 'en' if is_en else 'de',
            'MAIN_MENU': main_menu,
            # Variables used by image.html
            'RELEASED': 'Released' if is_en else 'Veröffentlicht',
            'CHECKSUM': 'Checksum (MD5)' if is_en else 'Checksumme (MD5)',
            'SIZE': 'Size' if is_en else 'Größe',
    }
