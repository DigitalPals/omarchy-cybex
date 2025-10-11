#!/bin/bash

if pgrep -x hypridle >/dev/null; then
  echo '{"text": "\uf204", "tooltip": "Computer will idle and lock when inactive", "class": "off"}'
else
  echo '{"text": "\uf205", "tooltip": "Computer will stay active", "class": "on"}'
fi
