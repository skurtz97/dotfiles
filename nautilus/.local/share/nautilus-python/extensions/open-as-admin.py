"""Nautilus extension: right-click "Open as Administrator".

Opens the selected folder (or current location) via the admin://
GVfs backend, which prompts through polkit. Requires nautilus-python.
Managed by GNU Stow in ~/src/dotfiles/nautilus/.
"""

import subprocess
from urllib.parse import urlparse, unquote

from gi.repository import Nautilus, GObject


def _admin_uri(file_info: Nautilus.FileInfo) -> str:
    path = unquote(urlparse(file_info.get_uri()).path)
    return f"admin://{path}"


class OpenAsAdminExtension(GObject.GObject, Nautilus.MenuProvider):
    def _open(self, _menu, file_info: Nautilus.FileInfo) -> None:
        subprocess.Popen(["nautilus", _admin_uri(file_info)])

    def _make_item(self, file_info, suffix: str) -> Nautilus.MenuItem:
        item = Nautilus.MenuItem(
            name=f"OpenAsAdmin::{suffix}",
            label="Open as Administrator",
        )
        item.connect("activate", self._open, file_info)
        return item

    # Right-click on a selected folder
    def get_file_items(self, files):
        if len(files) != 1:
            return []
        f = files[0]
        if not f.is_directory() or f.get_uri_scheme() != "file":
            return []
        return [self._make_item(f, "selected")]

    # Right-click on empty space in the current folder
    def get_background_items(self, current_folder):
        if current_folder.get_uri_scheme() != "file":
            return []
        return [self._make_item(current_folder, "background")]
