--[[

    Name: Mari
    Date: 12/10/2022

    Description: RichString is a complex module designed to turn normal strings into richText strings! This resource uses Markdown syntaxing
    similar to Discord in order to generate individual TextObjects. This module was only designed to support VISUAL applications and does
    not handle sizing or positioning because it is designed to be paired up with the SmartText utility module.

    ========================================================================================================================================

    v1.2 Updates:

    + Improved Markdown syntaxing
    + Renewed the ":Generate" function to support better & smarter algorithmic functuality
    + Implemented dynamic logic for syntax definitions

]]--

--// Module
local RichString = {};

local StringObject = {};
StringObject.__index = StringObject

--// Imports
local Markdown = require(script.Parent.Markdown);

--// Main Methods

--- Creates a new RichString object through OOP
function RichString.new(Properties : table?) : StringObject
    return setmetatable({

        --// Configurations \\--

        ["MarkdownEnabled"] = (Properties and Properties.MarkdownEnabled) or true, -- Will text automatically be MarkedDown? ( boolean )
        ["ResponsiveSizing"] = (Properties and Properties.ResponsiveSizing) or true, -- Will text automatically resize when the ancestor does? ( boolean )

        --// Programmable \\--
        
        ["_hyperFunctions"] = {}, -- { key = function }
        ["_replacements"] = {} -- { keyword = function OR string }

    }, StringObject);
end

--// Metamethods

--- Defines a function for programmic string functuality!
function StringObject:Define(Key : string, Callback : callback)
    assert(type(Key) == "string", "A string type was not passed for the \"Key\" parameter. Received \""..(type(Key)).."\"");
    assert(type(Callback) == "function", "A callback function type was not passed for the \"callback\" parameter. Received \""..(type(Callback)).."\"");

    if (self._hyperFunctions[Key]) then
        warn("A function with the name \""..(Key).."\" has already exists!");
        return
    end

    self._hyperFunctions[Key] = Callback
end

function StringObject:Replace(KeyWord : string, Replacement : callback | string)
    assert(type(KeyWord) == "string", "A string type was not passed for the \"key\" parameter. Received \""..(type(KeyWord)).."\"");
    assert(not self._replacements[KeyWord], "The provided KeyWord \""..(KeyWord).."\" is already in use!");

    self._replacements[KeyWord] = Replacement
end

--- Creates a new set of TextLabels using previously assigned property metadata. [ THIS WILL NOT FORMAT YOUR LABELS! You must use the SmartText module for further functuality! ]
function StringObject:Generate(Text : string, TextFont : Enum.Font, Callback : callback?, IsButton : boolean?) : table
    assert(type(Text) == "string", "The provided Text parameter was not of type \"string\". (received \""..(type(Text)).."\" instead.)");
    assert(typeof(TextFont) == "EnumItem", "The provided TextFont parameter was not of type \"EnumItem\". (received \""..(type(TextFont)).."\" instead.)")
    assert(table.find(Enum.Font:GetEnumItems(), TextFont), "The provided TextFont EnumItem was not a valid Font EnumItem!");
    assert((not Callback) or (type(Callback) == "function"), "The provided callback function was not of type \"function\". Received \""..(type(Callback)).."\"");

    local MarkdownInfo : table = ((self.MarkdownEnabled and Markdown:GetMarkdownData(Text, true)) or {});
    local HyperCases : table = GetHyperCases(Text);

    local Objects = {};

    for Starts, Ends in utf8.graphemes(Text) do
        if (IsSpecialSyntax(Starts, MarkdownInfo, HyperCases)) then continue; end -- This is a markdown/hypertext syntax! (does NOT require instancing)

        local Character : string = Text:sub(Starts, Ends);
        local Word, StartIndex : string & number = GetParentWord(Text, Starts);

        local HyperData : table = FindHyperCase(Starts, HyperCases);
        local HyperFunction : callback? = (HyperData and self._hyperFunctions[HyperData.Function]);

        local Formatting = FindMarkdown(Starts, MarkdownInfo);

        if (HyperData and not HyperFunction) then
            warn([[Requested HyperFunction "]]..(HyperData.Content)..[[" is undefined. Please define your function using 
                                    RichString:Define("myCoolFunction", function(...)) before using the HyperFunction syntax
                                    for the function.
            ]]);
        end

        --// Replacements
        --\\ Here we can look for phrase replacements (if any)

        local PhraseReplacement : string | callback = (Character ~= " " and self._replacements[Word]);

        if (type(PhraseReplacement) == "function") then
            if (Starts ~= StartIndex) then continue; end -- Ignore any non-starting subindexes from the provided word

            local ReplacementObject = PhraseReplacement(); -- This function MUST return an instance!

            if ((not ReplacementObject) or (typeof(ReplacementObject) ~= "Instance") or (not ReplacementObject:IsA("GuiObject"))) then
                error("RichString replacement error. The replacement for \""..(Word).."\" did not return a GuiObject Instance!");
            end

            if (HyperFunction and (ReplacementObject:IsA("ImageButton") or ReplacementObject:IsA("TextButton"))) then
                ReplacementObject.MouseButton1Click:Connect(function()
                    HyperFunction(HyperData.Content, HyperData.Function);
                end);
            end

            table.insert(Objects, ReplacementObject);

            if (Callback) then
                Callback(ReplacementObject);
            end
        else
            local NewTextObject = CreateTextObject(
                TextFont,
                Character,
                ((HyperData or IsButton) and "TextButton") or "TextLabel"
            );
            
            if (self.MarkdownEnabled) then -- We only need to markdown our string IF "MarkdownEnabled" is true
                for _, format in ipairs(Formatting) do
                    NewTextObject.Text = string.format(format, NewTextObject.Text);
                end
                
                NewTextObject.RichText = true
            end

            if (HyperFunction) then
                NewTextObject.MouseButton1Click:Connect(function()
                    HyperFunction(HyperData.Content, HyperData.Function);
                end);
            end
            
            table.insert(Objects, NewTextObject);

            if (Callback) then
                Callback(NewTextObject);
            end
        end
    end

    return Objects
