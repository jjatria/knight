# The Boolean class within Knight
unit class Boolean does TypedValue[Bool, * <=> *, * == *];

method Str(--> Str) is pure { $!value ?? 'true' !! 'false' }