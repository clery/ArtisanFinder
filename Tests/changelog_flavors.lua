local function load(path,AF) assert(loadfile(path))("ArtisanFinder",AF) end
for _,locale in ipairs({"enUS","frFR"}) do
    GetLocale=function() return locale end
    for _,flavor in ipairs({"Retail","Forever"}) do
        local AF={}
        load("Flavors/"..flavor..".lua",AF)
        load("Core/Bootstrap.lua",AF)
        load("Locales/enUS.lua",AF) load("Locales/frFR.lua",AF)
        load("Locales/"..flavor.."/enUS.lua",AF)
        load("Locales/"..flavor.."/frFR.lua",AF)
        load("Changelogs/"..flavor..".lua",AF)
        load("UI/Changelog.lua",AF)
        local entries=AF:GetChangelogEntries()
        assert(#entries>0 and entries[1].content~="")
        if flavor=="Forever" then
            assert(entries[1].version=="0.3.0-dev" and entries[#entries].version=="0.2.0")
            assert(not entries[1].content:find("CHANGELOG_ENTRY",1,true),"Forever resolves its own text")
        else
            assert(entries[1].version=="2.1.4" and #entries==9,"Retail release history preserved")
        end
        local filtered=AF:GetChangelogEntries("99.0.0")
        assert(#filtered==1 and filtered[1].content==entries[1].content,"empty filter uses same flavor fallback")
        local markdown=AF:BuildChangelogMarkdown()
        assert(markdown==entries[1].content,"in-game rendering uses selected history")
    end
end
print("PASS Retail/Forever changelog selection, English/French text, rendering and filtered fallback")

-- Exercise the actual Forever renderer with no LibMarkdown at all.
LibStub=nil
for _,locale in ipairs({"enUS","frFR"}) do
    GetLocale=function() return locale end
    local AF={}
    for _,path in ipairs({"Flavors/Forever.lua","Core/Bootstrap.lua","Locales/enUS.lua",
        "Locales/frFR.lua","Locales/Forever/enUS.lua","Locales/Forever/frFR.lua",
        "Changelogs/Forever.lua","UI/Changelog.lua"}) do load(path,AF) end
    for _,entry in ipairs(AF.CHANGELOG_RECENT_ENTRIES) do
        local html=AF:BuildChangelogHTML(nil,entry.version)
        assert(html:find("<html><body>",1,true) and html:find("<h3>",1,true))
        assert(html:find("<p>• ",1,true),"list items render as individual bullets")
        assert(not html:find("###",1,true) and not html:find("<p>- ",1,true),"no raw Markdown")
    end
    AF.CHANGELOG_RECENT_ENTRIES={{version="test",content="# Heading\n\n**Bold** and `code` & <text>\n\n- First\n- Second\n\n1. Numbered\n"}}
    local html=AF:BuildChangelogHTML()
    assert(html:find("<h1>Heading</h1>",1,true))
    assert(html:find("|cffffd100Bold|r",1,true) and html:find("|cffcccccccode|r",1,true))
    assert(html:find("&amp; &lt;text&gt;",1,true) and html:find("<p>1. Numbered</p>",1,true))
    assert(not html:find("**",1,true) and not html:find("`",1,true))
end
print("PASS native Forever Markdown headings, bullets, emphasis, code and HTML escaping without external library")
