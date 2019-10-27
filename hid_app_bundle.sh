.mgit/bundle.sh -M hid_app -v -o /x/hid_app.exe \
   -a "cairo pixman png z freetype harfbuzz hidapi" -d "setupapi" \
   -m "hid_app*.lua hidapi.lua glue.lua box2d.lua color.lua time.lua
		bundle.lua cairo*.lua fs*.lua path.lua
		winapi.lua winapi/*.lua nw*.lua events.lua bitmap*.lua pp*.lua"
