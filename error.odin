package interpreter


Error :: union #no_nil { 
    Parse_Error,
    Runtime_Error,
    Error_Types,
}

Error_Types :: enum {
    None,
    Cast,
}

Parse_Error :: struct {
    token: Token,
    message: string,
}

Runtime_Error :: struct {
    token: Token,
    message: string,
}
