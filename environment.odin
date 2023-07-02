package interpreter

import "core:fmt"

@private
Environment :: struct {
    values: map[string]rawptr,
}

new_environment :: proc() -> Environment {
    return Environment { make(map[string]rawptr, 64) }
}

delete_environment :: proc(environment: ^Environment) {
    delete(environment.values)
}

define_value :: proc(environment: ^Environment, name: string, value: rawptr) {
    environment.values[name] = value
}

get_environment_value :: proc(environment: ^Environment, name: Token) -> (rawptr, Error) {
    if name.lexeme in environment.values {
        return environment.values[name.lexeme], .None
    }

    err := Runtime_Error{token = name, message = fmt.tprintf("Undefined variable'%v'.", name.lexeme)}
    runtime_error(err)
    return nil, err
}

