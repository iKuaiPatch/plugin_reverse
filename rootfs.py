import struct
import ctypes

def crc32_hash(data, length):
    """
    Custom hash function implementation matching the C code
    """
    hash_table = [
        0x00, 0x00, 0x00, 0x00, 0x64, 0x10, 0xB7, 0x1D, 0xC8, 0x20,
        0x6E, 0x3B, 0xAC, 0x30, 0xD9, 0x26, 0x90, 0x41, 0xDC, 0x76,
        0xF4, 0x51, 0x6B, 0x6B, 0x58, 0x61, 0xB2, 0x4D, 0x3C, 0x71,
        0x05, 0x50, 0x20, 0x83, 0xB8, 0xED, 0x44, 0x93, 0x0F, 0xF0,
        0xE8, 0xA3, 0xD6, 0xD6, 0x8C, 0xB3, 0x61, 0xCB, 0xB0, 0xC2,
        0x64, 0x9B, 0xD4, 0xD2, 0xD3, 0x86, 0x78, 0xE2, 0x0A, 0xA0,
        0x1C, 0xF2, 0xBD, 0xBD
    ]
    
    # Convert to 32-bit lookup table
    hash_table_32 = []
    for i in range(0, len(hash_table), 4):
        word = struct.unpack('<I', bytes(hash_table[i:i+4]))[0]
        hash_table_32.append(word)
    
    result = 0xffffffff
    
    for i in range(length):
        v4 = data[i]
        v5 = hash_table_32[(v4 ^ (result & 0xff)) & 0xf] ^ (result >> 4)
        result = hash_table_32[((v5 & 0xff) ^ (v4 >> 4)) & 0xf] ^ (v5 >> 4)
        result &= 0xffffffff
    
    return result

def generate_extended_key():
    """
    Generate the 1024-byte extended key from the base key
    """
    base_key = [0x77, 0xb1, 0xfa, 0x93, 0x74, 0x2c, 0xb3, 0x9d,
                0x33, 0x83, 0x55, 0x3e, 0x84, 0x8a, 0x52, 0x91]
    
    ext_key = []
    for i in range(1024):
        val = base_key[i & 0xf] + ctypes.c_uint32(19916032 * (i + 1)).value // 131
        ext_key.append(ctypes.c_uint8(val).value)
    
    return ext_key

def decode_rootfs(input_file, output_file):
    """
    Decode the rootfs file using the custom algorithm
    
    Args:
        input_file (str): Path to the input encrypted rootfs file
        output_file (str): Path to save the decoded rootfs file
    
    Returns:
        bool: True if decoding and hash verification successful, False otherwise
    """
    try:
        # Read input file
        with open(input_file, 'rb') as f:
            data = bytearray(f.read())
    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found")
        return False
    except Exception as e:
        print(f"Error reading input file: {e}")
        return False
    
    file_size = len(data)
    data_size = file_size - 4  # Exclude 4-byte hash at the end
    
    if file_size < 4:
        print("Error: File too small (less than 4 bytes)")
        return False
    
    # Calculate parameters
    size_low_byte = ctypes.c_int8(data_size).value
    ext_key = generate_extended_key()
    
    # Decode the data
    iter_val = 0
    while iter_val < data_size:
        # Calculate tmp_var
        tmp_var = ctypes.c_uint32(iter_val).value
        iter_val += 1
        
        # Calculate new low byte: *(uint8_t*)&tmp_var = (uint8_t)(size_low_byte + ext_key[tmp_var % 1024] * 1)
        new_low_byte = ctypes.c_uint8(size_low_byte + ext_key[tmp_var % 1024]).value
        
        # Replace tmp_var's low byte
        tmp_var = (tmp_var & 0xffffff00) | new_low_byte
        
        # Apply transformation to data[iter_val - 1]
        target_index = iter_val - 1
        if 0 <= target_index < data_size:
            current_byte = data[target_index]
            tmp_var_byte = tmp_var & 0xff
            
            # Subtract and rotate
            diff = ctypes.c_uint8(current_byte - tmp_var_byte).value
            shift_amount = (tmp_var_byte % 7) + 1
            
            # Circular left shift
            rotated = ctypes.c_uint8(diff << shift_amount).value | (diff >> (8 - shift_amount))
            data[target_index] = rotated
    
    # Verify hash
    calculated_hash = crc32_hash(data[:data_size], data_size)
    calculated_hash = (~calculated_hash) & 0xffffffff
    calculated_hash = struct.unpack('<I', struct.pack('>I', calculated_hash))[0]
    
    # Hash the hash
    hash_bytes = struct.pack('<I', calculated_hash)
    calculated_hash = crc32_hash(hash_bytes, 4)
    calculated_hash = (~calculated_hash) & 0xffffffff
    calculated_hash = struct.unpack('<I', struct.pack('>I', calculated_hash))[0]
    
    # Get authentic hash from file
    authentic_hash = struct.unpack('<I', data[file_size-4:file_size])[0]
    
    # Verify
    if calculated_hash != authentic_hash:
        print(f"Hash verification failed!")
        print(f"Calculated: 0x{calculated_hash:08x}")
        print(f"Authentic:  0x{authentic_hash:08x}")
        return False
    
    # Save decoded file
    try:
        with open(output_file, 'wb') as f:
            f.write(data)
        print(f"Successfully decoded '{input_file}' to '{output_file}'")
        print(f"File size: {file_size} bytes")
        print(f"Hash verification: PASSED")
        return True
    except Exception as e:
        print(f"Error writing output file: {e}")
        return False
