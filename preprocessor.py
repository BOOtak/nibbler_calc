import sys

class AsmLine:
    line = ""
    num = 0
    is_comment = False
    is_label = False
    is_local_label = False
    is_define = False
    is_instruction = False
    opcode = ""
    params = []
    name = ""
    value = ""
    local_label = ""

    def __init__(self, text_line, num):
        self.line = text_line.strip("\n")
        self.num = num
        if self.line.startswith("+") or self.line.startswith("-"):
            self.is_local_label = True
            self.local_label = self.line.split(" ")[0]

        if self.line.strip(" ").startswith(";"):
            self.is_comment = True
        elif self.line.endswith(":"):
            self.is_label = True
            self.value = self.line.strip(":")
        elif self.line.startswith("#define"):
            self.is_define = True
            values = self.line.split(" ")
            self.name, self.value = values[1], values[2]
        elif len(self.line.strip(" ")) == 0:
            # empty
            pass
        else:
            self.is_instruction = True
            raw_instr = self.line.lstrip("+").lstrip("-").lstrip(" ").split(";")[0].rstrip(" ")
            spc_idx = raw_instr.find(" ")
            if spc_idx == -1:
                self.opcode = raw_instr
                self_params = None
            else:
                self.opcode = raw_instr[0:spc_idx]
                params = raw_instr[spc_idx+1:]
                if self.opcode == "writebuf":
                    spc_idx = params.find(" ")
                    self.params = params[0:spc_idx], params[spc_idx+1:]
                else:
                    self.params = params.split(" ")

    def __str__(self):
        specs = str(self.num) + "; "
        if self.is_comment:
            specs = specs + "Comment"
        elif self.is_label:
            specs = specs + "Label"
        elif self.is_define:
            specs = specs + "Define: " + self.name + " = " + self.value
        elif self.is_instruction:
            specs = specs + "Instruction: " + self.opcode + "(" + ",".join(self.params) + ")"

        return self.line + " ; " + specs


def update_line_nums(asm_lines):
    for i, line in enumerate(asm_lines):
        line.num = i


