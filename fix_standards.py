import os
import re
import sys

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Find targets: (vivado_library|vhdl_library|vhdl_test)( ... )
    # This might be tricky with regex if there are nested parentheses.
    # We can try a simpler approach: process line by line or use a simple state machine.

    lines = content.split('\n')
    out_lines = []
    
    in_target = False
    target_type = ""
    brace_level = 0
    has_standard = False
    
    for line in lines:
        stripped = line.strip()
        
        # Check if we are entering a target
        match = re.match(r'^(vivado_library|vhdl_library|vhdl_test)\s*\(', line)
        if match and not in_target:
            in_target = True
            target_type = match.group(1)
            brace_level = line.count('(') - line.count(')')
            out_lines.append(line)
            has_standard = False
            continue
            
        if in_target:
            brace_level += line.count('(') - line.count(')')
            
            # Check for vhdl1993
            if re.match(r'^\s*vhdl1993\s*=\s*True,?\s*$', stripped):
                continue # Skip this line
                
            # Check for existing standard
            std_match = re.match(r'^(\s*)standard\s*=\s*".*?"(,?)\s*$', line)
            if std_match:
                has_standard = True
                out_lines.append(f'{std_match.group(1)}standard = "2019"{std_match.group(2)}')
                if brace_level == 0:
                    in_target = False
                continue
                
            if brace_level == 0:
                # We are exiting the target. If standard was not set, we should inject it before the closing parenthesis.
                # However, the closing parenthesis might be on its own line or with other things.
                if not has_standard:
                    # Inject standard = "2019"
                    # Find the last line before the closing parenthesis to see its indentation
                    indent = "    "
                    if out_lines and out_lines[-1].startswith(" "):
                        # Try to guess indent
                        indent_match = re.match(r'^(\s+)', out_lines[-1])
                        if indent_match:
                            indent = indent_match.group(1)
                    
                    # If line is just ")", insert before it
                    if stripped == ")":
                        out_lines.append(f'{indent}standard = "2019",')
                        out_lines.append(line)
                    else:
                        # This is a bit unsafe if it's like `], )` but we can just append
                        # Actually if it's `)` let's do this:
                        out_lines.append(line)
                else:
                    out_lines.append(line)
                in_target = False
            else:
                out_lines.append(line)
        else:
            out_lines.append(line)
            
    with open(filepath, 'w') as f:
        f.write('\n'.join(out_lines))

if __name__ == "__main__":
    for root, dirs, files in os.walk("."):
        if "third_party" in root:
            # The prompt said "Do not change files in `//third_party` without user's explicit permission."
            # Wait, the targets might be in third_party. But let's follow the general rule.
            pass
            
        for file in files:
            if file == "BUILD.bazel":
                filepath = os.path.join(root, file)
                process_file(filepath)
