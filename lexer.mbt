///|
struct Token {
  text : String
  line : Int
  column : Int
} derive(Eq, Debug)

///|
struct Statement {
  tokens : Array[Token]
  indented : Bool
  line : Int
} derive(Debug)

///|
struct LexResult {
  statements : Array[Statement]
  diagnostics : Array[Diagnostic]
} derive(Debug)

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r'
}

///|
fn flush_token(
  tokens : Array[Token],
  builder : StringBuilder,
  active : Bool,
  line : Int,
  column : Int,
) -> Unit {
  if active {
    tokens.push({ text: builder.to_string(), line, column })
  }
}

///|
/// Lex RFC 1035 master-file statements, retaining locations and inherited-owner indentation.
fn lex_zone(input : String) -> LexResult {
  let chars = input.to_array()
  let statements : Array[Statement] = []
  let diagnostics : Array[Diagnostic] = []
  let mut tokens : Array[Token] = []
  let mut builder = StringBuilder::new()
  let mut active = false
  let mut quoted = false
  let mut escaped = false
  let mut comment = false
  let mut depth = 0
  let mut line = 1
  let mut column = 1
  let mut token_line = 1
  let mut token_column = 1
  let mut statement_line = 1
  let mut indented = false
  let mut at_line_start = true
  for c in chars {
    if c == '\n' {
      if escaped {
        builder.write_char(c)
        escaped = false
      } else if quoted {
        diagnostics.push(diagnostic("Z001", "error", "unterminated quoted text", token_line, token_column))
        quoted = false
        flush_token(tokens, builder, active, token_line, token_column)
        builder = StringBuilder::new()
        active = false
      } else {
        flush_token(tokens, builder, active, token_line, token_column)
        builder = StringBuilder::new()
        active = false
      }
      comment = false
      if depth == 0 && tokens.length() > 0 {
        statements.push({ tokens, indented, line: statement_line })
        tokens = []
      }
      line += 1
      column = 1
      at_line_start = true
      if depth == 0 {
        statement_line = line
        indented = false
      }
      continue
    }
    if comment {
      column += 1
      continue
    }
    if at_line_start {
      if is_space(c) {
        if depth == 0 && tokens.length() == 0 {
          indented = true
        }
      } else {
        at_line_start = false
      }
    }
    if escaped {
      builder.write_char(c)
      escaped = false
      column += 1
      continue
    }
    if c == '\\' {
      if !active {
        token_line = line
        token_column = column
        active = true
      }
      builder.write_char(c)
      escaped = true
      column += 1
      continue
    }
    if c == '"' {
      if !active {
        token_line = line
        token_column = column
        active = true
      }
      quoted = !quoted
      builder.write_char(c)
      column += 1
      continue
    }
    if !quoted && c == ';' {
      flush_token(tokens, builder, active, token_line, token_column)
      builder = StringBuilder::new()
      active = false
      comment = true
      column += 1
      continue
    }
    if !quoted && (c == '(' || c == ')') {
      flush_token(tokens, builder, active, token_line, token_column)
      builder = StringBuilder::new()
      active = false
      if c == '(' {
        depth += 1
      } else if depth == 0 {
        diagnostics.push(diagnostic("Z002", "error", "unmatched closing parenthesis", line, column))
      } else {
        depth -= 1
      }
      column += 1
      continue
    }
    if !quoted && is_space(c) {
      flush_token(tokens, builder, active, token_line, token_column)
      builder = StringBuilder::new()
      active = false
      column += 1
      continue
    }
    if !active {
      token_line = line
      token_column = column
      active = true
    }
    builder.write_char(c)
    column += 1
  }
  if escaped {
    diagnostics.push(diagnostic("Z003", "error", "unfinished escape", token_line, token_column))
  }
  if quoted {
    diagnostics.push(diagnostic("Z001", "error", "unterminated quoted text", token_line, token_column))
  }
  if depth > 0 {
    diagnostics.push(diagnostic("Z004", "error", "unclosed parenthesis", statement_line, 1))
  }
  flush_token(tokens, builder, active, token_line, token_column)
  if tokens.length() > 0 {
    statements.push({ tokens, indented, line: statement_line })
  }
  { statements, diagnostics }
}
