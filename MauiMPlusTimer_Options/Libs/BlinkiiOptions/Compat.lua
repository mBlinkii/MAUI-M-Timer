-- BlinkiiOptions/Compat.lua
-- Every difference between the game clients this lib cares about, in one place.
-- Retail and the current Classic clients share most of the API; what differs
-- is detected here once, never by checking the client version.

-- The legacy picker is configured by writing its fields.
-- luacheck: globals ColorPickerFrame

local lib = BlinkiiOptions
if lib.__skip then return end

local Compat = {}
lib.Compat = Compat

-- Resize bounds: SetResizeBounds on current clients, the two old setters before it.
function Compat.SetResizeBounds(frame, minWidth, minHeight)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minWidth, minHeight)
    elseif frame.SetMinResize then
        frame:SetMinResize(minWidth, minHeight)
    end
end

-- Color picker -------------------------------------------------------------

-- onChange(r, g, b, a) while the player picks, onCancel(r, g, b, a) with the
-- colour from before. The legacy picker stores transparency (1 - alpha).
function Compat.OpenColorPicker(r, g, b, a, hasAlpha, onChange, onCancel)
    local picker = ColorPickerFrame
    if not picker then return end
    a = a or 1

    local function current()
        local nr, ng, nb = picker:GetColorRGB()
        local na = 1
        if hasAlpha then
            if picker.GetColorAlpha then
                na = picker:GetColorAlpha()
            elseif OpacitySliderFrame then
                na = 1 - OpacitySliderFrame:GetValue()
            end
        end
        return nr, ng, nb, na
    end

    local function changed()
        onChange(current())
    end

    local function cancelled()
        onCancel(r, g, b, a)
    end

    if picker.SetupColorPickerAndShow then
        picker:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = hasAlpha, opacity = a,
            swatchFunc = changed,
            opacityFunc = changed,
            cancelFunc = cancelled,
        })
        return
    end

    picker:Hide()
    picker.func = changed
    picker.opacityFunc = changed
    picker.cancelFunc = cancelled
    picker.hasOpacity = hasAlpha
    picker.opacity = 1 - a
    picker.previousValues = { r = r, g = g, b = b, opacity = 1 - a }
    picker:SetColorRGB(r, g, b)
    picker:Show()
end
