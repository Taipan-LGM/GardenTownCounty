with open('lib/l10n/app_strings.dart','r') as f:
    content = f.read()
lines = content.split('\n')

# Check for multi-line single-quoted strings (which are illegal in Dart)
# and any other structural issues
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    
    # Skip blank lines, comments, class declarations
    if not stripped or stripped.startswith('//') or stripped.startswith('class ') or stripped.startswith('part of') or stripped.startswith('import '):
        i += 1
        continue
    
    # Check for lines that look like they're inside a class but don't start with valid patterns
    # Valid patterns: "String get", "}", "String ", etc.
    valid_start = (
        stripped.startswith('String get') or 
        stripped.startswith('String ') or
        stripped.startswith('}') or
        stripped.startswith('///') or
        stripped.startswith('  //') or
        stripped.startswith('String ') or
        stripped == '' or
        stripped.startswith('  ///') or
        stripped.startswith('  /*') or
        stripped.startswith('  }') or
        stripped.startswith('  )') or
        stripped.startswith('  if') or
        stripped.startswith('  for') or
        stripped.startswith('  return') or
        stripped.startswith('  case') or
        stripped.startswith('  break') or
        stripped.startswith('  default') or
        stripped.startswith('  throw') or
        stripped.startswith('  final') or
        stripped.startswith('  var') or
        stripped.startswith('  const') or
        stripped.startswith('  late') or
        stripped.startswith('  static') or
        stripped.startswith('  late final') or
        stripped.startswith('  Future') or
        stripped.startswith('  )') or
        stripped.startswith('  {' ) or
        stripped.startswith('  } //') or
        stripped.startswith('  } // ') or
        stripped.startswith('  ///') or
        stripped.startswith('  /*') or
        stripped.startswith('    ')  # indented continuation
    )
    
    if not valid_start and i > 10:  # skip past imports
        print(f'Line {i+1}: UNEXPECTED: {repr(stripped[:120])}')
    
    i += 1
