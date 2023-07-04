package interpreter

import "core:fmt"
import "core:mem"

Token :: struct {
    type: Token_Type,
    lexeme: string,
    line: u32,
    literal: Token_Value,
}

new_token :: proc(type: Token_Type, lexeme: string, line: u32, value: Token_Value) -> Token {
    return Token{ type = type, lexeme = lexeme, line = line, literal = value } 
}

to_string :: proc(token: ^Token) -> string {
    l: string = (cast(^string)(&token.literal))^
    return fmt.tprintf("%v %v %v", token.type, token.lexeme, l)
}
