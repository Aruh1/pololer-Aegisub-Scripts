--[[
KaraSplitter Automation Script for Aegisub
Port of karasplitter-web TypeScript implementation

Features:
- Split karaoke by character, word, or syllable
- Japanese romaji syllable pattern recognition
- Calculate k-timing based on line duration
- De-Ktime: Remove all karaoke timing tags

Author: pololer
Version: 1.1
]]

script_name = "KaraSplitter"
script_description = "Split karaoke timing by character, word, or syllable"
script_author = "pololer"
script_version = "1.1"

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Character sets for O(1) lookup
local PUNCTUATION_CHARS = {
    [" "] = true, ["!"] = true, ["?"] = true,
    [","] = true, [";"] = true, [":"] = true
}

local PUNCTUATION_CHARS_WITH_BRACE = {
    [" "] = true, ["!"] = true, ["?"] = true,
    [","] = true, [";"] = true, [":"] = true, ["}"] = true
}

local VOWELS = {
    ["a"] = true, ["e"] = true, ["i"] = true, ["o"] = true, ["u"] = true
}

local VOWELS_WITH_MACRON = {
    ["a"] = true, ["e"] = true, ["i"] = true, ["o"] = true, ["u"] = true,
    ["ā"] = true, ["ī"] = true, ["ū"] = true, ["ē"] = true, ["ō"] = true
}

local CONSONANTS_WITH_VOWEL = {
    ["r"] = true, ["y"] = true, ["m"] = true,
    ["n"] = true, ["h"] = true, ["k"] = true
}

local W_VOWELS = {["a"] = true, ["o"] = true, ["ā"] = true, ["ō"] = true}
local T_VOWELS = {["a"] = true, ["e"] = true, ["o"] = true, ["ā"] = true, ["ē"] = true, ["ō"] = true}
local S_VOWELS = {["a"] = true, ["u"] = true, ["e"] = true, ["o"] = true, ["ā"] = true, ["ū"] = true, ["ē"] = true, ["ō"] = true}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get UTF-8 character at position, returns char and next position
---@param str string
---@param pos number
---@return string, number
local function utf8_char_at(str, pos)
    local byte = str:byte(pos)
    if not byte then return "", pos + 1 end
    
    local len = 1
    if byte >= 0xF0 then
        len = 4
    elseif byte >= 0xE0 then
        len = 3
    elseif byte >= 0xC0 then
        len = 2
    end
    
    return str:sub(pos, pos + len - 1), pos + len
end

--- Convert string to array of UTF-8 characters
---@param str string
---@return table
local function utf8_chars(str)
    local chars = {}
    local pos = 1
    while pos <= #str do
        local char, next_pos = utf8_char_at(str, pos)
        if char ~= "" then
            table.insert(chars, char)
        end
        pos = next_pos
    end
    return chars
end

--- Get UTF-8 string length
---@param str string
---@return number
local function utf8_len(str)
    local len = 0
    local pos = 1
    while pos <= #str do
        local _, next_pos = utf8_char_at(str, pos)
        len = len + 1
        pos = next_pos
    end
    return len
end

--- Remove all ASS tags from text
---@param text string
---@return string
local function de_ktime(text)
    return text:gsub("{[^}]*}", "")
end

--- Strip only karaoke timing tags from a tag block, preserving other tags.
--- Removes \k, \K, \kf, \ko followed by optional digits.
--- Returns the cleaned tag block, or empty string if nothing remains.
---@param tag_block string e.g. "{\\q2\\k50\\c&H000057&}"
---@return string
local function strip_k_tags(tag_block)
    -- Remove the outer braces to work with inner content
    local inner = tag_block:sub(2, -2)
    -- Remove karaoke tags: \k, \K, \kf, \ko followed by optional digits
    inner = inner:gsub("\\[kK][fo]?%d*", "")
    if inner == "" then
        return ""
    end
    return "{" .. inner .. "}"
end

