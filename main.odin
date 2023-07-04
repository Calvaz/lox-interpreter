package interpreter

import "core:fmt"
import "core:os"
import "core:io"
import "core:strings"

interpreter: Interpreter = { new_environment() }
had_error: bool = false
had_runtime_error: bool = false

main :: proc() {
    args := os.args 
    fmt.println(args)
    //defer delete_environment(&interpreter.environment)

    if len(args) > 2 {
        fmt.println("using jlox script")

    } else if len(args) == 2 {
        run_file(args[1])
    
    } else {
        run_prompt();
    }
}

run_file :: proc(path: string) {
    file: []byte
    if file, success := os.read_entire_file_from_filename(path); !success {
        fmt.printf("Could not read file %v")
        return
    }

    run(transmute(string)file)

    if had_error {
        os.exit(65)
    }
    if had_runtime_error {
        os.exit(70)
    }
}

run_prompt :: proc() {
    fmt.print("> ")

    for {
        buffer: [256]u8
        bytes_r, err := os.read(os.stdin, buffer[:]);
        if err < 0 {
            fmt.println(fmt.tprintf("Error while reading the file: %v", err))
        }
        run(string(buffer[:bytes_r]))
    }

    had_error = true
}

run :: proc(source: string) {
    inte := &interpreter.environment
    scanner := new_scanner(source)
    //defer destroy_scanner(&scanner)

    scan_tokens(&scanner)
    if had_error {
        return
    }

    parser := new_parser(scanner.tokens)
    //defer delete_parser(&parser)

    statements := parse(&parser)
    //defer delete(statements)
    if had_error {
        return
    }

    interpret(&interpreter, statements)
    a := 1
}

error :: proc{scanner_error, parser_error, runtime_error}

scanner_error :: proc(line: u32, message: string) {
    report(line, "", message)
}

parser_error :: proc(token: Token, message: string) {
    if token.type == .Eof {
        report(token.line, "at end", message)
    } else {
        report(token.line, fmt.tprintf("at '%v'", token.lexeme), message)
    }
}

runtime_error :: proc(err: Runtime_Error) {
    fmt.println(fmt.tprintf("%v\n[line %v]", err.message, err.token.line))
    had_runtime_error = true
}

report :: proc(line: u32, location: string, message: string) {
    fmt.println(fmt.tprintf("[line %v] Error %v: %v", line, location, message))
}

