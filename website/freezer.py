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
Freezes the TX-Pi web application.
"""
import os
from flask_frozen import Freezer
from webapp import app, TXPI_IMAGES

# Treat redirects as error since the Flask test client cannot handle
# external URIs anyway
app.config['FREEZER_REDIRECT_POLICY'] = 'error'

_REDIRECTS = {
    '/tx-pi-setup.sh': 'https://raw.githubusercontent.com/ftCommunity/tx-pi/master/setup/tx-pi-setup.sh',
    '/unstable/tx-pi-setup.sh': 'https://raw.githubusercontent.com/ftCommunity/tx-pi/develop/setup/tx-pi-setup.sh',
}

# Generate redirect rules for the TX-Pi images
for img_name in TXPI_IMAGES:
    _REDIRECTS['/images/latest_{0}'.format(img_name)] = TXPI_IMAGES[img_name]['url']

freezer = Freezer(app)


@freezer.register_generator
def all_routes():
    """\
    Generator which yields all paths with no arguments available in the app.

    This generator yields routes which wouldn't be available since
    they are not linked by url_for.

    Additionally, it may yield available paths but it does no harm if a
    route / path is reported multiple times.

    Simplifies website freezing.
    """
    def has_no_params(rule):
        defaults = rule.defaults if rule.defaults is not None else ()
        arguments = rule.arguments if rule.arguments is not None else ()
        return len(defaults) >= len(arguments)

    for path in (str(r) for r in app.url_map.iter_rules() if has_no_params(r)):
        yield path
        for lang in ('de', 'en'):
            yield '/{}{}'.format(lang, path)


if __name__ == '__main__':
    freezer.freeze()
    with open(os.path.join(freezer.root, '_redirects'), 'w') as f:
        for src, target in _REDIRECTS.items():
            f.write('{0}    {1}    302\n'.format(src, target))
