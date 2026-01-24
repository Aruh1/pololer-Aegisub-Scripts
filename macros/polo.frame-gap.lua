--[[
Frame Gap Automation Script for Aegisub
Based on Subtitle Edit's frame gap logic

Features:
- Frame Gap: Create minimum gaps between subtitles
- De-Frame Gap: Remove gaps between subtitles

Author: pololer
Version: 1.2
]]

script_name = "Frame Gap"
script_description = "Apply/Remove gaps between subtitles like Subtitle Edit"
script_author = "pololer"
script_version = "1.2"

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local DEFAULT_FRAME_RATE = 23.976
local MIN_SUBTITLE_DURATION_MS = 200
local DEFAULT_MAX_GAP_TO_CLOSE = 2000

-- Frame rate presets (ordered for display)
local FRAME_RATE_LIST = {
    {name = "23.976fps (Film/Anime)", fps = 23.976},
    {name = "24fps", fps = 24},
    {name = "25fps (PAL)", fps = 25},
    {name = "29.97fps (NTSC)", fps = 29.97},
    {name = "30fps", fps = 30},
    {name = "50fps (PAL HD)", fps = 50},
    {name = "59.94fps (NTSC HD)", fps = 59.94},
    {name = "60fps", fps = 60}
}

-- Build lookup table
local FRAME_RATES = {}
local FPS_NAMES = {}
for i, preset in ipairs(FRAME_RATE_LIST) do
    FRAME_RATES[preset.name] = preset.fps
    FPS_NAMES[i] = preset.name
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Calculate frame duration in milliseconds
---@param fps number Frame rate
---@return number Frame duration in milliseconds
local function get_frame_duration_ms(fps)
    return 1000 / fps
end

--- Build a set from selection indices for O(1) lookup
---@param sel table Selection indices
---@return table Selection set
local function build_selection_set(sel)
    local set = {}
    for _, i in ipairs(sel) do
        set[i] = true
    end
    return set
end

--- Get all dialogue lines sorted by start time
---@param subs table Subtitle object
---@return table Sorted dialogues with index and line
local function get_sorted_dialogue_lines(subs)
    local dialogues = {}
    local count = 0
    
    for i = 1, #subs do
        local line = subs[i]
        if line.class == "dialogue" and not line.comment then
            count = count + 1
            dialogues[count] = {index = i, line = line}
        end
    end
    
    table.sort(dialogues, function(a, b)
        return a.line.start_time < b.line.start_time
    end)
    
    return dialogues
end

-- ============================================================================
-- FRAME GAP FUNCTIONS (Create gaps between subtitles)
-- ============================================================================

---@param subs table Subtitle object
---@param sel table Selection indices
---@param min_gap_ms number Minimum gap in milliseconds
---@param mode string "all" or "selected"
---@return number Number of modified lines
local function apply_frame_gap(subs, sel, min_gap_ms, mode)
    local dialogues = get_sorted_dialogue_lines(subs)
    local dialogue_count = #dialogues
    
    if dialogue_count < 2 then
        return 0
    end
    
    local modified_count = 0
    local selected_set = mode == "selected" and build_selection_set(sel) or nil
    
    for i = 1, dialogue_count - 1 do
        local current = dialogues[i]
        local next_line = dialogues[i + 1]
        
        -- Skip if in selected mode and current line not selected
        if selected_set and not selected_set[current.index] then
            -- Continue to next iteration
        else
            local current_gap = next_line.line.start_time - current.line.end_time
            
            -- Only process if gap is smaller than required minimum
            if current_gap < min_gap_ms then
                local new_end = next_line.line.start_time - min_gap_ms
                
                -- Ensure minimum subtitle duration is maintained
                if new_end > current.line.start_time + MIN_SUBTITLE_DURATION_MS then
                    current.line.end_time = math.floor(new_end)
                    subs[current.index] = current.line
                    modified_count = modified_count + 1
                end
            end
        end
    end
    
    return modified_count
end

