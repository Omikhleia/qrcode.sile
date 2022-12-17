# qrcode.sile

[![license](https://img.shields.io/github/license/Omikhleia/qrcode.sile?label=License)](LICENSE)
[![Luacheck](https://img.shields.io/github/actions/workflow/status/Omikhleia/qrcode.sile/luacheck.yml?branch=main&label=Luacheck&logo=Lua)](https://github.com/Omikhleia/qrcode.sile/actions?workflow=Luacheck)
[![Luarocks](https://img.shields.io/luarocks/v/Omikhleia/qrcode.sile?label=Luarocks&logo=Lua)](https://luarocks.org/modules/Omikhleia/qrcode.sile)

This package for the [SILE](https://github.com/sile-typesetter/sile) typesetting
system aims at providing QR code support.

It provides the `qrcode` package, which allows printing out a QR code in documents
processed with SILE.

![QR codes](qrcode.png "QR code example")

On a slightly related topic, you might also be interested in the [barcodes.sile](https://github.com/Omikhleia/barcodes.sile) package set.

## Installation

These packages require SILE v0.14 or upper.

Installation relies on the **luarocks** package manager.

To install the latest development version, you may use the provided “rockspec”:

```
luarocks --lua-version 5.4 install --server=https://luarocks.org/dev qrcode.sile
```

(Adapt to your version of Lua, if need be, and refer to the SILE manual for more
detailed 3rd-party package installation information.)

## License

All SILE-related code and samples in this repository are released under the BSD 3-Clause license,
(c) 2022 Omikhleia.

A copy of the [luaqrcode](https://github.com/speedata/luaqrcode) QR code library is
distributed alongside this package.
All corresponding files (in the `lua-libraries` folder) are released under
the BSD 3-Clause license, (c) 2012-2020, Patrick Gundlach (SPEEDATA GMBH) and
contributors.
