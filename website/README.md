# Website for the TX-Pi project

https://www.tx-pi.de/


``webapp.py`` contains the (Flask) application.
The application can be run locally via ``python runwebapp.py``. 

To try out the conversion to a static website, run ``python freezer.py``.
A directory ``build`` is created with static files. In addition,
a file ``_redirects`` with redirect rules will be created.

To use Markdown in templates, use the filter ``{% filter markdown %}Markdown here{% endfilter %}`` 

The file ``images.ini`` contains information about available pre-built 
SD card images. This file is automatically used by the web application
and by the freezer script to create redirect rules.

Commits to the "master" branch should update the website https://www.tx-pi.de/

Work in progress.