end

--// Functions

--- Creates a new TextLabel preset! This was made purely for readability purposes.
function CreateTextObject(Font, Grapheme, ObjectType : string?)
    local NewLabel = Instance.new(ObjectType or "TextLabel");

    NewLabel.TextStrokeTransparency = 0.8
    NewLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
    
    NewLabel.TextXAlignment = Enum.TextXAlignment.Left
    NewLabel.Font = Font
    
    NewLabel.Name = ("RichString_")..(Grapheme)
    NewLabel.BackgroundTransparency = 1
    NewLabel.Text = Grapheme

    return NewLabel
end

--- Detects all hyper formatting cases! [ ex. "(this)[...]" formatting ]
function GetHyperCases(Content : string) : table
    local HyperCases = {};
	local Point = 0
	
	for _ in Content:gmatch("%(.*%)") do
		local ParenthesisAt, _ = Content:find("%(.*%)", Point);
		local BracketsAt, BracketsEnd = Content:find("%[.*%]", Point);
		
        if (not BracketsAt) then return; end
		Point += (BracketsEnd - Point);

		local HasBothSyntaxes = (ParenthesisAt ~= nil and BracketsAt ~= nil);
		if (not HasBothSyntaxes) then return; end -- Both Syntaxes were NOT present. ( no need to continue )
		if (Content:sub(BracketsAt - 1, BracketsAt - 1) ~= ")") then return; end -- If our syntaxes are NOT linked then this is malformed ( CANCEL )

		local InnerParenthesis = Content:sub(ParenthesisAt + 1, BracketsAt - 2); -- Inner Parenthesis text ( eg. "this" )
		local InnerBrackets = Content:sub(BracketsAt + 1, Content:find("%]") - 1); -- Callback function key ( eg. "..." )
		
		table.insert(HyperCases, {
			["Content"] = InnerParenthesis,
			["Function"] = InnerBrackets,
			
			["Starts"] = ParenthesisAt + 1,
			["Ends"] = BracketsAt - 2,

            ["FullEnd"] = BracketsEnd
		});
	end
	
	return HyperCases
end

--- Returns the parent word of the specified subindex within the specified content string
function GetParentWord(Content : string, SubIndex : number) : string & number
    local Index = 1

    for _, Word in pairs(Content:split(" ")) do
        local Starts, Ends = Index, Index + #Word

        if (SubIndex >= Starts and SubIndex <= Ends) then
            return Word, Index
        end

        Index += (#Word + 1);
    end
end

--- Returns a markdown table based on whether a word from the provided string has markdown information available
function FindMarkdown(SubIndex : number, MarkdownInfo : table) : table?
    local MarkdownFormats = {};

    for _, Scope in ipairs(MarkdownInfo) do
        local isWithinMarkdownSyntax = ((SubIndex >= Scope.starts) and (SubIndex <= Scope.ends));

        if (isWithinMarkdownSyntax) then -- This word is within a markdown finding!
            table.insert(MarkdownFormats, Scope.format);
        end
    end

    return MarkdownFormats
end

--- Finds the hyper case for the provided subindex (if any)
function FindHyperCase(SubIndex : number, HyperCases : table?) : table?
    if (not HyperCases) then return; end
    
    for _, CaseScope in pairs(HyperCases) do
        local IsWithinCase = ((SubIndex >= CaseScope.Starts) and (SubIndex <= CaseScope.Ends));
        
        if (IsWithinCase) then
            return CaseScope
        end
    end
end

--- Returns a boolean that determines if the provided sub-index is a part of any special syntaxing
function IsSpecialSyntax(SubIndex : number, MarkdownInfo : table?, HyperCases : table?) : boolean?
    if (MarkdownInfo) then
        for _, Scope in ipairs(MarkdownInfo) do
            local HasThisMarkdown = ((SubIndex >= Scope.starts) and (SubIndex <= Scope.ends));
            local IsPartOfSyntax = (HasThisMarkdown and ((SubIndex <= Scope.starts + #Scope.syntax - 1) or (SubIndex >= Scope.ends - #Scope.syntax + 1)));
    
            if (not IsPartOfSyntax) then continue; end
            return true;
        end
    end

    if (HyperCases) then
        for _, CaseScope in pairs(HyperCases) do
            local IsWithinCase = ((SubIndex >= CaseScope.Starts - 1) and (SubIndex <= CaseScope.FullEnd));
            local IsPartOfEmbed = (IsWithinCase and (
                (SubIndex == CaseScope.Starts - 1) or (SubIndex <= CaseScope.FullEnd and SubIndex > CaseScope.Ends)
            ));
            
            if (not IsPartOfEmbed) then continue; end
            return true;
        end 
    end
end

return RichString