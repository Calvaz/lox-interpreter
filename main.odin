package interpreter

import "core:fmt"
import "core:os"
import "core:io"
import "core:strings"

had_error: bool = false

main :: proc() {
    args := os.args 
    fmt.println(args)

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
}

run_prompt :: proc() {
    fmt.print("> ")

    for {
        buffer: [256]u8
        bytes_r, err := os.read(os.stdin, buffer[:]);
        if err < 0 {
            fmt.println(err)
        }
        run(string(buffer[:bytes_r]))
    }

    had_error = true
}

run :: proc(source: string) {
    scanner := new_scanner(source)
    defer destroy_scanner(&scanner)

    scan_tokens(&scanner)
    if had_error {
        return
    }

    parser := new_parser(scanner.tokens)
    expr := parse(&parser)
}

error :: proc{scanner_error, parser_error}

scanner_error :: proc(line: u32, message: string) {
    report(line, "", message)
}

parser_error :: proc(token: Token, message: string) {
    if token.type == .Eof {
        report(token.line, " at end", message)
    } else {
        report(token.line, fmt.tprintf(" at '%v'", token.lexeme), message)
    }
}

report :: proc(line: u32, location: string, message: string) {
    fmt.tprintf("[line %v] Error %v: %v", line, location, message)
}

