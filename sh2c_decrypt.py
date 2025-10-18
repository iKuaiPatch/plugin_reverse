import sys
import os
from elftools.elf.elffile import ELFFile

from find_sh2c import find_sh2c

def generate_ext_key() -> bytes:
    key = [0x88, 0xB1, 0xF1, 0x93, 0x7A, 0x2C, 0xB3, 0x9D, 0x53, 0x83, 0x95, 0x3E, 0x8B, 0x8A, 0x53, 0x62]
    ext_key = bytearray(1024)
    for i in range(1024):
        ext_key[i] = (0xDE * (i + 1) + key[i & 0xF]) & 0xFF
    return bytes(ext_key)

def decrypt(data: bytes) -> bytes:
    size = len(data)
    ext_key = generate_ext_key()
    result = bytearray(data)

    for i in range(size):
        tmp = (size + ext_key[i & 0x3FF]) & 0xFF
        result[i] = (((result[i] - tmp) & 0xFF) >> (7 - tmp % 7)) | (((result[i] - tmp) & 0xFF) << (tmp % 7 + 1) & 0xFF)

    return bytes(result)

def find_sh2c_encrypt_data(path: str) -> bytes:
    dataOffset = 0

    with open(path, 'rb') as f:
        elf = ELFFile(f)
        machine = elf['e_machine']

        data_section = None
        for section in elf.iter_sections():
            if section.name == '.data':
                data_section = section
                break
        
        data_content = data_section.data()
            
        if not data_content:
            print("Warrning: .data section is empty")
        else:
            for i, byte_val in enumerate(data_content):
                if byte_val != 0:
                    dataOffset = data_section['sh_offset'] + i
                    break

    with open(path, 'rb') as f:
        print("ELF machine: {}".format(machine))

        if machine == 'EM_X86_64':
            offset = {
                'size': 0x1677, # BA E5 4F 00 00  mov edx, 4FE5h
                'data': 0xA020
            }

            f.seek(offset['size'])
            if f.read(1) != b'\xba':
                print("Invalid x86_64 size opcode")
                return None
            size = int.from_bytes(f.read(4), 'little')
        elif machine == 'EM_MIPS': # MT7621
            offset = {
                'size': 0xC9C, # 59 1F 06 24  li $a2, 0x1F59
                'data': 0xE010
            }

            f.seek(offset['size'])
            size = int.from_bytes(f.read(2), 'little')
            code = f.read(2)
            if code[0] != 0x06 and code[1] != 0x24 and code[1] != 0x34: # 24=li, 34=li
                print("Invalid MIPS size opcode", code.hex())
                return None
        elif machine == 'EM_AARCH64': # MT798x
            offset = {
                'size': 0x900, # 22 EB 83 52  MOV W2, #0x1F59 ; 1
                'data': 0xB008
            }
            f.seek(offset['size'])
            inst = int.from_bytes(f.read(4), 'little')

            sf = (inst >> 31) & 1             # 31
            opc = (inst >> 29) & 0b11         # 30-29
            fixed6 = (inst >> 23) & 0b111111  # 28-23
            hw = (inst >> 21) & 0b11          # 22-21
            imm16 = (inst >> 5) & 0xFFFF      # 20-5
            Rd = inst & 0b11111               # 4-0

            if fixed6 != 0b100101 or opc not in [0,2,3]:
                print("Not a MOVZ/MOVK/MOVN instruction")
                return None
        
            value = imm16 << (hw * 16)
            
            size = value
        else:
            print("Unsupported machine: {}".format(machine))
            return None
        
        print("Found sh2c encrypt size: {}".format(size))

        if dataOffset != offset['data']:
            f.seek(dataOffset)
            a = f.read(4)
            f.seek(offset['data'])
            b = f.read(4)
            if a != b:
                print("Warning: .data section offset mismatch, using .data section offset")
                offset['data'] = dataOffset

        f.seek(offset['data'])
        data = f.read(size)

        if len(data) != size:
            print("Read data size mismatch")
        
        return data

    return None

def find_and_decrypt(path: str):
    for file in find_sh2c(path):
        encrypt = find_sh2c_encrypt_data(file)
        if encrypt is None:
            print(f"Not found sh2c encrypt data in {file}.")
            continue
        print(f"Found sh2c encrypt data in {file}, length = {len(encrypt)}")
        decrypted = decrypt(encrypt)
        with open(file, 'wb') as f:
            f.write(decrypted)
        print(f'Decrypted sh2c data written to {file}')

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 sh2c_decrypt.py target.elf output.sh")
        sys.exit(1)

    path = sys.argv[1]
    output = sys.argv[2]

    encrypt = find_sh2c_encrypt_data(path)
    if encrypt is None:
        print("Not found sh2c encrypt data.")
        sys.exit(1)
    
    print("Found sh2c encrypt data, length = {}".format(len(encrypt)))

    decrypted = decrypt(encrypt)
    with open(output, 'wb') as f:
        f.write(decrypted)


if __name__ == "__main__":
    main()

