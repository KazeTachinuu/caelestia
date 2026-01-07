#!/bin/bash
hyprctl binds -j | jq -r '
def modname:
  if . == 0 then ""
  elif . == 1 then "Shift"
  elif . == 4 then "Ctrl"
  elif . == 5 then "Ctrl+Shift"
  elif . == 8 then "Alt"
  elif . == 9 then "Alt+Shift"
  elif . == 12 then "Ctrl+Alt"
  elif . == 13 then "Ctrl+Alt+Shift"
  elif . == 64 then "Super"
  elif . == 65 then "Super+Shift"
  elif . == 68 then "Super+Ctrl"
  elif . == 69 then "Super+Ctrl+Shift"
  elif . == 72 then "Super+Alt"
  elif . == 73 then "Super+Alt+Shift"
  elif . == 76 then "Super+Alt+Ctrl"
  else "Mod\(.)"
  end;

.[] | select(.key > "" and (.key | test("^mouse|catchall|XF86") | not) and .description > "") |
"\(.description)|\(.modmask | modname)+\(.key)"
' | column -t -s'|' | sort
