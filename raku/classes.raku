#unit module Knight;


my $Identifier;

class Value {
	method new($value) { self.bless :$value }

	method Str(--> Str) { $.run.value.Str }
	method Bool(--> Bool) { $.run.value.Bool }
	method Int(--> Int) { $.run.value.Int }
	method run(--> Value) { self }

	method assign(Value $value, --> Value) {
		$Identifier.new($.Str).assign($value);
	}

	method lth(Value $rhs, --> Bool) {
		$.cmp($rhs) === Less
	}

	method gth(Value $rhs, --> Bool) {
		$.cmp($rhs) === More
	}

	multi method eql(Value $, --> Bool) {
		False
	}
}

class Boolean is Value {
	has Bool $.value;

	method Str(--> Str) {
		$.value ?? "true" !! "false"
	}

	method cmp(Value $rhs, --> Order) {
		$.value <=> ?$rhs
	}

	multi method eql(Boolean $rhs, --> Bool) {
		$.value == $rhs.value
	}
}

class Null is Value {
	method new() { self.bless }

	method Str(--> Str) { "null" }
	method Bool(--> Bool) { False }
	method Int(--> Int) { 0 }

	method cmp($) {
		die "Cannot compare Null."
	}

	multi method eql(Null $, --> Bool) {
		True
	}
}

class String is Value {
	has Str $.value;

	method Int(--> Int) {
		$!value ~~ /^ <[\d]>* /;
		$<>.Int
	}

	method add(Value $rhs, --> String) {
		String.new: $!value ~ $rhs.Str
	}

	method mul(Value $rhs, --> String) {
		String.new: $!value x $rhs.Str
	}

	method cmp(Value $rhs, --> Order) {
		$!value cmp $rhs.Str
	}

	multi method eql(String $rhs, --> Bool) {
		$!value === $rhs.Str
	}
}

class Number is Value {
	has Int $.value;

	method add(Value $rhs, --> Number) {
		Number.new: $!value + $rhs.Int
	}

	method sub(Value $rhs, --> Number) {
		Number.new: $!value - $rhs.Int
	}

	method mul(Value $rhs, --> Number) {
		Number.new: $!value * $rhs.Int
	}

	method div(Value $rhs, --> Number) {
		Number.new: $!value div ($rhs.Int or die "Cannot divide by zero!")
	}

	method mod(Value $rhs, --> Number) {
		Number.new: $!value mod ($rhs.Int or die "Cannot modulo by zero!")
	}

	method pow(Value $rhs, --> Number) {
		Number.new: $!value ** $rhs.Int
	}

	method cmp(Value $rhs, --> Order) {
		$!value <=> $rhs.Int
	}

	multi method eql(Number $rhs, --> Bool) {
		$!value == $rhs.Int
	}
}

class Identifier is Value {
	has Str $!ident;

	# todo: make this private
	constant %ENV = (a => 3);

	method new(Str $ident) {
		self.bless :$ident
	}

	method run(--> Value) {
		%ENV{$!ident} or die "unknown variable '$!ident'";
	}

	method assign(Value $value, --> Value) {
		%ENV{$!ident} = $value;
		$value
	}
}

say String.new("a").assign(Number.new(3));

class Function is Value {
	has $!func;
	has @!args;

	constant %FUNCS = (
		'P' => sub (--> Value) {
			String.new: get
		}

		'R' => sub (--> Value) {
			Number.new: (^0xffff_ffff).pick
		}

		'E' => sub (Value $str, --> Value) {
			Knight::run $str.Str
		}

		'B' => sub (Value $block, --> Value) {
			$block
		}

		'C' => sub (Value $block, --> Value) {
			$block.run.run
		}

		'`' => sub (Value $str, --> Value) {
			String.new: qx<$str>
		}

		'Q' => sub (Value $code) {
			exit $code
		}

		'!' => sub (Value $bool, --> Value) {
			Boolean.new: !$bool
		}

		'L' => sub (Value $str, --> Value) {
			Number.new: $str.Str.chars
		}

		'O' => sub (Value $str, --> Value) {
			my $result = $str.run;
			my $to-output = $result.Str;

			if $to-output.substr(*-1) eq '\\' {
				print $to-output.substr(0, *-1);
			} else {
				say $to-output;
			}

			$result;
		}

		'+' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs = 1;
			if $lhs.isa(String) {
				String.new: $lhs ~ $rhs
			} else {

			}
			$lhs.run + $rhs.run
		}

		'-' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run - $rhs.run
		}

		'*' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run * $rhs.run
		}

		'/' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run div $rhs.run
		}

		'%' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run mod $rhs.run
		}

		'^' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run ** $rhs.run
		}

		'<' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run < $rhs.run
		}

		'>' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run > $rhs.run
		}

		'?' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run._eql($rhs.run)
		}

		'&' => sub (Value $lhs, Value $rhs, --> Value) {
			$lhs.run._eql($rhs.run)
		}

		'&' => sub (Value $lhs, Value $rhs, --> Value) { $lhs=$lhs.run; $lhs.to_bool ?? $rhs.run !! $lhs },
		'|' => sub (Value $lhs, Value $rhs, --> Value) { $lhs=$lhs.run; $lhs.to_bool ?? $lhs !! $rhs.run },
		';' => sub (Value $lhs, Value $rhs, --> Value) { $lhs.run; $rhs.run },
		'=' => sub (Value $lhs, Value $rhs, --> Value) { die "eql" },
		W => sub (Value $cond, Value $body, --> Value) {
			my $ret = Null.new;
			$ret = $body.run while $cond;
			$ret;
		},

		I => sub ($cond, $iftrue, $iffalse) { $cond.run.to_bool ?? $iftrue.run !! $iffalse.run },
		G => sub ($str, $idx, $len) { die "todo: get"},
		S => sub ($str, $idx, $len, $repl) { die "todo: set"},
	);

	method new($name, *@args) {
		my $func = %FUNCS{$name} or die "unknown function '$name'";
		self.bless: :$func, args => @args
	}

	method run(--> Value) {
		$!func(|self.args);
	}
}

my &func = %Function::FUNCS{'+'};
#say func(Stri, 4;


#say 34.^methods.map(*.gist).grep(/<[A..Z]>/);
#say 34.BUILDALL: 3, 9;
#say 34.ACCEPTS ;
#say &sub(String.new("34\\"));
#.new("O", [Number.new(34)]).run

=finish
sub run(Str $input) {
	# my $match = Knight::Syntax.parse($source, actions => Knight::Syntax-Exec);
	die "todo";
}
