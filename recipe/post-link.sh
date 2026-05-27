#!/bin/bash
# Compile the GSettings schemas for the environment.
#
# Coot is a GTK4 application and aborts at start up with
#   GLib-GIO-ERROR **: No GSettings schemas are installed on the system
# (a fatal g_error -> SIGABRT) when
# share/glib-2.0/schemas/gschemas.compiled is absent.
#
# gtk4 ships a post-link that is meant to generate this cache, but not
# every gtk4 build packages it (e.g. gtk4-4.22.4-h879dcaf_3 does not),
# so the cache can be missing after a plain `conda create ... coot`.
# coot is the leaf package, linked after gtk4, so running it here picks
# up every installed schema.  Failures are non-fatal so a bad schema in
# the environment can't block installation of coot.
if [ -x "${PREFIX}/bin/glib-compile-schemas" ] && [ -d "${PREFIX}/share/glib-2.0/schemas" ]; then
    "${PREFIX}/bin/glib-compile-schemas" "${PREFIX}/share/glib-2.0/schemas" || true
fi
