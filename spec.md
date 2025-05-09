# Qik Virtual Machine Specification

# Bytecode Structure

Each Qik executable is split into two sections, data and text

## Data Section

The data section contains mosto of the static data needed during execution of the program

## Text Section

The text section contains all the instructions of compiled Qik programs

# Instructions

- `nop` - 1 - does nothing
- `call (name: string, args: [i|r ...])` - >= 3 - Calls a built-in function with the given arguments
- `callext (path: str, args: [i|r...])` - >= 4 - Calls a compiled Qik file like function
- `alloc (dst: r, size: i|r)` - 3 - Allocates or reallocates the specified register with the given amount
- `free (dst: r)` - 2 - Frees the specified register
- `cmp (a: r, op: '='|'!='|'>'|'<'|'>='|'<=', b: r)` - 3 - Compares the two specified registers by the specified operator
- `jmp (target: str|pos)` - 3 - Unconditionally jumps to the specified position
- `tjmp (target: str|pos)` - 3 - Jumps to the specified if the result of the last `cmp` is true
- `fjmp (target: str|pos)` - 3 - Jumps to the specified if the result of the last `cmp` is false
- `set (dst: r, src: i|r)` - 3 - Sets the specified register to the given value
- `indset (dstIndex: i|r, dst: r, srcIndex: i|r, src: i|r)` - 4 - Sets the specified index of the specified register to the given value
- `inc (dst: r)` - 2 - Incremements the specified register
- `dec (dst: r)` - 2 - Decremements the specified register
