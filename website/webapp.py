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
from flask import Flask, render_template, request, url_for
from flask_misaka import Misaka
from collections import namedtuple
from functools import partial
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
@app.route('/cases/')
@app.route('/images/')
@app.route('/hat/')
@app.route('/electrical/')
@app.route('/software/')
def lang_bridge():
    """\
    Generic paths which redirect to language-specific paths.
    """
    path_de = '/de' + request.path
    path_en = '/en' + request.path
    return '''<!DOCTYPE html>
<html>
  <head>
    <script type="text/javascript">
      var lang = (navigator.language || navigator.userLanguage);
      if (lang && lang.substr(0, 2).toLowerCase() === "de") {
        window.location = "%s"
      }
    </script>
    <meta http-equiv="refresh" content="0; url=%s">
  </head>
</html>
''' % (path_de, path_en)


@app.route('/<lang>/')
def home(lang):
    """\
    Homepage.
    """
    return render_template('home_{0}.html'.format(lang))

@app.route('/<lang>/cases/')
def cases(lang):
    """\
    3d printable case designs.
    """
    return render_template('cases_{0}.html'.format(lang))

@app.route('/<lang>/cases/selection/')
def cases_selection(lang):
    """\
    Case selection helper
    """
    return render_template('cases_selection_{0}.html'.format(lang))

@app.route('/<lang>/cases/pi/pi4/')
def cases_pi4(lang):
    """\
    Case for Pi4
    """
    return render_template('cases_pi4_{0}.html'.format(lang))

@app.route('/<lang>/cases/pi/pi2_pi3/')
def cases_pi2_pi3(lang):
    """\
    Case for Pi2 and Pi3
    """
    return render_template('cases_pi2_pi3_{0}.html'.format(lang))

@app.route('/<lang>/cases/displays/3.2inch/')
def cases_displays_32inch(lang):
    """\
    Case for 3.2" displays
    """
    return render_template('cases_displays_3.2inch_{0}.html'.format(lang))

@app.route('/<lang>/cases/displays/3.5inch/')
def cases_displays_35inch(lang):
    """\
    Case for 3.5" displays
    """
    return render_template('cases_displays_3.5inch_{0}.html'.format(lang))

@app.route('/<lang>/cases/displays/4inch/')
def cases_displays_4inch(lang):
    """\
    Case for 4" displays
    """
    return render_template('cases_displays_4inch_{0}.html'.format(lang))

@app.route('/<lang>/cases/hats/tx-pi-hat/')
def cases_hats_tx_pi_hat(lang):
    return render_template('cases_hats_tx_pi_hat_{0}.html'.format(lang))

@app.route('/<lang>/cases/hats/i2c_pwr/')
def cases_hats_i2c_pwr(lang):
    return render_template('cases_hats_i2c_pwr_{0}.html'.format(lang))

@app.route('/<lang>/cases/hats/CoolerHAT/')
def cases_hats_cooler(lang):
    return render_template('cases_hats_cooler_{0}.html'.format(lang))

@app.route('/<lang>/cases/accessories/clips_stands/')
def cases_accessories_clips_stands(lang):
    return render_template('cases_accessories_clips_stands_{0}.html'.format(lang))

@app.route('/<lang>/cases/accessories/pipower/')
def cases_accessories_pipower(lang):
    return render_template('cases_accessories_pipower_{0}.html'.format(lang))

@app.route('/<lang>/electrical/')
def electrical(lang):
    return render_template('electrical_{0}.html'.format(lang))

@app.route('/<lang>/hat/')
def hat(lang):
    return render_template('hat_{0}.html'.format(lang))

@app.route('/<lang>/software/')
def software(lang):
    return render_template('software_{0}.html'.format(lang))

@app.route('/<lang>/prerequisites/')
def prerequisites(lang):
    return render_template('prerequisites_{0}.html'.format(lang))

@app.route('/<lang>/images/')
def images(lang):
    """\
    Renders a page about the images.
    """
    images = []
    for name, img in TXPI_IMAGES.items():
        img['download_url'] = '/images/latest_{0}'.format(name)
        img['descr'] = img['descr_de'] if lang == 'de' else img['descr_en']
        images.append(img)
    return render_template('images_{0}.html'.format(lang), images=images)


@app.route('/<lang>/installation/')
def installation(lang):
    """\
    Installation hints.
    """
    return render_template('installation_{0}.html'.format(lang),
                           current_os_url='http://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2020-05-28/2020-05-27-raspios-buster-lite-armhf.zip',
                           legacy_os_url='http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/2019-04-08-raspbian-stretch-lite.zip')

MenuItem = namedtuple('MenuItem', ['name', 'url', 'icon'])

@app.context_processor
def inject_defaults():
    """\
    Set some default Jinja variables.
    """
    is_en = not request.path.startswith('/de/')
    main_menu = (MenuItem('Software', 'software', icon='icon-puzzle'),
                 MenuItem('Hardware', 'electrical', icon='icon-install'),
                 MenuItem('Cases' if is_en else 'Gehäuse', 'cases', icon='icon-cube'),
                 MenuItem('Github', _GITHUB_URL, icon='icon-gh'),
                 MenuItem('Deutsch' if is_en else 'English',
                          ('/de/' if is_en else '/en/') + request.path[4:], icon=None))
    language = 'en' if is_en else 'de'
    return { # Variables mainly used for skel.html
            'LANG': language,
            'MAIN_MENU': main_menu,
            # Variables used by image.html
            'RELEASED': 'Released' if is_en else 'Veröffentlicht',
            'CHECKSUM': 'Checksum (MD5)' if is_en else 'Checksumme (MD5)',
            'SIZE': 'Size' if is_en else 'Größe',
            'RASPBIAN_VERSION': 'Raspbian version' if is_en else 'Raspbian Version',
            # Function to simplify links
            'lurl_for': partial(url_for, lang=language)
    }