--- Parse text into segments of tags and plain text.
--- Strips karaoke timing tags but preserves all other override tags.
--- Returns:
---   plain_text: the text with all tags removed (for splitting)
---   tag_positions: array of {pos=number, tag=string} where pos is the
---                  character position in plain_text where the tag should appear
---@param text string
---@return string, table
local function parse_text_with_tags(text)
    local plain_text = ""
    local tag_positions = {}
    local pos = 1
    local len = #text
    
    while pos <= len do
        local char = text:sub(pos, pos)
        if char == "{" then
            -- Find closing brace
            local close_idx = text:find("}", pos, true)
            local tag_block
            if close_idx then
                tag_block = text:sub(pos, close_idx)
                pos = close_idx + 1
            else
                tag_block = text:sub(pos)
                pos = len + 1
            end
            -- Strip karaoke tags, keep the rest
            local cleaned = strip_k_tags(tag_block)
            if cleaned ~= "" then
                -- Position is current length of plain_text (0-indexed char boundary)
                local char_pos = utf8_len(plain_text)
                table.insert(tag_positions, {pos = char_pos, tag = cleaned})
            end
        else
            plain_text = plain_text .. char
            pos = pos + 1
        end
    end
    
    return plain_text, tag_positions
end

-- ============================================================================
-- SPLIT FUNCTIONS
-- ============================================================================

