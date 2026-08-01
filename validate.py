import os
import re

missing = []

for root, dirs, files in os.walk("."):
    if "third_party" in root:
        continue
    if "BUILD.bazel" in files:
        filepath = os.path.join(root, "BUILD.bazel")
        with open(filepath, 'r') as f:
            content = f.read()
        
        lines = content.split('\n')
        in_target = False
        target_name = ""
        has_standard = False
        brace_level = 0
        
        for line in lines:
            if re.match(r'^(vivado_library|vhdl_library|vhdl_test)\s*\(', line):
                in_target = True
                brace_level = line.count('(') - line.count(')')
                has_standard = False
                continue
                
            if in_target:
                brace_level += line.count('(') - line.count(')')
                name_match = re.match(r'^\s*name\s*=\s*"([^"]+)"', line)
                if name_match:
                    target_name = name_match.group(1)
                    
                if re.match(r'^\s*standard\s*=\s*"2019"', line):
                    has_standard = True
                    
                if brace_level == 0:
                    if not has_standard:
                        missing.append(f"{filepath}: {target_name}")
                    in_target = False

if missing:
    print("Targets missing standard = '2019':")
    for m in missing:
        print(m)
else:
    print("All targets have standard = '2019'!")
