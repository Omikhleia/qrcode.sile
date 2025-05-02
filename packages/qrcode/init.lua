--
-- QR codes for SILE.
--
-- License: GPL-3.0-or-later
--
-- Copyright (C) 2022, 2025 Didier Willis
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--
local qrencode = require("qrencode")

local PathRenderer = require("grail.renderer")
local Color = require("grail.color")
local PRNG = require("prng-prigarin")
local prng = PRNG()

local base = require("packages.base")

local package = pl.class(base)
package._name = "qrcode"

function package:_init (_)
  base._init(self)
end

-- We are just providing one hard-code color theme.
-- It is hard to ensure that any color scheme will be readable by all QR code scanners.
-- Toying whith HSL is also a neat trick, but not guaranteed to always work with any color scheme.
local COLORS = {
  "darkblue",  -- 1 normal black cell
  "#0d4944",   -- 2 outer detection block cells
  "darkgreen", -- 3 inner detection block cells
  "purple",    -- 4 version and information cells, and a cell top left of the bottom detection block
  "#093330"    -- 5 alignment cells
}

local function colorFn (h, s, l, factorAroundLightness)
  local newL = l + (1 - l) * factorAroundLightness
  return Color.fromHsl(h, s, newL)
end
local function computeColor (cell)
  local color = COLORS[cell] or "red" -- Red should not occur
  color = Color(color)
  if cell ~= 4 then
    local H, S, L = color:toHsl()
    local s = prng:random() * 0.25
    color = colorFn(H, S, L, s)
  end
  return color
end

