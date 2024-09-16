# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os

from actions_toolkit.github import Context, get_octokit

from .logger import logger
from .network import dl2, gh_api_request, wait_dl_tasks

context = Context()
user_repo = f'{context.repo.owner}/{context.repo.repo}'

try:
    token = os.getenv('GITHUB_TOKEN')
    repo = get_octokit(token).rest.get_repo(user_repo)
except Exception:
    pass

compiler = context.repo.owner
if user_info := gh_api_request(f"https://api.github.com/users/{compiler}"):
    compiler = user_info.get("name", compiler)
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

def del_cache(key_prefix: str) -> None:
    if response := gh_api_request(f"https://api.github.com/repos/{user_repo}/actions/caches"):
        for cache in response["actions_caches"]:
            cache: dict
            if cache['key'].startswith(key_prefix):
                logger.info(f'Deleting cache {cache["key"]}')
                gh_api_request(f"https://api.github.com/repos/{user_repo}/actions/caches/{cache['id']}")
    else:
        logger.error('Failed to get caches list')