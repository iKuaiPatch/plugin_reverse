import sys
from find_sh2c import find_sh2c
from elftools.elf.elffile import ELFFile

def generate_ext_key(key_index: int = 0) -> bytes:
    keys = [
        [0x88, 0xB1, 0xF1, 0x93, 0x7A, 0x2C, 0xB3, 0x9D, 0x53, 0x83, 0x95, 0x3E, 0x8B, 0x8A, 0x53, 0x68],
        [0x88, 0xB1, 0xF1, 0x93, 0x7A, 0x2C, 0xB3, 0x9D, 0x53, 0x83, 0x95, 0x95, 0x8B, 0x8A, 0x53, 0x68],
        [0x88, 0xB1, 0xF1, 0x93, 0x7A, 0x2C, 0xB3, 0x9D, 0x53, 0x83, 0x95, 0x3E, 0x8B, 0x8A, 0x53, 0x62]
    ]
    key = keys[key_index]
    ext_key = bytearray(1024)
    for i in range(1024):
        ext_key[i] = (0xDE * (i + 1) + key[i & 0xF]) & 0xFF
    return bytes(ext_key)

def decrypt(data: bytes, key2: bool) -> bytes:
    size = len(data)
    ext_key = generate_ext_key(key2)
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

        size = 0
        data_offset = dataOffset

        if machine == 'EM_X86_64':
            offset = [
                {
                    'size': 0x16BF, # BA E5 4F 00 00  mov edx, 4FE5h ; 1
                    'data': 0xA020
                },
                {
                    'size': 0x16BD, # BA E5 4F 00 00  mov edx, 4FE5h ; 2
                    'data': 0x9040
                }
            ]
            for off in offset:
                f.seek(off['size'])
                if f.read(1) != b'\xba':
                    print(f"{off['size']:04X}: Invalid x86_64 size opcode")
                    continue

                size = int.from_bytes(f.read(4), 'little')
                break
            data_offset = off['data']
        elif machine == 'EM_MIPS': # MT7621
            offset = {
                'size': 0xC9C, # 59 1F 06 24  li $a2, 0x1F59
                'data': 0xE010
            }

            f.seek(offset['size'])
            size = int.from_bytes(f.read(2), 'little')
            data_offset = offset['data']
            code = f.read(2)
            if code != b'\x06\x24':
                print("Invalid MIPS size opcode", code)
                return None
            
        elif machine == 'EM_AARCH64': # MT798x
            offset = [
                {
                    'size': 0x900, # 22 EB 83 52  MOV W2, #0x1F59 ; 1
                    'data': 0xB008
                },
                {
                    'size': 0x90C, # 22 EB 83 52  MOV W2, #0x1F59 ; 2
                    'data': 0xB008
                }
            ]
            for off in offset:
                f.seek(off['size'])
                inst = int.from_bytes(f.read(4), 'little')

                sf = (inst >> 31) & 1             # 31
                opc = (inst >> 29) & 0b11         # 30-29
                fixed6 = (inst >> 23) & 0b111111  # 28-23
                hw = (inst >> 21) & 0b11          # 22-21
                imm16 = (inst >> 5) & 0xFFFF      # 20-5
                Rd = inst & 0b11111               # 4-0

                if fixed6 != 0b100101 or opc not in [0,2,3]:
                    print(f"{off['size']:04X}: Not a MOVZ/MOVK/MOVN instruction")
                    continue
            
                value = imm16 << (hw * 16)
                
                size = value
                data_offset = off['data']
                break
            if size == 0:
                print("Invalid AARCH64 size opcode")
                return None
        else:
            print("Unsupported machine: {}".format(machine))
            return None
        
        print("Found sh2c encrypt size: {}".format(size))

        if dataOffset != data_offset:
            f.seek(dataOffset)
            a = f.read(4)
            f.seek(data_offset)
            b = f.read(4)
            if a != b:
                print("Warning: .data section offset mismatch, using .data section offset")
                print("Data at .data offset: 0x{:X}".format(dataOffset))
                print("Data at calculated offset: 0x{:X}".format(data_offset))
                data_offset = dataOffset

        print("Using data offset: 0x{:X}".format(data_offset))
        f.seek(data_offset)
        data = f.read(size)

        if len(data) != size:
            print("Read data size mismatch")
        
        return data

    return None

def decrypt_sigle_file(file: str):
    encrypt = find_sh2c_encrypt_data(file)
    if encrypt is None:
        print(f"Not found sh2c encrypt data in {file}.")
        return
    print(f"Found sh2c encrypt data in {file}, length = {len(encrypt)}")

    for key_index in range(3):
        decrypted = decrypt(encrypt, key_index)
        try:
            decrypted.decode('utf-8')
            print(f'Decrypted sh2c data is valid UTF-8 text with key index {key_index}.')
            break
        except UnicodeDecodeError:
            continue
    
    try:
        decrypted.decode('utf-8')
    except UnicodeDecodeError:
        print(f'Failed to decrypt sh2c data in {file} with all key indices.')
        return
    
    with open(file, 'wb') as f:
        f.write(decrypted)

    print(f'Decrypted sh2c data written to {file}')

def find_and_decrypt(path: str):
    for file in find_sh2c(path):
        decrypt_sigle_file(file)

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

