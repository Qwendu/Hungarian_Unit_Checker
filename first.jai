/*
This is an example of how to integrate the Unit checker into your
own meta program.
Note that the checker can be called on every already typechecked function.

The Unit Checker uses Hungarian Notation to recognize units of variables, and does
basically no unit inference (currently only for assignments in a for expansions, to give units to the iterator)
*/

#import "Basic";
#import,file "SI_Units.jai";
// @Bug type deduction in module parameters causes crash 
UNITS :: #import,file "Unit.jai"(
	discarding_unit_information_is_legal = true,
	converting_from_no_unit_to_unit_is_legal = false
); 

#run
{
	JC.set_build_options_dc(.{do_output = false});
	w:= JC.compiler_create_workspace();
	defer JC.compiler_destroy_workspace(w);

	o := JC.get_build_options(w);
	JC.set_optimization_level(*o, 1, 0);
	o.output_type = .NO_OUTPUT;
	JC.set_build_options(o, w);

	JC.compiler_begin_intercept(w);
	JC.add_build_file("to_verify.jai", w);
	defer JC.compiler_end_intercept(w);

	while true
	{
		msg := JC.compiler_wait_for_message();
		if msg.kind == .COMPLETE  break;
	
		if msg.kind == .TYPECHECKED
		{
			tm := cast(*JC.Message_Typechecked)msg;
			for tm.procedure_bodies
			{
				// Check every already typechecked procedure
				UNITS.unit_Check(it.expression); 
			}
		}
	}
}





JC :: #import "Compiler";
