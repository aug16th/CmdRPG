#import "Basic";
#import "Compiler";
#import "String";

build :: () {
    print("build() called\n");
    set_build_options_dc(.{do_output=false});  // this script itself produces no executable

    w := compiler_create_workspace("Target Program");
    options := get_build_options(w);
    options.output_executable_name = "CmdRPG";
    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file("Source/main.jai", w);

    collected_names: [..] string;
    injected := false;

    while true {
        message := compiler_wait_for_message();
        if message.workspace != w continue;

        if message.kind == {
            case .TYPECHECKED;
                // Remember every declaration tagged @GameCommand.
                tc := cast(*Message_Typechecked) message;
                for tc.declarations {
                    decl := it.expression;
                    for decl.notes {
                        if it.text == "GameCommand" {
                            // Copy: the compiler owns decl.name and it may not outlive this message.
                            array_add_if_unique(*collected_names, copy_string(decl.name));
                        }
                    }
                }

            case .PHASE;
                // The compiler has typechecked everything it can. main() calls
                // init_commands(), which doesn't exist yet, so this is where we add it.
                // (Injecting at .COMPLETE is too late: compilation is already over.)
                phase := cast(*Message_Phase) message;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN && !injected {
                    if collected_names.count == 0 {
                        print("build.jai warning: no @GameCommand procedures found.\n");
                    }

                    builder: String_Builder;
                    append(*builder, "init_commands :: () {\n");
                    for collected_names {
                        print_to_builder(*builder, "    register_command(\"%1\", %1);\n", it);
                    }
                    append(*builder, "}\n");

                    generated_code := builder_to_string(*builder);
                    print("Generated:\n%", generated_code);
                    add_build_string(generated_code, w);

                    injected = true;
                }

            case .COMPLETE;
                break;  // compilation finished, generated code included
        }
    }

    compiler_end_intercept(w);
}

#run build();