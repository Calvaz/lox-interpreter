package interpreter


Error :: union {
    Parse_Error,
    Error_Types,
}

Error_Types :: enum {
    None,
}

Parse_Error :: struct {
    token: Token,
    message: string,
}