local function show_dialog(subs, sel)
    local dialog = {
        {class = "label", x = 0, y = 0, width = 3, label = "Frame Gap Settings"},
        {class = "label", x = 0, y = 1, label = "Mode:"},
        {class = "dropdown", name = "mode", x = 1, y = 1, width = 2,
            items = {"All lines", "Selected lines only"}, value = "All lines"},
        {class = "label", x = 0, y = 2, label = "Frame Rate:"},
        {class = "dropdown", name = "fps_preset", x = 1, y = 2, width = 2,
            items = FPS_NAMES, value = FPS_NAMES[1]},
        {class = "label", x = 0, y = 3, label = "Min gap (frames):"},
        {class = "intedit", name = "gap_frames", x = 1, y = 3, width = 1,
            value = 1, min = 1, max = 10},
        {class = "label", x = 0, y = 4, label = "— OR —"},
        {class = "label", x = 0, y = 5, label = "Custom gap (ms):"},
        {class = "intedit", name = "gap_ms", x = 1, y = 5, width = 1,
            value = 0, min = 0, max = 1000},
        {class = "checkbox", name = "use_custom", x = 0, y = 6,
            label = "Use custom milliseconds", value = false}
    }
    
    local pressed, results = aegisub.dialog.display(dialog, {"Apply", "Cancel"})
    return pressed == "Apply" and results or nil
end

local function frame_gap_main(subs, sel)
    local results = show_dialog(subs, sel)
    if not results then
        aegisub.cancel()
        return
    end
    
    local min_gap_ms
    if results.use_custom then
        min_gap_ms = results.gap_ms
    else
        local fps = FRAME_RATES[results.fps_preset] or DEFAULT_FRAME_RATE
        min_gap_ms = get_frame_duration_ms(fps) * results.gap_frames
    end
    
    local mode = results.mode == "Selected lines only" and "selected" or "all"
    
    aegisub.progress.title("Applying Frame Gap...")
    local modified = apply_frame_gap(subs, sel, min_gap_ms, mode)
    
    aegisub.debug.out(string.format("Frame Gap: %.2fms\nModified: %d lines", min_gap_ms, modified))
    aegisub.set_undo_point("Apply Frame Gap")
    
    return sel
end

local function frame_gap_quick(subs, sel)
    aegisub.progress.title("Quick Frame Gap...")
    
    local min_gap_ms = get_frame_duration_ms(DEFAULT_FRAME_RATE)
    local modified = apply_frame_gap(subs, sel, min_gap_ms, "all")
    
    aegisub.debug.out(string.format("Quick Frame Gap (%.1fms)!\nModified: %d lines", min_gap_ms, modified))
    aegisub.set_undo_point("Quick Frame Gap")
    
    return sel
end

local function frame_gap_selected(subs, sel)
    if #sel == 0 then
        aegisub.debug.out("No lines selected!")
        return sel
    end
    
    aegisub.progress.title("Frame Gap Selection...")
    
    local min_gap_ms = get_frame_duration_ms(DEFAULT_FRAME_RATE)
    local modified = apply_frame_gap(subs, sel, min_gap_ms, "selected")
    
    aegisub.debug.out(string.format("Frame Gap Selection!\nModified: %d lines", modified))
    aegisub.set_undo_point("Frame Gap (Selected)")
    
    return sel
end

-- ============================================================================
-- DE-FRAME GAP FUNCTIONS (Remove gaps between subtitles)
-- ============================================================================

---@param subs table Subtitle object
---@param sel table Selection indices
---@param keep_gap_ms number Gap to keep in milliseconds
---@param mode string "all" or "selected"
---@param max_gap_to_close number Maximum gap to close in milliseconds
---@return number Number of modified lines
local function apply_deframe_gap(subs, sel, keep_gap_ms, mode, max_gap_to_close)
    local dialogues = get_sorted_dialogue_lines(subs)
    local dialogue_count = #dialogues
    
    if dialogue_count < 2 then
        return 0
    end
    
    local modified_count = 0
    local selected_set = mode == "selected" and build_selection_set(sel) or nil
    
    for i = 1, dialogue_count - 1 do
        local current = dialogues[i]
        local next_line = dialogues[i + 1]
        
        -- Skip if in selected mode and current line not selected
        if selected_set and not selected_set[current.index] then
            -- Continue to next iteration
        else
            local current_gap = next_line.line.start_time - current.line.end_time
            
            -- Only close gaps that are positive, larger than keep_gap, and within max limit
            if current_gap > keep_gap_ms and current_gap <= max_gap_to_close then
                local new_end = next_line.line.start_time - keep_gap_ms
                current.line.end_time = math.floor(new_end)
                subs[current.index] = current.line
                modified_count = modified_count + 1
            end
        end
    end
    
    return modified_count
