-- Diagnostics limit test (lua/genja/diag-limit.lua): 7 lua_ls warnings
-- (undefined-global), one per line. Expected: 3 drawn, ]d visits all 7.
print(undefined_one)
print(undefined_two)
print(undefined_three)
print(undefined_four)
print(undefined_five)
print(undefined_six)
print(undefined_seven)
