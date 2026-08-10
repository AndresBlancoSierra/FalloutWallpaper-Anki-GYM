#!/bin/bash
# Toggle interactividad del wallpaper de Fallout (hyprwinwrap).
# En modo fondo los clics pasan de largo; en modo interactivo se puede
# hacer clic en la página (+1/-1). Clic en otra ventana lo devuelve al fondo.
hyprctl dispatch hyprwinwrap_interactivity
