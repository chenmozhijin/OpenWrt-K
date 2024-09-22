# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
class ConfigError(Exception):
    pass

class ConfigParseError(ConfigError):
    pass

class ConfigNotFoundError(ConfigError):
    pass

class PrePareError(Exception):
    pass