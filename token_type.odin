package interpreter

Token_Type :: enum {
    Left_Paren, Right_Paren, Left_Brace, Right_Brace,
    Comma, Dot, Minus, Plus, Semicolon, Slash, Star,

    Question, Colon,

    Bang, Bang_Equal,
    Equal, Equal_Equal,
    Greater, Greater_Equal,
    Less, Less_Equal,

    Identifier, String, Number,

    And, Class, Else, False, Fun, For, If, Nil, Or,
    Print, Return, Super, This, True, Var, While,

    Eof,
}

