--
-- QR codes for SILE.
-- Didier Willis, 2022.
-- License: BSD 3-Clause
--
local qrencode = require("qrencode")
local base = require("packages.base")

local package = pl.class(base)
package._name = "qrcode"

function package:_init (_)
  base._init(self)
end

function package:registerCommands ()
  self:registerCommand("qrcode", function (options, _)
    local text = SU.required(options, "code", "valid text string")
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
      if X < SILE.measurement("0.5mm") then
        SU.warn("QR code width is too small (minimum recommended module of 0.5mm is not satisfied)")
      end
      if options.module then
        SU.warn("QR code width takes precedence of module option (ignored)")
      end
    else
      X = SU.cast("measurement", options.module or "0.5mm")
      if X < SILE.measurement("0.5mm") then
        SU.warn("QR code width is too small (minimum recommended module of 0.5mm is not satisfied)")
      end
      width = X * (#tab_or_message + 8)
    end

    SILE.typesetter:pushHbox({
      width = SILE.length(width),
      height = SILE.length(width - safeZone * X),
      depth = SILE.length(safeZone * X),
      outputYourself = function(node, typesetter, line)
        local X0 = typesetter.frame.state.cursorX
        local Y0 = typesetter.frame.state.cursorY
        local w = node:scaledWidth(line):tonumber()
        typesetter.frame:advanceWritingDirection(w)

        -- N.B. This is probably wrong for RTL or BTT writing directions!

        local h = node.height:tonumber()
        local d = node.depth:tonumber()
        local Xn = w / (#tab_or_message + 2 * safeZone)
        for i, col in ipairs(tab_or_message) do
          for j, row in ipairs(col) do
            if row > 0 then -- Black cell
              SILE.outputter:drawRule(X0 + (safeZone + i-1) * Xn,
                                      Y0 - node.height:tonumber() + (safeZone + j-1) * Xn,
                                      Xn,
                                      Xn)
            end
          end
        end
        -- Output a border
        -- COMMENTED OUT: That was for debug, and I am not sure this is a needed option
        -- There are better solutions for framing things.
        -- NOTE: Drawn inside the box, so borders slightly overlap with inner content.
        -- This should be negligible compared to the safeZone
        -- local thickness = 0.5
        -- SILE.outputter:drawRule(X0, Y0 + d - thickness, w, thickness)
        -- SILE.outputter:drawRule(X0, Y0 - h, w, thickness)
        -- SILE.outputter:drawRule(X0, Y0 - h, thickness, h + d)
        -- SILE.outputter:drawRule(X0 + w - thickness, Y0 - h, thickness, h + d)
      end
    })
  end)
end

package.documentation = [[
\begin{document}
\use[module=packages.qrcode]

The \autodoc:package{qrcode} package allows to print out a QR code.

The \autodoc:command{\qrcode} command takes a mandatory \autodoc:parameter{code} parameter,
the (numeric or alphanumeric) text content to represent as a QR code.

By default, it uses a “module” (pixel size) of 0.5mm. The GS1 recommendations
for printed QR codes intended to be scanned by smartphones is for the module
to be between 0.5 and 1.25mm.

This size can be changed by setting either the \autodoc:parameter{module} option to the
requested measurement value, or the \autodoc:parameter{width} option to define the
total requested width of the QR code (in which case, obviously, the corresponding
module is deduced). The command issues a warning if the module is below 0.5mm.

By default again, a recommended safety zone of four modules is recommended by GS1
around all faces of the code. You can disable that safety area by specifying
the \autodoc:parameter{safezone=false} option.

QR codes include an error correction capacity, so that they might be deciphered
even when damaged or partly obscured. GS1 recommends at least the “medium”
error correction level (approx. 15\% of recovery capacity), which is therefore
enabled by default. You can change the error correction level by setting
the \autodoc:parameter{ec=<level>} option to 1 (“medium”), 2 (“medium”), 3 (“quartil”)
or 4 (“high”), respectively leading to a 7\%, 15\%, 25\% or 30\% recovery capacity.

Here is this package in action \qrcode[code=http://github.com/Omikhleia/qrcode.sile/] with
default settings.

\end{document}]]

return package
