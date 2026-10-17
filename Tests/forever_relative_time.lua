local AF={}
assert(loadfile("Features/Forever/DirectoryUI.lua"))("ArtisanFinder",AF)
AF.Now=function() return 100000000 end
AF.Text=function(_,key,value) return key..(value and (":"..value) or "") end
local cases={{0,"JUST_NOW"},{59,"MINUTES_AGO:59"},{60,"HOURS_AGO:1"},{1439,"HOURS_AGO:23"},
 {1440,"DAYS_AGO:1"},{30*1440,"DAYS_AGO:30"},{31*1440,"MONTHS_AGO:1"},
 {11*31*1440,"MONTHS_AGO:11"},{12*31*1440,"YEARS_AGO:1"},{25*31*1440,"YEARS_AGO:2"}}
for _,case in ipairs(cases) do
 assert(AF:FormatForeverObservedAge(AF:Now()-case[1]*60)=="FOREVER_"..case[2],"relative time threshold "..case[1])
end
assert(AF:FormatForeverObservedAge(AF:Now()+60)=="FOREVER_JUST_NOW","future timestamps are clamped")
print("PASS observed age transitions through minutes, hours, days, 31-day months and 12-month years")
