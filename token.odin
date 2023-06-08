package interpreter

import "core:fmt"
import "core:mem"

Token :: struct {
    type: Token_Type,
    lexeme: string,
    literal: rawptr,
    line: u32,
}

new_token :: proc(type: Token_Type, lexeme: string, line: u32, value: rawptr) -> Token {
    fmt.println(value)
    return Token{ type, lexeme, value, line } 
}

to_string :: proc(token: ^Token) -> string {
    l: string = (cast(^string)(&token.literal))^
    return fmt.tprintf("%v %v %v", token.type, token.lexeme, l)
}