end

local function show_deframe_dialog(subs, sel)
    local dialog = {
        {class = "label", x = 0, y = 0, width = 3, label = "De-Frame Gap (Remove gaps)"},
        {class = "label", x = 0, y = 1, label = "Mode:"},
        {class = "dropdown", name = "mode", x = 1, y = 1, width = 2,
            items = {"All lines", "Selected lines only"}, value = "All lines"},
        {class = "label", x = 0, y = 2, label = "Keep gap (ms):"},
        {class = "intedit", name = "keep_gap", x = 1, y = 2, width = 1,
            value = 0, min = 0, max = 100},
        {class = "label", x = 0, y = 3, label = "Max gap to close (ms):"},
        {class = "intedit", name = "max_gap", x = 1, y = 3, width = 1,
            value = DEFAULT_MAX_GAP_TO_CLOSE, min = 1, max = 10000},
        {class = "label", x = 0, y = 5, width = 3, label = "Extends end times to close gaps."}
    }
    
    local pressed, results = aegisub.dialog.display(dialog, {"Apply", "Cancel"})
    return pressed == "Apply" and results or nil
end

local function deframe_gap_main(subs, sel)
    local results = show_deframe_dialog(subs, sel)
    if not results then
        aegisub.cancel()
        return
    end
    
    local mode = results.mode == "Selected lines only" and "selected" or "all"
    
    aegisub.progress.title("Removing Frame Gaps...")
    local modified = apply_deframe_gap(subs, sel, results.keep_gap, mode, results.max_gap)
    
    aegisub.debug.out(string.format("De-Frame Gap!\nKeep: %dms, Max: %dms\nModified: %d lines", 
        results.keep_gap, results.max_gap, modified))
    aegisub.set_undo_point("De-Frame Gap")
    
    return sel
end

local function deframe_gap_quick(subs, sel)
    aegisub.progress.title("Quick De-Frame Gap...")
    
    local modified = apply_deframe_gap(subs, sel, 0, "all", DEFAULT_MAX_GAP_TO_CLOSE)
    
    aegisub.debug.out(string.format("Quick De-Frame Gap (0ms)!\nModified: %d lines", modified))
    aegisub.set_undo_point("Quick De-Frame Gap")
    
    return sel
end

local function deframe_gap_selected(subs, sel)
    if #sel == 0 then
        aegisub.debug.out("No lines selected!")
        return sel
    end
    
    aegisub.progress.title("De-Frame Gap Selection...")
    
    local modified = apply_deframe_gap(subs, sel, 0, "selected", DEFAULT_MAX_GAP_TO_CLOSE)
    
    aegisub.debug.out(string.format("De-Frame Gap Selection!\nModified: %d lines", modified))
    aegisub.set_undo_point("De-Frame Gap (Selected)")
    
    return sel
end

-- ============================================================================
-- VALIDATION FUNCTIONS
-- ============================================================================

--- Validation function for selection-based macros
---@param subs table Subtitle object
---@param sel table Selection indices
---@return boolean
local function validate_has_selection(subs, sel)
    return #sel > 0
end

-- ============================================================================
-- REGISTER MACROS
-- ============================================================================

-- Frame Gap
aegisub.register_macro("Frame Gap/Apply Frame Gap...", 
    "Apply minimum gap between subtitles", frame_gap_main)
aegisub.register_macro("Frame Gap/Quick Apply (1 frame @ 23.976fps)", 
    "Quick 1-frame gap at 23.976fps", frame_gap_quick)
aegisub.register_macro("Frame Gap/Apply to Selection", 
    "Apply 1-frame gap to selection", frame_gap_selected, validate_has_selection)

-- De-Frame Gap
aegisub.register_macro("Frame Gap/De-Frame Gap...", 
    "Remove gaps between subtitles", deframe_gap_main)
aegisub.register_macro("Frame Gap/Quick De-Frame Gap (0ms)", 
    "Quick remove all gaps", deframe_gap_quick)
aegisub.register_macro("Frame Gap/De-Frame Gap Selection", 
    "Remove gaps for selection", deframe_gap_selected, validate_has_selection)