function package:registerCommands ()
  self:registerCommand("qrcode", function (options, _)
    local text = SU.required(options, "code", "valid text string")
    local colored = SU.boolean(options.colored, false)
    local dotted = SU.boolean(options.dotted, false)
    local ec = SU.cast("integer", options.ec or "2") -- LMQH(1..4), default M(2)
    if ec < 1 or ec > 4 then
      SU.error("QR code invalid error correction level")
    end
    local ok, tab_or_message = qrencode.qrcode(text, ec)
    if not ok then
      SU.error("QR code encoding error: ", tab_or_message)
    end
    local width
    local X
    -- GS1 and ISO 18004 recommend an X module between 0.5mm and 1.25mm for print material.
    -- They also recommend a safety zone of 4X around all the four faces of the QR code.
    local safeZone = SU.boolean(options.safezone, true) and 4 or 0
    if options.width then
      width = SU.cast("measurement", options.width)
      X = width / (#tab_or_message + 2 * safeZone)
      if X < SILE.types.measurement("0.5mm") then
        SU.warn("QR code width is too small (minimum recommended module of 0.5mm is not satisfied)")
      end
      if options.module then
        SU.warn("QR code width takes precedence of module option (ignored)")
      end
    else
      X = SU.cast("measurement", options.module or "0.5mm")
      if X < SILE.types.measurement("0.5mm") then
        SU.warn("QR code module is too small (minimum recommended module of 0.5mm is not satisfied)")
      end
      width = X * (#tab_or_message + 2 * safeZone)
    end
    local logo = options.logo
    if logo then
      logo = SILE.resolveFile(logo) or SU.error("QR code logo file not found: ", logo)
    end
    local logoMin
    local logoMax
    if logo then
      -- The logo should not destroy more the QR code.
      -- This is a bit empirical, but we can use the error recovery capacity of the QR code
      -- and determine a decent size for the logo.
      -- The minimal error recovery is around 7% in Low mode (1), so we pick a size
      -- that is around 6.5% of the QR code (and we lose most of the error recovery).
      -- For other modes, we pick a size that is around 7% of the QR code, to ensure
      -- the error recovery is not too much affected and the logo is not too big.
      -- Note: Some other implementations go up to using 10% of the QR code size.
      -- I sometimes had troubles scanning them, so I prefer to be conservative here.
      local logoSz = #tab_or_message * math.sqrt(ec == 1 and 0.065 or 0.07)
      logoMin = math.ceil(#tab_or_message / 2 - logoSz / 2)
      logoMax = math.floor(#tab_or_message / 2 + logoSz / 2)
    end

    SILE.typesetter:pushHbox({
      width = SILE.types.length(width),
      height = SILE.types.length(width - safeZone * X),
      depth = SILE.types.length(safeZone * X),
      outputYourself = function(node, typesetter, line)
        local X0 = typesetter.frame.state.cursorX
        local Y0 = typesetter.frame.state.cursorY
        local w = node:scaledWidth(line):tonumber()
        typesetter.frame:advanceWritingDirection(w)

        -- N.B. This is probably wrong for RTL or BTT writing directions!

        local Xn = w / (#tab_or_message + 2 * safeZone)
        local painter = PathRenderer()
        for i, col in ipairs(tab_or_message) do
          for j, cell in ipairs(col) do
            if logo and i > logoMin and i <= logoMax and j > logoMin and j <= logoMax then -- luacheck: ignore 542
              -- We reserve an empty square for the logo
            elseif cell > 0 then -- "Black" cell
              local color = colored and computeColor(cell) or nil
              if dotted then
                local path
                if cell == 2 or cell == 3 then
                  -- We keep squares for detection blocks
                  path = painter:rectangle(0, Xn, Xn*0.9, Xn*0.9, {
                    fill = color,
                    stroke = "none",
                  })
                else
                  -- Small cheat: True circles are intensive to compute from bezier curves.
                  -- We use a rounded rectangle instead, which is simpler, and even ensure it is slightly
                  -- square, for better detection.
                  path = painter:roundedRectangle(0, Xn, Xn*0.90, Xn*0.90, Xn*0.45, Xn*0.45, {
                    fill = color,
                    strokeWidth = Xn * 0.05,
                  })
                end
                SILE.outputter:drawSVG(path,
                                       X0 + (safeZone + i-1) * Xn,
                                       Y0 - node.height:tonumber() + (safeZone + j-1) * Xn,
                                       Xn,
                                       Xn, 1)
              else
                local path = painter:rectangle(0, Xn, Xn, Xn, {
                  fill = color,
                  strokeWidth = Xn * 0.1,
                })
                SILE.outputter:drawSVG(path,
                                       X0 + (safeZone + i-1) * Xn,
                                       Y0 - node.height:tonumber() + (safeZone + j-1) * Xn,
                                       Xn,
                                       Xn, 1)
              end
            end
          end
        end
        if logo then
          SILE.outputter:drawImage(
            logo,
            X0 + (safeZone + logoMin) * Xn,
            Y0 - node.height:tonumber() + (safeZone + logoMin) * Xn,
            Xn * (logoMax - logoMin),
            Xn * (logoMax - logoMin),
            1
          )
        end
      end
    })
  end)
end

package.documentation = [[
\begin{document}
\use[module=packages.qrcode]

The \autodoc:package{qrcode} package allows to print out a QR code.

The \autodoc:command{\qrcode} command takes a mandatory \autodoc:parameter{code} parameter, the (numeric or alphanumeric) text content to represent as a QR code.

By default, it uses a “module” (pixel size) of 0.5mm. The GS1 recommendations for printed QR codes intended to be scanned by smartphones is for the module to be between 0.5 and 1.25mm.

This size can be changed by setting either the \autodoc:parameter{module} option to the requested measurement value, or the \autodoc:parameter{width} option to define the total requested width of the QR code (in which case, obviously, the corresponding module is deduced).
The command issues a warning if the module is below 0.5mm.

By default again, a recommended safety zone of four modules is recommended by GS1 around all faces of the code. You can disable that safety area by specifying the \autodoc:parameter{safezone=false} option.

QR codes include an error correction capacity, so that they might be deciphered even when damaged or partly obscured.
GS1 recommends using at least the “medium” error correction level (approx. 15\% of recovery capacity), which is therefore enabled by default.
You can change the error correction level by setting the \autodoc:parameter{ec=<level>} option to 1 (“low”), 2 (“medium”), 3 (“quartil”) or 4 (“high”), respectively leading to a 7\%, 15\%, 25\% or 30\% recovery capacity.

Here is this package in action \qrcode[code=http://github.com/Omikhleia/qrcode.sile/] with default settings.

\qrcode[code=http://github.com/Omikhleia/qrcode.sile/, safezone=false, ec=4, module=0.75mm]

This QR code has the same content but is rendered here without safety area, a larger module and a higher error correction level.
Now, here is something fancier, with the \autodoc:parameter{dotted=true} and \autodoc:parameter{colored=true} options.
We kept the safety area on, so that each QR code is well separated from the others.
Such QR codes are not recommended for printed material at small size, but they are still readable by most scanners.
They are more suitable in big-sized posters.
In colored mode, the colors are slightly randomized so each cell is different from the others, but the color scheme is still consistent.

\noindent\qrcode[code=http://github.com/Omikhleia/qrcode.sile/, width=33%lw, dotted=true]\qrcode[code=http://github.com/Omikhleia/qrcode.sile/, width=33%lw, colored=true]\qrcode[code=http://github.com/Omikhleia/qrcode.sile/, width=33%lw, dotted=true, colored=true]

The \autodoc:parameter{logo} option allows to add an image in the center of the QR code, scaled in a square.
Obviously, the image should already have a square aspect ratio, or it will be distorted.
Its size is automatically computed so that it does not destroy the QR code and the image is not too big.
Some of the error recovery capacity is lost in the process.
You should therefore always verify that the QR code is still readable by scanning it with a smartphone or a QR code reader.

\end{document}]]

return package
