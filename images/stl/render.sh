#!/bin/bash
# for i in *.stl ; do ./render.sh $i ; done
blender -b ~/bin/ft.blend -P ~/bin/viz.py -- $1 ${1%.stl}.png
convert ${1%.stl}.png -fuzz 35% -trim +repage ${1%.stl}.png
