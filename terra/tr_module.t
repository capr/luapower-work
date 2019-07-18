
--tr's module table, not declared in tr_types because tr_types has
--dependencies that need to be loaded before tr_types is loaded.
return require'terra/low'.module()
