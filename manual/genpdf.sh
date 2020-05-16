#!/bin/bash
#
# Creates the PDF output from LaTeX source
#

lualatex manual-de
echo "Generate toc"
lualatex manual-de