--- Split text by character
---@param kara_text string
---@return table
local function k_array_char(kara_text)
    local result = {}
    local chars = utf8_chars(kara_text)
    
    for _, char in ipairs(chars) do
        if PUNCTUATION_CHARS[char] and #result > 0 then
            result[#result] = result[#result] .. char
        else
            table.insert(result, char)
        end
    end
    
    return result
end

--- Split text by word
---@param kara_text string
---@return table
local function k_array_word(kara_text)
    local trimmed = kara_text:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return {} end
    
    local result = {}
    for word in trimmed:gmatch("%S+") do
        table.insert(result, word .. " ")
    end
    
    return result
end

--- Split text by syllable (Japanese romaji patterns)
---@param kara_text string
---@return table
local function k_array_syl(kara_text)
    local result = {}
    local pos = 1
    local len = #kara_text
    
    while pos <= len do
        local char, next_pos = utf8_char_at(kara_text, pos)
        local next_char = ""
        if next_pos <= len then
            next_char = utf8_char_at(kara_text, next_pos)
        end
        
        local lc = char:lower()
        local lnc = next_char:lower()
        
        -- Handle bracket content (ASS tags)
        if char == "{" then
            local close_idx = kara_text:find("}", pos, true)
            local bracket_content
            if close_idx then
                bracket_content = kara_text:sub(pos, close_idx)
                pos = close_idx + 1
            else
                bracket_content = kara_text:sub(pos)
                pos = len + 1
            end
            
            if #result > 0 then
                result[#result] = result[#result] .. bracket_content
            else
                table.insert(result, bracket_content)
            end
            goto continue
        end
        
        -- Handle punctuation
        if PUNCTUATION_CHARS_WITH_BRACE[char] then
            if #result > 0 then
                result[#result] = result[#result] .. char
            else
                table.insert(result, char)
            end
            pos = next_pos
            goto continue
        end
        
        -- Japanese syllable patterns
        if CONSONANTS_WITH_VOWEL[lc] then
            if VOWELS_WITH_MACRON[lnc] then
                table.insert(result, char .. next_char)
                pos = next_pos
                local _, p = utf8_char_at(kara_text, pos)
                pos = p
            else
                table.insert(result, char)
                pos = next_pos
            end
        elseif lc == "w" then
            if W_VOWELS[lnc] then
                table.insert(result, char .. next_char)
                pos = next_pos
                local _, p = utf8_char_at(kara_text, pos)
                pos = p
            else
                table.insert(result, char)
                pos = next_pos
            end
        elseif lc == "t" then
            if T_VOWELS[lnc] then
                table.insert(result, char .. next_char)
                pos = next_pos
                local _, p = utf8_char_at(kara_text, pos)
                pos = p
            elseif lnc == "s" then
                local third_pos = next_pos
                local _, p = utf8_char_at(kara_text, third_pos)
                if p <= len then
                    local third_char = utf8_char_at(kara_text, p)
                    table.insert(result, char .. next_char .. third_char)
                    pos = p
                    local _, np = utf8_char_at(kara_text, pos)
                    pos = np
                else
                    table.insert(result, char)
                    pos = next_pos
                end
            else
                table.insert(result, char)
                pos = next_pos
            end
        elseif lc == "c" then
            if lnc == "h" then
                local third_pos = next_pos
                local _, p = utf8_char_at(kara_text, third_pos)
                if p <= len then
                    local third_char = utf8_char_at(kara_text, p)
                    table.insert(result, char .. next_char .. third_char)
                    pos = p
                    local _, np = utf8_char_at(kara_text, pos)
                    pos = np
                else
                    table.insert(result, char .. next_char)
                    pos = next_pos
                    local _, np = utf8_char_at(kara_text, pos)
                    pos = np
                end
            else
                table.insert(result, char .. next_char)
                pos = next_pos
                local _, p = utf8_char_at(kara_text, pos)
                pos = p
            end
        elseif lc == "s" then
            if S_VOWELS[lnc] then
                table.insert(result, char .. next_char)
                pos = next_pos
                local _, p = utf8_char_at(kara_text, pos)
                pos = p
            elseif lnc == "h" then
                local third_pos = next_pos
                local _, p = utf8_char_at(kara_text, third_pos)
                if p <= len then
                    local third_char = utf8_char_at(kara_text, p)
                    table.insert(result, char .. next_char .. third_char)
                    pos = p
                    local _, np = utf8_char_at(kara_text, pos)
                    pos = np
                else
                    table.insert(result, char)
                    pos = next_pos
                end
            else
                table.insert(result, char)
                pos = next_pos
            end
        elseif lc == "f" then
            if lnc == "u" then
                table.insert(result, char .. next_char)
                pos = next_pos
                local _, p = utf8_char_at(kara_text, pos)
                pos = p
            else
                table.insert(result, char)
                pos = next_pos
            end
        elseif VOWELS[lc] then
            table.insert(result, char)
            pos = next_pos
        else
            -- Default: check if next is a vowel
            if VOWELS[lnc] then
                table.insert(result, char .. next_char)
                pos = next_pos
                local _, p = utf8_char_at(kara_text, pos)
                pos = p
            else
                table.insert(result, char)
                pos = next_pos
            end
        end
        
        ::continue::
    end
    
    return result
end

--- Split text based on mode
---@param kara_text string
---@param mode string "char", "word", or "syl"
---@return table
local function str_to_kara_array(kara_text, mode)
    if mode == "char" then
        return k_array_char(kara_text)
    elseif mode == "word" then
        return k_array_word(kara_text)
    elseif mode == "syl" then
        return k_array_syl(kara_text)
    end
    return {}
end

--- Collect all tags that should be inserted at a given character position
---@param tag_positions table
---@param char_pos number
---@return string
local function get_tags_at_pos(tag_positions, char_pos)
    local tags = ""
    for _, tp in ipairs(tag_positions) do
        if tp.pos == char_pos then
            tags = tags .. tp.tag
        end
    end
    return tags
end

--- Convert array to k-timed string with calculated timing, re-inserting preserved tags
---@param kara_split_array table
---@param time_per_letter number
---@param tag_positions table|nil
---@return string
local function arr_to_k_str(kara_split_array, time_per_letter, tag_positions)
    if #kara_split_array == 0 then return "" end
    tag_positions = tag_positions or {}
    
    local result = ""
    local char_offset = 0
    
    for _, syl in ipairs(kara_split_array) do
        local syl_len = utf8_len(syl)
        -- Collect tags that belong before this syllable
        local pre_tags = get_tags_at_pos(tag_positions, char_offset)
        result = result .. pre_tags .. string.format("{\\k%d}%s", time_per_letter * syl_len, syl)
        
        -- Check for tags within the syllable (between characters)
        local syl_chars = utf8_chars(syl)
        for ci = 2, #syl_chars do
            local inner_tags = get_tags_at_pos(tag_positions, char_offset + ci - 1)
            if inner_tags ~= "" then
                -- Insert mid-syllable tags after the syllable text
                result = result .. inner_tags
            end
        end
        
        char_offset = char_offset + syl_len
    end
    
    -- Append any trailing tags (at the very end of the text)
    local trailing = get_tags_at_pos(tag_positions, char_offset)
    if trailing ~= "" then
        result = result .. trailing
    end
    
    return result
end

--- Convert array to k-timed string with fixed k1, re-inserting preserved tags
---@param kara_split_array table
---@param tag_positions table|nil
---@return string
local function arr_to_k_str_fixed(kara_split_array, tag_positions)
    if #kara_split_array == 0 then return "" end
    tag_positions = tag_positions or {}
    
    local result = ""
    local char_offset = 0
    
    for _, syl in ipairs(kara_split_array) do
        local syl_len = utf8_len(syl)
        local pre_tags = get_tags_at_pos(tag_positions, char_offset)
        result = result .. pre_tags .. "{\\k1}" .. syl
        
        local syl_chars = utf8_chars(syl)
        for ci = 2, #syl_chars do
            local inner_tags = get_tags_at_pos(tag_positions, char_offset + ci - 1)
            if inner_tags ~= "" then
                result = result .. inner_tags
            end
        end
        
        char_offset = char_offset + syl_len
    end
    
    local trailing = get_tags_at_pos(tag_positions, char_offset)
    if trailing ~= "" then
        result = result .. trailing
    end
    
    return result
end

-- ============================================================================
-- MAIN PROCESSING FUNCTIONS
-- ============================================================================

--- Apply KaraSplitter to selected lines
---@param subs table Subtitle object
---@param sel table Selection indices
---@param mode string Split mode
---@param use_fixed_k boolean Use fixed k1 timing
---@return number Number of modified lines
local function apply_karasplit(subs, sel, mode, use_fixed_k)
    local modified_count = 0
    
    for _, i in ipairs(sel) do
        local line = subs[i]
        if line.class == "dialogue" and not line.comment then
            local text = line.text
            -- Parse text to extract non-karaoke tags and their positions
            local clean_text, tag_positions = parse_text_with_tags(text)
            
            if clean_text ~= "" then
                local split = str_to_kara_array(clean_text, mode)
                
                if use_fixed_k then
                    line.text = arr_to_k_str_fixed(split, tag_positions)
                else
                    -- Calculate duration in centiseconds
                    local duration = (line.end_time - line.start_time) / 10
                    local text_len = utf8_len(clean_text)
                    
                    if text_len > 0 then
                        local time_per_letter = math.floor(duration / text_len)
                        line.text = arr_to_k_str(split, time_per_letter, tag_positions)
                    end
                end
                
                subs[i] = line
                modified_count = modified_count + 1
            end
        end
    end
    
    return modified_count
end

--- Remove karaoke timing tags from selected lines
---@param subs table Subtitle object
---@param sel table Selection indices
---@return number Number of modified lines
local function apply_dektime(subs, sel)
    local modified_count = 0
    
    for _, i in ipairs(sel) do
        local line = subs[i]
        if line.class == "dialogue" then
            local new_text = de_ktime(line.text)
            if new_text ~= line.text then
                line.text = new_text
                subs[i] = line
                modified_count = modified_count + 1
            end
        end
    end
    
    return modified_count
end

-- ============================================================================
-- DIALOG FUNCTIONS
-- ============================================================================

local function show_main_dialog(subs, sel)
    local dialog = {
        {class = "label", x = 0, y = 0, width = 3, label = "KaraSplitter Settings"},
        {class = "label", x = 0, y = 1, label = "Split Mode:"},
        {class = "dropdown", name = "mode", x = 1, y = 1, width = 2,
            items = {"Character", "Word", "Syllable (Romaji)"}, value = "Character"},
        {class = "label", x = 0, y = 2, label = "K-Time:"},
        {class = "dropdown", name = "ktime", x = 1, y = 2, width = 2,
            items = {"Calculated (duration-based)", "Fixed {\\k1}"}, value = "Calculated (duration-based)"},
        {class = "checkbox", name = "clean_first", x = 0, y = 3, width = 3,
            label = "Clean existing tags first", value = true}
    }
    
    local pressed, results = aegisub.dialog.display(dialog, {"Apply", "Cancel"})
    return pressed == "Apply" and results or nil
end

-- ============================================================================
-- MACRO FUNCTIONS
-- ============================================================================

local function karasplit_main(subs, sel)
    local results = show_main_dialog(subs, sel)
    if not results then
        aegisub.cancel()
        return
    end
    
    local mode_map = {
        ["Character"] = "char",
        ["Word"] = "word",
        ["Syllable (Romaji)"] = "syl"
    }
    local mode = mode_map[results.mode] or "char"
    local use_fixed_k = results.ktime == "Fixed {\\k1}"
    
    aegisub.progress.title("Applying KaraSplitter...")
    local modified = apply_karasplit(subs, sel, mode, use_fixed_k)
    
    aegisub.debug.out(string.format("KaraSplitter (%s mode)\nModified: %d lines", mode, modified))
    aegisub.set_undo_point("KaraSplitter")
    
    return sel
end

local function karasplit_char(subs, sel)
    aegisub.progress.title("KaraSplit by Character...")
    local modified = apply_karasplit(subs, sel, "char", false)
    aegisub.debug.out(string.format("KaraSplit Character!\nModified: %d lines", modified))
    aegisub.set_undo_point("KaraSplit (Character)")
    return sel
end

local function karasplit_word(subs, sel)
    aegisub.progress.title("KaraSplit by Word...")
    local modified = apply_karasplit(subs, sel, "word", false)
    aegisub.debug.out(string.format("KaraSplit Word!\nModified: %d lines", modified))
    aegisub.set_undo_point("KaraSplit (Word)")
    return sel
end

local function karasplit_syl(subs, sel)
    aegisub.progress.title("KaraSplit by Syllable...")
    local modified = apply_karasplit(subs, sel, "syl", false)
    aegisub.debug.out(string.format("KaraSplit Syllable!\nModified: %d lines", modified))
    aegisub.set_undo_point("KaraSplit (Syllable)")
    return sel
end

local function dektime_main(subs, sel)
    aegisub.progress.title("Removing K-Time tags...")
    local modified = apply_dektime(subs, sel)
    aegisub.debug.out(string.format("De-Ktime!\nModified: %d lines", modified))
    aegisub.set_undo_point("De-Ktime")
    return sel
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

local function validate_has_selection(subs, sel)
    return #sel > 0
end

-- ============================================================================
-- REGISTER MACROS
-- ============================================================================

aegisub.register_macro("KaraSplitter/Split...",
    "Split karaoke with options", karasplit_main, validate_has_selection)
aegisub.register_macro("KaraSplitter/Split by Character",
    "Split karaoke by character", karasplit_char, validate_has_selection)
aegisub.register_macro("KaraSplitter/Split by Word",
    "Split karaoke by word", karasplit_word, validate_has_selection)
aegisub.register_macro("KaraSplitter/Split by Syllable",
    "Split karaoke by Japanese syllable", karasplit_syl, validate_has_selection)
aegisub.register_macro("KaraSplitter/De-Ktime",
    "Remove all karaoke timing tags", dektime_main, validate_has_selection)
