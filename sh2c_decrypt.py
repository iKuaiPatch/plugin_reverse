#!/usr/bin/env python3

import sys
import re
from elftools.elf.elffile import ELFFile

from find_sh2c import find_sh2c

def parse_hex_key(hex_string: str) -> bytes:
    return bytes.fromhex(hex_string)

def generate_ext_key(base_key: bytes) -> bytes:
    ext_key = bytearray(1024)
    for i in range(1024):
        ext_key[i] = (0xDE * (i + 1) + base_key[i & 0xF]) & 0xFF
    return bytes(ext_key)

def decrypt(data: bytes, base_key: bytes) -> bytes:
    size = len(data)
    ext_key = generate_ext_key(base_key)
    result = bytearray(data)

    for i in range(size):
        tmp = (size + ext_key[i & 0x3FF]) & 0xFF
        result[i] = (((result[i] - tmp) & 0xFF) >> (7 - tmp % 7)) | (((result[i] - tmp) & 0xFF) << (tmp % 7 + 1) & 0xFF)

    return bytes(result)

def extract_hex_key_from_elf(path: str) -> bytes:
    with open(path, 'rb') as f:
        elf = ELFFile(f)
        
        # Find .rodata section and look for the hex key string
        rodata_section = None
        for section in elf.iter_sections():
            if section.name == '.rodata':
                rodata_section = section
                break
        
        if rodata_section:
            rodata_content = rodata_section.data()
            hex_pattern = re.compile(rb'[0-9a-f]{32}\x00')
            matches = hex_pattern.findall(rodata_content)
            if matches:
                hex_key_str = matches[0][:-1].decode('ascii')
                print(f"Found hex key string in .rodata: {hex_key_str}")
                return parse_hex_key(hex_key_str)
    
    print("Warning: Could not find hex key in .rodata, using default key")
    return bytes([0x88, 0xB1, 0xF1, 0x93, 0x7A, 0x2C, 0xB3, 0x9D, 0x53, 0x83, 0x95, 0x3E, 0x8B, 0x8A, 0x53, 0x62])

