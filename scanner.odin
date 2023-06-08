package interpreter

import "core:fmt"

import "core:strconv"
import "core:builtin"

keywords: map[string]Token_Type = map[string]Token_Type {
    "and" = .And,
    "class" = .Class,
    "else" = .Else,
    "false" = .False,
    "for" = .For,
    "fn" = .Fun,
    "if" = .If,
    "nil" = .Nil,
    "or" = .Or,
    "print" = .Print,
    "return" = .Return,
    "super" = .Super,
    "this" = .This,
    "true" = .True,
    "var" = .Var,
    "while" = .While,
}

@private
Scanner :: struct {
    source: string,
    tokens: [dynamic]Token,
}

@private start := 0
@private current := 0
@private line: u32 = 1

new_scanner :: proc(source: string) -> Scanner {
    tokens := make([dynamic]Token)
    start = 0
    current = 0
    line = 1
    return Scanner { source, tokens }
}

scan_tokens :: proc(scanner: ^Scanner) -> [dynamic]Token {
    for !is_at_end(scanner) {
        start = current;
        scan_token(scanner);
    }

    append(&scanner.tokens, new_token(.Eof, " ", line, rawptr(uintptr(0))))
    return scanner.tokens
}

destroy_scanner :: proc(scanner: ^Scanner) {
    delete(scanner.tokens)
}

@private
scan_token :: proc(scanner: ^Scanner) {
    c := advance(scanner)
    switch (c) {
        case '(': add_token(scanner, .Left_Paren)
        case ')': add_token(scanner, .Right_Paren)
        case '{': add_token(scanner, .Left_Brace)
        case '}': add_token(scanner, .Right_Brace)
        case ',': add_token(scanner, .Comma)
        case '.': add_token(scanner, .Dot)
        case '-': add_token(scanner, .Minus)
        case '+': add_token(scanner, .Plus)
        case ';': add_token(scanner, .Semicolon)
        case '*': add_token(scanner, .Star)
        case '!': add_token(scanner, is_next_equal_to(scanner, '=') ? .Bang_Equal : .Bang)
        case '=': add_token(scanner, is_next_equal_to(scanner, '=') ? .Equal_Equal : .Equal)
        case '<': add_token(scanner, is_next_equal_to(scanner, '=') ? .Less_Equal : .Equal)
        case '>': add_token(scanner, is_next_equal_to(scanner, '=') ? .Greater_Equal : .Equal)
        case '/': {
            if is_next_equal_to(scanner, '/') {
                for look_ahead(scanner) != '\n' && !is_at_end(scanner) {
                    advance(scanner)
                }
            } else {
                add_token(scanner, .Slash)
            }
        }
        case '\r':
        case 'o': if is_next_equal_to(scanner, 'r') { add_token(scanner, .Or) }
        case ' ':
        case '\t':
        case '\n': line += 1

        case '"': add_string(scanner)
        
        case: {
            if is_digit(scanner, c) {
                add_number(scanner)
            } else if is_alpha(scanner, c) {
                add_keyword(scanner)
            } else {
                error(line, fmt.tprintf("Unexpected character %v", c))
                error(line, fmt.tprintf("Unexpected character: %v", c))
            }
        }
    }
    fmt.println(c)
}

@private
advance :: proc(scanner: ^Scanner) -> rune {
    current += 1
    for r, i in scanner.source {
        if i == current - 1 {
            return r
        }
    }
    return '0'
}

@private
add_token :: proc(scanner: ^Scanner, type: Token_Type) {
    add_token_to_scanner(scanner, type, rawptr(uintptr(0)))
}

@private
add_token_to_scanner :: proc(scanner: ^Scanner, type: Token_Type, value: rawptr) {
    text := scanner.source[start:current]
    token := new_token(type, text, line, value)
    fmt.println(token)
    append(&scanner.tokens, token)
}

@private
is_at_end :: proc(scanner: ^Scanner) -> bool {
    return current >= len(scanner.source)
}

@private
is_next_equal_to :: proc(scanner: ^Scanner, expected: rune) -> bool {
    if is_at_end(scanner) { return false }

    for r, i in scanner.source {
        if i == current {
            if r != expected {
                return false
            }
            break
        }
    }

    current += 1
    return true
}

@private
look_ahead :: proc(scanner: ^Scanner) -> rune {
    if is_at_end(scanner) { return '0' }

    for r, i in scanner.source {
        if i == current {
            return r
        }
    }

    return '0'
}

@private
look_ahead_next :: proc(scanner: ^Scanner) -> rune {
    if current + 1 >= len(scanner.source) { return '0' }

    for r, i in scanner.source {
        if i == current + 1 {
            return r
        }
    }

    return '0'
}

add_string :: proc(scanner: ^Scanner) {
    for look_ahead(scanner) != '"' && !is_at_end(scanner) {
        if look_ahead(scanner) == '\n' { line += 1 }
        advance(scanner)
    }

    if is_at_end(scanner) {
        error(line, "Unterminated string")
        return 
    }

    advance(scanner)
    
    value := scanner.source[start + 1:current - 1]
    add_token_to_scanner(scanner, .String, rawptr(&value))
}

is_digit :: proc(scanner: ^Scanner, char: rune) -> bool {
    return char >= '0' && char <= '9'
}

is_alpha :: proc(scanner: ^Scanner, char: rune) -> bool {
    return (char >= 'a' && char <= 'z') ||
        (char >= 'A' && char <= 'Z') ||
        char == '_'
}

is_alphanumeric :: proc(scanner: ^Scanner, char: rune) -> bool {
    return is_alpha(scanner, char) || is_digit(scanner, char)
}

add_number :: proc(scanner: ^Scanner) {
    for is_digit(scanner, look_ahead(scanner)) { advance(scanner) }

    if look_ahead(scanner) == '.' && is_digit(scanner, look_ahead_next(scanner)) {
        advance(scanner)

        for is_digit(scanner, look_ahead(scanner)) { advance(scanner) }
    }

    val_f64, ok := strconv.parse_f64(scanner.source[start:current])
    if !ok {
        error(line, "Not a valid decimal")
        return
    }

    add_token_to_scanner(scanner, .Number, rawptr(&val_f64))
}

add_keyword :: proc(scanner: ^Scanner) {
    for is_alphanumeric(scanner, look_ahead(scanner)) { advance(scanner) }

    text := scanner.source[start:current]
    type, ok := keywords[text]
    if !ok {
        // it's a variable
        type = .Identifier
    }
    add_token(scanner, type)
}

