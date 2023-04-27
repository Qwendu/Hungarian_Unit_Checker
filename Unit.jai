#scope_export

#module_parameters(
	discarding_unit_information_is_legal : bool = true,
	converting_from_no_unit_to_unit_is_legal : bool = true
);

suffix_meaning := Unit_Of_Suffix.[
	.{"_m", Meter},
	.{"_s", Second},
	.{"_km", #run 1000 * Meter},
	.{"_foot", #run 3048 * si("m") / 10000},
	.{"_m2", #run si("m") * si("m")}
];


conversions := Unit_Of_Suffix.[
	.{"foot_to_meter_conversion", #run 10_000 * None / 3048}
];


// This function should be called by you with a valid procedure body
// It will halt compilation if an obvious violation of unit conversions gets detected
unit_Check :: (body : *Jai.Code_Procedure_Body)
{
	if !has_Note(body.header.notes, "UnitCheck") return;
	new_context := context;
	new_context.print_style.struct_printer = pretty_printer;
	
	push_context new_context
	{
		bindings : Variable_Unit_Map;
		for arg : body.header.arguments
		{
			add_Binding_From_Suffix(*bindings, arg.name);
		}
		for local_variable : body.block.members
		{
			add_Binding_From_Suffix(*bindings, local_variable.name);
		}
		for statement : body.block.statements
		{
			unit, valid := check_Unit(*bindings, statement);
		}
	}
}


Unit_Of_Suffix :: struct
{
	suffix : string;
	unit : Unit;
}

add_Suffix :: (suffix : string, unit : Unit)
{
	association :  Unit_Associated_String;
	association.suffix = suffix;
	association.unit = unit;
	array_add(*suffix_meaning,  association);
}

#scope_file

check_Unit :: (binding : *Variable_Unit_Map, node : *Jai.Code_Node) -> Unit, bool
{
	if node.kind == 
	{
	case .IF;
		branch := cast(*Jai.Code_If)node;
		assert(branch.is_switch_statement == false, "We do not handle switch statements yet!\n");
		unit, valid:= check_Unit(binding, branch.condition);
		print("Unit of condition %\n", unit);
		if branch.then_block  check_Unit(binding, branch.then_block);
		if branch.else_block  check_Unit(binding, branch.else_block);
		return unit, valid;
	case .FOR;
		for_ := cast(*Jai.Code_For)node;
		unit_it_expr, valid_it_expr := check_Unit(binding, for_.iteration_expression);

		if for_.iteration_expression_right
		{
			unit_it_expr_right, valid_it_expr_right := check_Unit(binding, for_.iteration_expression_right);
			if !operation_Valid(binding, unit_it_expr, for_.iteration_expression, unit_it_expr_right, for_.iteration_expression_right, for_,#char "=")
			{
				return .{}, false;
			}
		}
		for_binding := copy(<<binding);
		// @Incomplete scan names for suffixes and match there too
		if for_.ident_decl  add_Binding(*for_binding, for_.ident_decl.name, unit_it_expr);
		if for_.index_decl  add_Binding(*for_binding, for_.index_decl.name, .{});

		unit, valid := check_Unit(*for_binding, for_.block);
		if !valid  return .{}, false;
		return unit, valid;
	case .WHILE;
		while_ := cast(*Jai.Code_While)node;
		unit_cond, valid_cond := check_Unit(binding, while_.condition);
		if !valid_cond  return .{}, false;
		unit_block, valid_block := check_Unit(binding, while_.block);
		return unit_block, valid_block;
	case .CASE;
		case_ := cast(*Jai.Code_Case)node;
		if case_.condition
		{
			unit_cond , valid_cond := check_Unit(binding, case_.condition);
			if !valid_cond  return .{}, false;
		}
		unit_block, valid_block := check_Unit(binding, case_.then_block);
		return unit_block, valid_block;
	case .BLOCK;
		block := cast(*Jai.Code_Block)node;
		if block.block_type == .IMPERATIVE
		{
			if block.owning_statement  print("owned by %\n", block.owning_statement.kind);
			block_binding := copy(<<binding);
			for entry : block.members
			{
				add_Binding_From_Suffix(*block_binding, entry.name);
			}
			for statement : block.statements
			{
				unit, valid := check_Unit(*block_binding, statement);
				if !valid  return .{}, false;
			}
		}
		return .{}, true;
	case .IDENT;
		ident := cast(*Jai.Code_Ident)node;
		unit, found := lookup_Variable(binding, ident.name);
		if found  return unit, true;
		unit, found = lookup_Conversion(ident.name);
		if found  return unit, true;
		return .{}, false;
	case .DECLARATION;
		decl := cast(*Jai.Code_Declaration)node;
		unit := lookup_Variable(binding, decl.name);
		if decl.expression
		{
			expr_unit, valid := check_Unit(binding, decl.expression);
			valid &= operation_Valid(binding, unit, node, expr_unit, decl.expression, node, #char "=");
			if valid
			{
				if expr_unit ==  .{}
				{
					return unit, true;
				}else if expr_unit == unit {
					return unit, true;
				}else{

					return .{}, false;
				}
			}
		}
		return unit, true;
	case .BINARY_OPERATOR;
		binop := cast(*Jai.Code_Binary_Operator)node;
		left_unit,  left_valid  := check_Unit(binding, binop.left);
		right_unit, right_valid := check_Unit(binding, binop.right);
		if !left_valid || !right_valid  return .{}, false;
		valid := operation_Valid(binding, left_unit, binop.left, right_unit, binop.right,node, binop.operator_type);
		
		if binop.operator_type == 
		{
		case #char "*";
			return left_unit * right_unit, valid;
		case #char "/";
			return left_unit / right_unit, valid;
		case;
			return left_unit, valid;
		}
	case .LITERAL;
		return .{}, true;
	case;
		return .{}, true;
	}
	return .{}, true;
}




/*
: Unit_Of_Suffix.[
	.{"_m",    #run si("m")},
	.{"_s",    #run si("s")},
	.{"_mol",  #run si("mol")},
	.{"_m2",   #run si("m") * si("m")},
	.{"_km3",  #run si("m") * si("m") * si("m")},
	.{"_mps",  #run si("m") / si("s")},
	.{"_kgm2", #run si("kg") * si("m") * si("m")},
	.{"_km",   #run si("m") * 1000},
	.{"_kph",  #run si("m") * 1000 / (si("s") * 3600)},
	.{"_foot", #run 3048 * si("m") / 10000}
];*/


Variable_Unit_Map :: struct
{
	data : [..] Unit_Binding;
}

copy :: (binding : Variable_Unit_Map) -> Variable_Unit_Map
{
	r := binding;
	array_copy(*r.data, binding.data);
	return r;
}

Unit_Binding :: struct
{
	variable_name : string;
	unit : Unit;
}


operation_Valid :: (
	bindings : *Variable_Unit_Map, 
	a_unit : Unit, a_node : *Jai.Code_Node,
	b_unit : Unit, b_node : *Jai.Code_Node,
	operation_node : *Jai.Code_Node,
	operation : Jai.Operator_Type.loose) -> bool
{
	are_assignment :bool = false;

	left_is_literal := false;
	if a_node  left_is_literal = a_node.kind == .LITERAL;
	right_is_literal := false;
	if b_node  right_is_literal = b_node.kind == .LITERAL;

	if operation == 
	{
	// Comparisons
	case xx Jai.Operator_Type.IS_EQUAL;       #through;
	case xx Jai.Operator_Type.IS_NOT_EQUAL;   #through;
	case xx Jai.Operator_Type.LESS_EQUALS;    #through;
	case xx Jai.Operator_Type.GREATER_EQUALS; #through;
	case #char "<";                           #through;
	case #char ">";                           #through;

	// Assignments
	case xx Jai.Operator_Type.PLUS_EQUALS;  #through;
	case xx Jai.Operator_Type.MINUS_EQUALS; #through;
	case xx Jai.Operator_Type.TIMES_EQUALS; #through;
	case xx Jai.Operator_Type.DIV_EQUALS;   #through;
	case xx Jai.Operator_Type.MOD_EQUALS;   #through;
	case #char "="; 
		are_assignment = true;
		#through;
	
	// Arithmetic add and sub
	case #char "+"; #through;
	case #char "-";
		if a_unit == .{} && b_unit != .{} && are_assignment && !left_is_literal
		{
			if !discarding_unit_information_is_legal
			{
				discard_error := tprint("Discarding unit [%].\nThis has been disallowed!\n", b_unit);
				Jai.compiler_report(operation_node.enclosing_load.fully_pathed_filename, operation_node.location.l0, operation_node.location.c0, discard_error, .ERROR);
			}
		}
		if a_unit != .{} && b_unit == .{} && are_assignment && !right_is_literal
		{
			if !converting_from_no_unit_to_unit_is_legal
			{
				conversion_error := tprint("Converting to unit [%] while value has no unit is illegal!\nThis has been disallowed!\n", a_unit);
				Jai.compiler_report(operation_node.enclosing_load.fully_pathed_filename, operation_node.location.l0, operation_node.location.c0, conversion_error, .ERROR);
			}
		}
		if a_unit == .{} || b_unit == .{}  return true;
		if a_unit != b_unit
		{
			if a_node
			{
				error := tprint("Left hand side is this, Unit %", a_unit);
				Jai.compiler_report(a_node.enclosing_load.fully_pathed_filename,
					a_node.location.l0, a_node.location.c0,
					error, .INFO);
			}
			if b_node
			{
				error := tprint("Right hand side is this, Unit %", b_unit);
				Jai.compiler_report(b_node.enclosing_load.fully_pathed_filename,
					b_node.location.l0, b_node.location.c0,
					error, .INFO);
			}
			error := tprint("Cannot convert unit % to %:", b_unit, a_unit);
			Jai.compiler_report(
				operation_node.enclosing_load.fully_pathed_filename,
				operation_node.location.l0, operation_node.location.c0,
				error);
			return false;
		}
	case #char "*";
		/*
		if a_unit.factor != b_unit.factor && are_Equal_Up_To_Factor(a_unit, b_unit)
		{
			error_string := tprint("Cannot multiply units % and % as factors are different! Did you miss a unit conversion?\n", a_unit, b_unit);
			Jai.compiler_report(operation_node.enclosing_load.fully_pathed_filename,
			operation_node.location.l0, operation_node.location.c0,
			error_string);
		}
		*/
		return true;
	case #char "/";
		return true;
	case;
	}
	return true;
}

lookup_Variable :: (map : *Variable_Unit_Map, name :string) -> Unit, bool
{
	for map.data
	{
		if it.variable_name == name  return it.unit, true;
	}
	return .{}, false;
}

lookup_Conversion :: (name : string) -> Unit, bool
{
	for conversions  if it.suffix == name  return it.unit, true;
	return .{}, false;
}

add_Binding_From_Suffix :: (map : *Variable_Unit_Map, name : string)
{
	binding : Unit_Binding;
	binding.variable_name = copy_string(name);
	for suffix_meaning
	{
		if ends_with(name, it.suffix) binding.unit = it.unit;
	}
	array_add(*map.data, binding);
}

add_Binding :: (map : *Variable_Unit_Map, name : string, unit : Unit)
{
	binding : Unit_Binding;
	binding.variable_name = copy_string(name);
	binding.unit = unit;
	array_add(*map.data, binding);
}

pretty_printer :: (builder : *String_Builder, any : Any, data : *void) -> bool
{
	if any.type == type_info(Unit)
	{
		print_Unit_To_Builder(builder, <<cast(*Unit)any.value_pointer);
		return true;
	}else if any.type == type_info(Fraction)
	{
		print_Fraction_To_Builder(builder, <<cast(*Fraction)any.value_pointer);
		return true;
	}else if any.type == type_info(Variable_Unit_Map)
	{
		print_Variable_Unit_Map_To_Builder(builder, <<cast(*Variable_Unit_Map)any.value_pointer);
		return true;
	}
	return false;
}

print_Unit_To_Builder :: (builder :*String_Builder, unit : Unit)
{
	print_to_builder(builder, "% ", unit.factor);
	numerator_printed := false;
	for unit.powers
	{
		if it > 0
		{
			if numerator_printed print_to_builder(builder, " ");
			numerator_printed = true;
			print_to_builder(builder, "%", SI_Units[it_index].abbreviation);
			if it > 1 print_to_builder(builder, "^%", it);
		}
	}
	if !numerator_printed  print_to_builder(builder,"1");
	denominator_exists := false;
	for unit.powers  denominator_exists |= it < 0;
	if denominator_exists
	{
		denominator_first := true;
		print_to_builder(builder,"/");
		for unit.powers
		{
			if it < 0
			{
				if !denominator_first print_to_builder(builder, " ");
				denominator_first = false;
				print_to_builder(builder, "%", SI_Units[it_index].abbreviation);
				if it < -1 print_to_builder(builder, "^%", it);
			}
		}
	}
}

print_Fraction_To_Builder :: (builder : *String_Builder, fraction : Fraction)
{
	if fraction.denominator == 1
	{
		print_to_builder(builder, "%", fraction.numerator);
	}else{
		print_to_builder(builder, "%/%", fraction.numerator, fraction.denominator);		}
}

print_Variable_Unit_Map_To_Builder :: (builder : *String_Builder, map : Variable_Unit_Map)
{
	longest_name_length := 0;
	for map.data  longest_name_length = max(longest_name_length, it.variable_name.count);
	for map.data
	{
		append(builder, it.variable_name);
		for 0..longest_name_length-it.variable_name.count
		{
			append(builder, " ");
		}
		append(builder, " | ");
		print_to_builder(builder, "%\n", it.unit);
	}
}

Jai :: #import "Compiler";
#import "Basic";
#import "String";

has_Note :: (notes : []*Jai.Code_Note, note_string : string) -> bool
{
	for notes
	{
		if it.text == note_string  return true;
	}
	return false;
}
#import, file "SI_Units.jai";
