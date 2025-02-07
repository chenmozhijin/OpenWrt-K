# SPDX-FileCopyrightText: Copyright (c) 2024-2025 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import httpx

from .logger import logger


class DownloadError(Exception):
    def __init__(self, msg: str, task: "DLTask") -> None:
        super().__init__(msg)
        self.task = task
        self.msg = msg

    def __str__(self) -> str:
        url = self.task.url
        path = self.task.path
        return f"DownloadError: {self.msg} (url: {url}, path: {path})"

    def __repr__(self) -> str:
        return self.__str__()

class DLTask:
    def __init__(self, url: str, path: str, retry: int, num_chunks: int, headers: dict | None) -> None:
        self.url = url
        self.path = os.path.abspath(path)
        self.retry = retry
        self.num_chunks = num_chunks
        self.headers = headers or {}
        self.error: Exception | None = None
        self.completed = False

        if os.path.exists(self.path):
            os.remove(self.path)
            logger.warning(f"File {self.path} already exists, removed.")

        if not os.path.exists(os.path.dirname(self.path)):
            os.makedirs(os.path.dirname(self.path))
            logger.info(f"Directory {os.path.dirname(self.path)} created.")

        self.thread = threading.Thread(target=self._download)
        self.thread.start()

    def _download(self) -> None:
        try:
            with httpx.Client(headers=self.headers, follow_redirects=True) as client:
                try:
                    # 检查服务器是否支持分片下载
                    resp = client.head(self.url)
                    resp.raise_for_status()
                    accept_ranges = resp.headers.get("Accept-Ranges") == "bytes"
                    content_length = int(resp.headers.get("Content-Length", 0))
                except (httpx.HTTPError, httpx.RequestError):
                    accept_ranges = False
                    content_length = 0

                if accept_ranges and content_length > 0 and self.num_chunks > 1:
                    try:
                        self._download_chunks(client, content_length)
                    except Exception:
                        self._download_whole(client)
                else:
                    self._download_whole(client)
        except Exception as e:
            self.error = e
        finally:
            self.completed = True

    def _download_chunks(self, client: httpx.Client, content_length: int) -> None:
        # 计算块范围
        num_chunks = min(self.num_chunks, content_length)
        chunk_size = content_length // num_chunks
        ranges = [
            (
                i * chunk_size,
                (i + 1) * chunk_size - 1 if i < num_chunks - 1 else content_length - 1,
            )
            for i in range(num_chunks)
        ]

        # 预先分配文件
        with open(self.path, "wb") as f:
            f.truncate(content_length)

        # 并行下载块
        with ThreadPoolExecutor(max_workers=num_chunks) as executor:
            futures = [executor.submit(self._download_chunk, client, start, end) for start, end in ranges]

            for future in as_completed(futures):
                try:
                    data, pos = future.result()
                    self._write_chunk(pos, data)
                except Exception:
                    executor.shutdown(wait=False, cancel_futures=True)
                    raise

    def _download_chunk(self, client: httpx.Client, start: int, end: int) -> tuple[bytes, int]:
        headers = self.headers.copy()
        headers["Range"] = f"bytes={start}-{end}"

        for attempt in range(self.retry + 1):
            try:
                resp = client.get(self.url, headers=headers)
                if resp.status_code == 206:
                    return resp.content, start
                msg = f"Unexpected status code {resp.status_code}"
                self._raise_download_error(httpx.HTTPStatusError(
                    msg,
                    request=resp.request,
                    response=resp,
                ))
            except Exception:
                if attempt == self.retry:
                    raise
                time.sleep(1)
        msg = "Chunk download failed after retries"
        raise DownloadError(msg, self)

    def _write_chunk(self, pos: int, data: bytes) -> None:
        with open(self.path, "r+b") as f:
            f.seek(pos)
            f.write(data)

    def _download_whole(self, client: httpx.Client) -> None:
        for attempt in range(self.retry + 1):
            try:
                with client.stream("GET", self.url, headers=self.headers) as response:
                    response.raise_for_status()
                    with open(self.path, "wb") as f:
                        for chunk in response.iter_bytes():
                            f.write(chunk)
                    return
            except Exception:
                if attempt == self.retry:
                    raise
                time.sleep(1)

    def _raise_download_error(self, e: Exception) -> None:
        raise e

def dl2(
    url: str,
    path: str,
    retry: int = 6,
    num_chunks: int = 4,
    headers: dict | None = None,
) -> DLTask:
    return DLTask(url, path, retry, num_chunks, headers)


def wait_dl_tasks(dl_tasks: list[DLTask]) -> None:
    for task in dl_tasks:
        task.thread.join()

    for task in dl_tasks:
        if task.error is not None:
            raise task.error
