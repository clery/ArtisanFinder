-- Create our library object.
--
local LMD = LibStub("LibMarkdown-1.0");

-- Here's the sample markdown text we'll use. 
-- Note: [====[ ... ]====] is the same as a quoted string in lua, as 
-- long as the number of equals signs match
--
local text = [==============[
![This is an image.](Interface\\QuestionFrame\\answer-ChromieScenario-Chromie-small.PNG right 200x100 "It's Chromie Time!") 

LibMarkdown Demo
================

This is a `SimpleHTML` frame. {rt1} {rt2} {rt3} {rt4} {rt5} {rt6} {rt7} {rt8}

### Some Things to Note:

 1) This frame was written in _markdown_. This should be **bold** but it's not; that's a WoW limitation.
 2. `Backticks` are used to show code.
 3) Here's a link to the [markdown specification](https://commonmark.org/help/).
 4. This is an ordered list. A horizontal rule follows.

------------------------------------

 - This is an unordered list. The bullets are purple.
 * You can press &quot;ESC&quot; to close this window.
 + Or you can use [this link](window:close) to close it.
^
    local LMD = LibStub("LibMarkdown-1.0");
    print("This is a code block.");

> This is a blockquote.
>
> Blockquotes are shown with horizontal rules 
> on the top and the bottom.

```
  <body>
    <p>This is another kind of code block.</p>
  </body>
```

## HTML in Markdown

<p>LibMarkdown passes HTML through unchanged.</p>
<p>If HTML tags aren't properly closed, SimpleHTML won't display any of the HTML.</p>
<p>SimpleHTML won't show the contents of tags it doesn't recognize, such 
as <strong>the &lt;strong&gt; tag</strong> (<-- see, this wasn't displayed), 
even if they're valid HTML.</p>

]==============];

-- ]==============]; local more_text = [==============[
local frame = _G["LMDDemoFrame"] or CreateFrame("Frame", "LMDDemoFrame", UIParent, "SimplePanelTemplate");
frame.html  = frame.html or CreateFrame("SimpleHTML", "LMDDemoFrameSimpleHTML", frame);

frame:SetSize(640,600);
frame:SetPoint("CENTER", UIParent, "CENTER", 30, 30);
frame.html:SetSize(600, 540);
frame.html:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -30);

-- Some font definitions.
-- Look here for font objects: https://www.townlong-yak.com/framexml/live/FontStyles.xml
--
frame.html:SetFontObject("h1", "SubzoneTextFont");
frame.html:SetTextColor("h1", 0, 0.6, 1, 1);

frame.html:SetFontObject("h2", "Fancy22Font");
frame.html:SetTextColor("h2", 0, 1, 0, 1);

frame.html:SetFontObject("h3", "NumberFontNormalLarge");
frame.html:SetTextColor("h3", 0, 0.8, 0.4, 1);

frame.html:SetFontObject("p", "GameFontNormal");
frame.html:SetTextColor("p", 1, 1, 1, 1);

frame.html:SetHyperlinkFormat("[|cff3399ff|H%s|h%s|h|r]");
tinsert(UISpecialFrames, "LMDDemoFrame");

-- This is a minimal hyperlink handler...
--
frame.html:SetScript("OnHyperlinkClick", 
  function(f, link, text, ...) 
    if     link=="window:close" 
    then   f:GetParent():Hide() 
    elseif link:match("https?://")
    then   StaticPopup_Show("LIBMARKDOWNDEMOFRAME_URL", nil, nil, { title = text, url = link });
    end 
  end);

frame.html:SetScript("OnHyperlinkEnter", function(f) f:SetCursor("Interface\\CURSOR\\vehichleCursor.PNG") end);
frame.html:SetScript("OnHyperlinkLeave", function(f) f:SetCursor()                                        end);

-- ... and this is the popup it opens.
--
StaticPopupDialogs["LIBMARKDOWNDEMOFRAME_URL"] = 
{ OnShow = 
    function(self, data)
      self.text:SetFormattedText("Here's a link to " .. data.title);
      self.editBox:SetText(data.url);
      self.editBox:SetAutoFocus(true);
      self.editBox:HighlightText();
    end,
  text         = "",
  wide         = true,
  closeButton  = true,
  button1      = "OK",
  timeout      = 60,
  hasEditBox   = true,
  hideOnEscape = true,
  OnAccept               = function(self) self:Hide() end,
  EditBoxOnEnterPressed  = function(self) self:Hide() end,
  EditBoxOnEscapePressed = function(self) self:Hide() end 
};

frame:SetScript("OnShow", 
  function(self)
    self.html:SetText(LMD:ToHTML(text)); 
    print(LMD:ToHTML(text)); 
  end);

print("[|cff00ddddLibMarkdown|r] demo loaded. Type |cff00dddd/script LMDDemoFrame:Show()|r to see it.");
