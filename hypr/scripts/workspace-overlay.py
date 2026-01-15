#!/usr/bin/env python3
"""
Workspace Overlay
Shows active workspace number on each monitor with fade animation.
Single instance enforced via lock file.
"""

import contextlib
import fcntl
import json
import os
import signal
import subprocess
import sys
import warnings
from pathlib import Path

import gi
gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
warnings.filterwarnings("ignore", category=DeprecationWarning)

from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

# Config
HOLD_MS = 1500
FADE_STEP = 0.1
FRAME_MS = 16
MARGIN = (80, 40)  # top, right

LOCK_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "workspace-overlay.lock"

STYLE = b"""
label {
    background: rgba(17, 17, 27, 0.85);
    color: rgba(205, 214, 244, 0.95);
    font: 500 64px Rubik;
    border-radius: 20px;
    padding: 14px 36px;
    border: 1px solid rgba(255, 255, 255, 0.08);
}
"""


class Overlay(Gtk.Window):
    def __init__(self, text: str, monitor: Gdk.Monitor | None = None):
        super().__init__()
        self._opacity = 0.0
        self._setup(monitor, text)

    def _setup(self, monitor: Gdk.Monitor | None, text: str):
        self.set_app_paintable(True)
        self.set_decorated(False)
        if visual := self.get_screen().get_rgba_visual():
            self.set_visual(visual)

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_exclusive_zone(self, -1)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, MARGIN[0])
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, MARGIN[1])
        if monitor:
            GtkLayerShell.set_monitor(self, monitor)

        self.add(Gtk.Label(label=text))

    def run(self):
        self.show_all()
        self.set_opacity(0)
        self._fade(1)

    def _fade(self, direction: int):
        self._opacity = max(0, min(1, self._opacity + direction * FADE_STEP))
        self.set_opacity(self._opacity)

        if 0 < self._opacity < 1:
            GLib.timeout_add(FRAME_MS, self._fade, direction)
        elif direction > 0:
            GLib.timeout_add(HOLD_MS, self._fade, -1)
        else:
            self.destroy()


@contextlib.contextmanager
def lock():
    try:
        fd = os.open(str(LOCK_FILE), os.O_CREAT | os.O_RDWR)
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (OSError, BlockingIOError):
        sys.exit(0)
    try:
        yield
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)
        LOCK_FILE.unlink(missing_ok=True)


def get_monitors() -> list[dict]:
    r = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 else []


def find_gdk_monitor(display: Gdk.Display, desc: str) -> Gdk.Monitor | None:
    for i in range(display.get_n_monitors()):
        if (m := display.get_monitor(i)).get_model() in desc:
            return m
    return None


def main():
    with lock():
        monitors = get_monitors()
        if not monitors:
            sys.exit(1)

        signal.signal(signal.SIGTERM, lambda *_: Gtk.main_quit())
        signal.signal(signal.SIGINT, lambda *_: Gtk.main_quit())

        css = Gtk.CssProvider()
        css.load_from_data(STYLE)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        display = Gdk.Display.get_default()
        for mon in monitors:
            Overlay(
                str(mon["activeWorkspace"]["id"]),
                find_gdk_monitor(display, mon["description"]),
            ).run()

        GLib.timeout_add(HOLD_MS + 500, Gtk.main_quit)
        Gtk.main()


if __name__ == "__main__":
    main()