def find_sh2c_encrypt_data(path: str) -> tuple[bytes, bytes]:
    dataOffset = 0

    with open(path, 'rb') as f:
        elf = ELFFile(f)
        machine = elf['e_machine']

        # Find .data section to get the initial data offset
        data_section = None
        for section in elf.iter_sections():
            if section.name == '.data':
                data_section = section
                break
        
        if not data_section:
            print("Error: .data section not found")
            return None, None
            
        data_content = data_section.data()
        data_size = data_section['sh_size']

        if not data_content:
            print("Warning: .data section is empty")
        else:
            # Find the first non-zero byte in .data to determine the data offset
            for i, byte_val in enumerate(data_content):
                if byte_val != 0:
                    dataOffset = data_section['sh_offset'] + i
                    data_size -= i
                    print(f"Found non-zero byte in .data at offset 0x{i:x}, setting dataOffset to 0x{dataOffset:x}, adjusted data size: {data_size} bytes")
                    break

    base_key = extract_hex_key_from_elf(path)
    print(f"Using key: {base_key.hex()}")
    
    with open(path, 'rb') as f:
        print(f"ELF machine: {machine}")

        size = None
        data_offset_from_opcode = None
        
        if machine == 'EM_X86_64':
            # x86_64: 尝试从 MOV EDX 指令中提取大小
            # 格式: BA <size_little_endian>  (mov edx, size)
            offsets = [
                {'size': 0x1677, 'data': 0xA020},
                {'size': 0x166A, 'data': 0xD020},
            ]
            
            for o in offsets:
                f.seek(o['size'])
                if f.read(1) == b'\xba':  # MOV EDX opcode
                    size = int.from_bytes(f.read(4), 'little')

                    if size <= 0 or size > data_size:
                        print(f"Warning: Extracted size {size} from opcode at offset 0x{o['size']:x} is invalid, skipping")
                        continue

                    data_offset_from_opcode = o['data']
                    print(f"Found size from x86_64 opcode: {size} (0x{size:x})")
                    break

        elif machine == 'EM_MIPS': # MT7621
            # MIPS: LI $a2, size
            # 格式: <size_little_endian> 06 24  (li $a2, size)
            offsets = [
                {'size': 0xC64, 'data': 0x3010},
                {'size': 0xC9C, 'data': 0xE010}
            ]
            
            for o in offsets:
                f.seek(o['size'])
                size = int.from_bytes(f.read(2), 'little')
                code = f.read(2)
                if code[0] == 0x06 and (code[1] == 0x24 or code[1] == 0x34):  # LI opcode
                    if size <= 0 or size > data_size:
                        print(f"Warning: Extracted size {size} from opcode at offset 0x{o['size']:x} is invalid, skipping")
                        continue
                    data_offset_from_opcode = o['data']
                    print(f"Found size from MIPS opcode: {size} (0x{size:x})")
                    break
            
        elif machine == 'EM_AARCH64': # MT798x
            # ARM64: MOV W2, #size
            # 格式: <inst_little_endian>  (MOV W2, #imm)
            offsets = [
                {'size': 0x8E8, 'data': 0x10008},
                {'size': 0x900, 'data': 0xB008}
            ]
            
            for o in offsets:
                f.seek(o['size'])
                inst = int.from_bytes(f.read(4), 'little')
                
                fixed6 = (inst >> 23) & 0b111111
                opc = (inst >> 29) & 0b11
                
                if fixed6 == 0b100101 and opc in [0, 2, 3]:  # MOVZ/MOVK/MOVN
                    hw = (inst >> 21) & 0b11
                    imm16 = (inst >> 5) & 0xFFFF
                    size = imm16 << (hw * 16)

                    if size <= 0 or size > data_size:
                        print(f"Warning: Extracted size {size} from opcode at offset 0x{o['size']:x} is invalid, skipping")
                        continue

                    data_offset_from_opcode = o['data']
                    print(f"Found size from ARM64 opcode: {size} (0x{size:x})")
                    break
        
        else:
            print(f"Unsupported machine: {machine}")
            return None, None
        
        if size is None:
            print(f"Warning: Could not extract size from opcodes for {machine}")
            return None, None
        
        if data_offset_from_opcode and dataOffset != data_offset_from_opcode:
            f.seek(dataOffset)
            data_from_section = f.read(min(4, size))
            f.seek(data_offset_from_opcode)
            data_from_opcode = f.read(min(4, size))
            
            if data_from_section != data_from_opcode:
                print(f"Warning: Data offset mismatch detected")
                print(f"  .data section offset: 0x{dataOffset:x}")
                print(f"  Opcode-based offset: 0x{data_offset_from_opcode:x}")
                print(f"  Using .data section offset")
            else:
                dataOffset = data_offset_from_opcode
        elif data_offset_from_opcode:
            dataOffset = data_offset_from_opcode
        
        f.seek(dataOffset)
        data = f.read(size)
        
        if len(data) != size:
            print(f"Warning: Read {len(data)} bytes but expected {size} bytes")
        
        print(f"Extracted encrypted data from offset 0x{dataOffset:x}, size: {len(data)} bytes")
        return data, base_key

    return None, None

def find_and_decrypt(path: str):
    for file in find_sh2c(path):
        encrypt_data, base_key = find_sh2c_encrypt_data(file)
        if encrypt_data is None:
            print(f"Not found sh2c encrypt data in {file}.")
            continue
        print(f"Found sh2c encrypt data in {file}, length = {len(encrypt_data)}")
        decrypted = decrypt(encrypt_data, base_key)
        try:
            decrypted.decode('utf-8')
        except UnicodeDecodeError:
            print(f"Error: Decrypted data in {file} is not valid UTF-8, writing as binary")
            continue
        with open(file, 'wb') as f:
            f.write(decrypted)
        print(f'Decrypted sh2c data written to {file}')

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 sh2c_decrypt.py target.elf output.sh")
        sys.exit(1)

    path = sys.argv[1]
    output = sys.argv[2]

    encrypt_data, base_key = find_sh2c_encrypt_data(path)
    if encrypt_data is None:
        print("Not found sh2c encrypt data.")
        sys.exit(1)
    
    print("Found sh2c encrypt data, length = {}".format(len(encrypt_data)))

    decrypted = decrypt(encrypt_data, base_key)
    with open(output, 'wb') as f:
        f.write(decrypted)
    
    print(f"Successfully decrypted to {output}")


if __name__ == "__main__":
    main()

