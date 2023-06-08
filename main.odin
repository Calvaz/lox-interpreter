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
    reader := io.Reader{}
    fmt.print("> ")

    for {
        buffer: [256]byte
        if bytes_r, err := os.read(os.stdin, buffer[:]); err != os.ERROR_NONE {
            fmt.println(err)
        }
        run(string(buffer[:]))
    }

    had_error = true
}

run :: proc(source: string) {
    fmt.printf("source: %v", source)
    scanner := new_scanner(source)
    defer destroy_scanner(&scanner)

    scan_tokens(&scanner)
    for t in scanner.tokens {
        fmt.println(t)
    }
}

error :: proc(line: u32, message: string) {
    report(line, "", message)
}

report :: proc(line: u32, location: string, message: string) {
    fmt.tprintf("[line %v] Error %v: %v", line, location, message)
}