def main():
    if len(sys.argv) != 2:
        print("Usage: preprocessor.py <asm file>")
        return

    filename = sys.argv[1]
    with open(filename, "r") as f:
        text_lines = f.readlines()

    asm_lines = []
    for i, line in enumerate(text_lines):
        asm_lines.append(AsmLine(line, i))

    # for line in asm_lines:
    #     print(line)

    # handle sti
    sti_found = True
    while sti_found:
        sti_found = False
        sti_index = 0
        sti_insert = []
        for i, line in enumerate(asm_lines):
            if line.is_instruction:
                if line.opcode == "sti":
                    sti_found = True
                    sti_index = i
                    addr = line.params[0]
                    value = line.params[1]
                    cap = int(line.params[2]) if len(line.params) > 2 else 15
                    for i in range(0, cap):
                        if i != 0:
                            sti_insert.append(AsmLine("+   cmpi #" + str(i), 0))
                        sti_insert.append(AsmLine("    jnz +", 0))
                        sti_insert.append(AsmLine("    ld " + value, 0))
                        if i == 0:
                            sti_insert.append(AsmLine("    st " + addr, 0))
                        else:
                            sti_insert.append(AsmLine("    st " + addr + "+" + str(i), 0))
                        sti_insert.append(AsmLine("    jmp sti_end_" + str(line.num), 0))
                    sti_insert.append(AsmLine("+   ld " + value, 0))
                    sti_insert.append(AsmLine("    st " + addr + "+" + str(cap), 0))
                    sti_insert.append(AsmLine("sti_end_" + str(line.num) + ":", 0))
                    break

        if sti_found:
            asm_lines.remove(asm_lines[sti_index])
            asm_lines[sti_index:sti_index] = sti_insert
            update_line_nums(asm_lines)

    # handle ldi
    ldi_found = True
    while ldi_found:
        ldi_found = False
        ldi_index = 0
        ldi_insert = []
        for i, line in enumerate(asm_lines):
            if line.is_instruction:
                if line.opcode == "ldi":
                    ldi_found = True
                    ldi_index = i
                    addr = line.params[0]
                    cap = int(line.params[1]) if len(line.params) > 1 else 15
                    for i in range(0, cap):
                        if i != 0:
                            ldi_insert.append(AsmLine("+   cmpi #" + str(i), 0))
                        ldi_insert.append(AsmLine("{0:4}jnz +".format(line.local_label), 0))
                        if i == 0:
                            ldi_insert.append(AsmLine("    ld " + addr, 0))
                        else:
                            ldi_insert.append(AsmLine("    ld " + addr + "+" + str(i), 0))
                        ldi_insert.append(AsmLine("    jmp ldi_end_" + str(line.num), 0))
                    ldi_insert.append(AsmLine("+   ld " + addr + "+" + str(cap), 0))
                    ldi_insert.append(AsmLine("ldi_end_" + str(line.num) + ":", 0))
                    break

        if ldi_found:
            asm_lines.remove(asm_lines[ldi_index])
            asm_lines[ldi_index:ldi_index] = ldi_insert
            update_line_nums(asm_lines)

    # handle writebuf
    writebuf_found = True
    while writebuf_found:
        writebuf_found = False
        writebuf_index = 0
        writebuf_insert = []
        for i, line in enumerate(asm_lines):
            if line.is_instruction:
                if line.opcode == "writebuf":
                    writebuf_found = True
                    writebuf_index = i
                    buf = line.params[0]
                    arg = line.params[1]
                    if arg.startswith("\"") and arg.endswith("\""):
                        # string
                        params = ["'" + ch + "'" for ch in arg[1:-1]]
                    else:
                        params = arg.split(",")

                    buf_offset = 0
                    if buf.find("+") != -1:
                        buf_offset = int(buf.split("+")[1])
                        buf = buf.split("+")[0]

                    buf_idx = len(params) * 2 - 1 + buf_offset
                    if (buf_idx > 15):
                        print("Buffer is TOO LONG!!!")
                        break

                    for j, param in enumerate(params):
                        prefix = ""
                        if j == 0:
                            prefix = line.local_label

                        writebuf_insert.append(AsmLine("{0:4}lit #<{1}".format(prefix, param), 0))
                        writebuf_insert.append(AsmLine("    st " + buf + "+" + str(buf_idx), 0))
                        buf_idx = buf_idx - 1
                        writebuf_insert.append(AsmLine("    lit #>" + param, 0))
                        writebuf_insert.append(AsmLine("    st " + buf + "+" + str(buf_idx), 0))
                        buf_idx = buf_idx - 1
                    break

        if writebuf_found:
            asm_lines.remove(asm_lines[writebuf_index])
            asm_lines[writebuf_index:writebuf_index] = writebuf_insert
            update_line_nums(asm_lines)

    # handle call/ret
    # Reserve one memory location for accumulator value
    tmp_found = False
    ret_found = False
    for line in asm_lines:
        if line.is_define:
            if line.name == "TMP":
                tmp_found = True
            elif line.name == "RETURN_ADDRESS":
                ret_found = True

            if ret_found and tmp_found:
                break

    if not tmp_found:
        print("No TMP variable!")
    if not ret_found:
        print("No RETURN_ADDRESS variable!")


    calls = {}
    for i, line in enumerate(asm_lines):
        if line.is_instruction:
            if line.opcode == "call" or line.opcode == "calli":
                label = line.params[0]
                if calls.get(label) is None:
                    # [called, total, call_depth]
                    calls[label] = [0, 0, 0]
                else:
                    calls[label][1] = calls[label][1] + 1

    call_depth = 0
    for i, line in enumerate(asm_lines):
        if line.is_label:
            if calls.get(line.value) is not None:
                # inside called function
                call_depth = call_depth + 1
        elif line.is_instruction:
            if line.opcode == "ret":
                call_depth = call_depth - 1
            elif line.opcode == "call" or line.opcode == "calli":
                calls[line.params[0]][2] = call_depth


    call_found = True
    while call_found:
        call_found = False
        call_index = 0
        label = ""
        insert_1 = []
        insert_2 = []
        return_address = "RETURN_ADDRESS"

        for i, line in enumerate(asm_lines):
            if line.is_instruction:
                # calli = Call with parameter in accumulator
                # call = no parameter
                # So we save parameter for calli in TMP var
                # TODO: remove TMP var, save RETURN_ADDRESS before lit/ld to accumulator
                if line.opcode == "call" or line.opcode == "calli":
                    call_found = True
                    call_index = i
                    label = line.params[0]
                    count = calls[label][0]
                    depth = calls[label][2]
                    if depth != 0:
                        return_address = "RETURN_ADDRESS_" + str(depth)
                    calls[label][0] = calls[label][0] + 1
                    if line.opcode == "calli":
                        insert_1.append(AsmLine("{0:4}st TMP".format(line.local_label), 0))
                        insert_1.append(AsmLine("    lit #" + str(count), 0))
                    else:
                        insert_1.append(AsmLine("{0:4}lit #{1}".format(line.local_label, count), 0))

                    insert_1.append(AsmLine("    st " + return_address, 0))
                    if line.opcode == "calli":
                        insert_1.append(AsmLine("    ld TMP", 0))

                    insert_1.append(AsmLine("    jmp " + label, 0))
                    insert_1.append(AsmLine(label + "_ret_" + str(count) + ":", 0))

                    if count == 0:
                        insert_2.append(AsmLine("    ld " + return_address, 0))
                    else:
                        insert_2.append(AsmLine("    cmpi #" + str(count), 0))

                    insert_2.append(AsmLine("    jz " + label + "_ret_" + str(count), 0))
                    break

        if call_found:
            search_for_ret = False
            return_index = 0

            for i, line in enumerate(asm_lines):
                if search_for_ret:
                    if line.is_instruction:
                        if line.opcode == "ret":
                            return_index = i
                            if line.is_local_label:
                                if calls[label][0] == 1:
                                    insert_2[0] = AsmLine("{0:4}ld {1}".format(line.local_label, return_address), 0)

                            break
                elif line.is_label:
                    if line.value == asm_lines[call_index].params[0]:
                        search_for_ret = True

            if return_index == 0:
                print("No return index!!!")
                break

            if calls[label][0] > calls[label][1]:
                asm_lines.remove(asm_lines[return_index])
                asm_lines[return_index:return_index] = [AsmLine("    jmp halt ; invalid return address", 0)]


            asm_lines[return_index:return_index] = insert_2

            asm_lines.remove(asm_lines[call_index])
            asm_lines[call_index:call_index] = insert_1

            update_line_nums(asm_lines)


    with open(filename[:-4] + "u.asm", "w") as f:
        for line in asm_lines:
            f.write(line.line + "\n")

if __name__ == '__main__':
    main()
