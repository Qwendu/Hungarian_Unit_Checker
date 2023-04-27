

// Check 'first.jai' to see how units get defined in the meta program!

// A Constant for converting feet to meters
// Factors in the program are not checked by the unit checker, they are regarded as unit less
// But "foot_to_meter_conversion" is declared in the Unit.jai file as a conversion from foot to meter
// It is up to you to make sure those conversions make sense!
foot_to_meter_conversion :: 3048 / 10000; 

simple_units :: ()
{
	duration_s := 3;
	distance_a_m := 3;
	distance_b_m := distance_a_m; // Units match, both meters
	//distance_b_m = duration_s; // Uncomment this to get an error

	distance_far_km := 100; //_km is not defined in the suffixes!
	
	//The following is an error if converting_from_no_unit_to_unit_is_legal = false
	//distance_a_m = distance_far_km;  
} @UnitCheck

unit_and_arithmetic :: ()
{
	start_position_m := 100;
	end_position_m := 1300;

	//Same units can be added and subtracted
	distance_m := end_position_m - start_position_m;

	time_delta_s :=  10;
	// Different units can get multiplies and divided, Usual rules apply
	// m / s = meters per second
	velocity_mps := distance_m / time_delta_s;

	// Units can be multiplied just how you think it would work
	area_m2 := start_position_m * end_position_m;

	distance_foot := 3;

	// Units can only be multiplied if they have the same factor
	area_m2 = start_position_m * (distance_foot * foot_to_meter_conversion);
	// The following line will error, because the factors are different 
	// for _m2 and _foot * _m
	// area_m2 = start_position_m * distance_foot;
} @UnitCheck
