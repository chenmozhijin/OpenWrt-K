# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os

import yaml

from .paths import paths


class UpLoader:
    def __init__(self) -> None:
        self.action_file = os.path.join(paths.openwrt_k, ".github", "action", "upload", "action.yml")
        with open(self.action_file, encoding='utf-8') as file:
            self.action = yaml.load(file, Loader=yaml.FullLoader)  # noqa: S506
        self.action['runs']['steps'] = []

    def add(self,
            name: str,
            path: str | list[str],
            if_no_files_found: str | None = None,
            retention_days: int | None = None,
            compression_level: int | None = None,
            overwrite: bool | None = None,
            include_hidden_files: bool | None = None) -> None:
        if isinstance(path, list):
            path = "\n".join(path)
        action = {
            "name": name,
            "uses": "actions/upload-artifact@v4",
            "with": {
                "name": name,
                "path": path,
            },
        }
        if if_no_files_found is not None:
            action["with"]['if-no-files-found'] = if_no_files_found
        if retention_days is not None:
            action["with"]['retention-days'] = retention_days
        if compression_level is not None:
            action["with"]['compression-level'] = compression_level
        if overwrite is not None:
            action["with"]['overwrite'] = overwrite
        if include_hidden_files is not None:
            action["with"]['include-hidden-files'] = include_hidden_files
        self.action['runs']['steps'].append(action)

    def save(self) -> None:
        if self.action['runs']['steps']:
            with open(self.action_file, 'w', encoding='utf-8') as file:
                yaml.dump(self.action, file, allow_unicode=True, sort_keys=False)

uploader = UpLoader()
