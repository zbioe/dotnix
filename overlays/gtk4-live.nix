# GTK4 reloading its gtk.css when it changes, swapped into closures with
# replaceDependencies instead of rebuilding every GTK4 app
gtk4s:
map (gtk4: {
  oldDependency = gtk4;
  newDependency = gtk4.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/gtk4-reload-user-css.patch ];
  });
}) gtk4s
