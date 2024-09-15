# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
from actions_toolkit import core
from actions_toolkit.github import Context, get_octokit
from github.Repository import Repository

from .logger import logger
from .network import dl2, wait_dl_tasks

context = Context()

def get_repo() -> Repository:
    token = core.get_input('Token')
    octokit = get_octokit(token)

    user_repo = f'{context.repo.owner}/{context.repo.repo}'
    return octokit.rest.get_repo(user_repo)

repo = get_repo()


def dl_artifact(name: str, path: str) -> str:
    for artifact in repo.get_artifacts():
        if artifact.workflow_run.id == context.run_id and artifact.name == name:
            dl_url = artifact.archive_download_url
            logger.info(f'Downloading artifact {name} from {dl_url}')
            break
    else:
        msg = f'Artifact {name} not found'
        raise ValueError(msg)

    dl = dl2(dl_url, path)
    wait_dl_tasks([dl])
    return dl.get_dest()
