#!./luajit

terralib.printraw(terralib.systemincludes)

terralib.includec'stdio.h'

terra f()
    terralib.traceback(nil)
    --printf("%d", 5)
end
terra g()
    f()
end
g()

