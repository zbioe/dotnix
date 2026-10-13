# GTK4 builds that reload ~/.config/gtk-4.0/gtk.css when it changes, so
# libadwaita apps follow `theme` (home/theme) live. Meant for
# replaceDependencies: the patched lib is swapped into existing closures
# instead of rebuilding every GTK4 app against it.
gtk4s:
map (gtk4: {
  oldDependency = gtk4;
  newDependency = gtk4.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./gtk4-reload-user-css.patch ];
  });
}) gtk4s
