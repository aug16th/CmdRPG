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
    add_build_file("main.jai", w);

    collected_names: [..] string;
    injected := false;

    while true {
    message := compiler_wait_for_message();
    if message.workspace != w continue;

    if message.kind == {
        case .TYPECHECKED;
            tc := cast(*Message_Typechecked) message;
            for tc.declarations {
                decl := it.expression;
                for decl.notes {
                    if it.text == "GameCommand" {
                        array_add(*collected_names, decl.name);
                    }
                }
            }

        case .COMPLETE;
            if !injected {
                builder: String_Builder;
                append(*builder, "init_commands :: () {\n");
                for collected_names {
                    print_to_builder(*builder, "    register_command(\"%\", %);\n", it, it);
                }
                append(*builder, "}\n");

                generated_code := builder_to_string(*builder);
                add_build_string(generated_code, w);

                injected = true;
            } else {
                break;   // second COMPLETE: the generated code is done too, truly finished
            }
    }
}

    compiler_end_intercept(w);
}
#run build();