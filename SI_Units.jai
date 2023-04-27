#scope_export

// This struct represents a unit in the SI system
// For reference here is a video about why this is a vector and why it makes sense to model units like this
// https://www.youtube.com/watch?v=bI-FS7aZJpY
// Unit.factor represents a factor between the unit and its SI base unit
// Ie. in km factor = 1000, base unit is meter (length)

Unit :: struct 
{
	powers : [SI_Units.count] int;
	factor : Fraction;
	factor.numerator = 1;
	factor.denominator = 1;
}

None     : Unit : #run si("");
Meter    : Unit : #run si("m");
Second   : Unit : #run si("s");
Kilogram : Unit : #run si("kg");
Ampere   : Unit : #run si("A");
Kelvin   : Unit : #run si("K");
Mol      : Unit : #run si("mol");
Candela  : Unit : #run si("cd");


Fraction :: struct
{
	numerator   : int;
	denominator : int;
};


si :: (abbreviation : string) -> Unit
{
	result : Unit;
	for *result.powers 
	{
		if abbreviation == SI_Units[it_index].abbreviation  
		{
			<<it = 1;
		}
	}
	return result;
}

SI_Units :: Unit_Info.[
	// From Wikipedia
	.{"m", "meter", "length"},
	.{"s", "second", "time"},
	.{"kg", "kilogram", "mass"},
	.{"A", "ampere", "electric current"},
	.{"K", "kelvin", "thermodynamic temperature"},
	.{"mol", "mole", "ammount of substance"},
	.{"cd", "candela", "luminous instensity"}
];

Unit_Info :: struct
{
	abbreviation : string;
	name : string;
	property : string;
}


are_Equal_Up_To_Factor :: (a : Unit, b : Unit) -> bool
{

	same := true;
	for a.powers  same &= b.powers[it_index] == it;
	return same;
}

operator == :: (a : Unit, b : Unit) -> bool
{
	same := true;
	for a.powers  same &= b.powers[it_index] == it;
	same &= a.factor == b.factor;
	return same;
}

operator * :: (a : Unit, b : Unit) -> Unit
{
	r : Unit;
	for 0..SI_Units.count-1
	{
		r.powers[it] = a.powers[it] + b.powers[it];
	}
	r.factor = a.factor * b.factor;
	return r;
}

operator * :: (a : Unit, b : int) -> Unit #symmetric
{
	r : Unit = a;
	r.factor = a.factor * b;
	return r;
}

operator / :: (a : Unit, b : Unit) -> Unit
{
	r : Unit;
	for 0..SI_Units.count-1
	{
		r.powers[it] = a.powers[it] - b.powers[it];
	}
	r.factor = a.factor / b.factor;
	return r;
}

operator / :: (a : Unit, b : int) -> Unit
{
	r:= a;
	r.factor /= b;
	return r;
}

operator == :: (a : Fraction, b : Fraction) -> bool
{
	return a.numerator == b.numerator && a.denominator == b.denominator;
}

operator * :: (a : Fraction, b : Fraction) -> Fraction
{
	r : Fraction;
	r.numerator = a.numerator * b.numerator;
	r.denominator = a.denominator * b.denominator;

	return simplify(r);
}

operator / :: (a : Fraction, b : Fraction) -> Fraction
{
	r : Fraction;
	r.numerator = a.numerator * b.denominator;
	r.denominator = a.denominator * b.numerator;
	return simplify(r);
}

operator * :: (a : Fraction, b : int) -> Fraction #symmetric
{
	r := a;
	r.numerator *= b;
	return simplify(r);
}

operator / :: (a : Fraction, b : int) -> Fraction
{
	assert(b != 0, "Cant devide by 0, even in units");
	r := a;
	r.denominator *= b;
	return simplify(r);;
}

simplify :: (f : Fraction) -> Fraction
{
	using r := f;
	for 2..min(numerator,denominator)
	{
		while numerator % it == 0 && denominator % it == 0
		{
			numerator /= it;
			denominator /= it;
		}
	}
	return r;
}

#scope_file
#import "Basic";
