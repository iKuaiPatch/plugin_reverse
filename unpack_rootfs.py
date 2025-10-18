import struct, gzip, os, shutil, subprocess, sys
import lzma
from rootfs import decode_rootfs
from sh2c_decrypt import find_and_decrypt

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

def get_rootfs_hash(data):
    # Verify hash
    calculated_hash = crc32_hash(data, len(data))
    calculated_hash = (~calculated_hash) & 0xffffffff
    calculated_hash = struct.unpack('<I', struct.pack('>I', calculated_hash))[0]
    
    # Hash the hash
    hash_bytes = struct.pack('<I', calculated_hash)
    calculated_hash = crc32_hash(hash_bytes, 4)
    calculated_hash = (~calculated_hash) & 0xffffffff
    calculated_hash = struct.unpack('<I', struct.pack('>I', calculated_hash))[0]

    return calculated_hash

def unpack_7zip(path: str, outdir: str):
    if not os.path.exists(outdir):
        os.mkdir(outdir)
    subprocess.run(['7z', 'x', '-o' + outdir, path, '-y'])

def xz_unpack_robust(input_file, output_file):
    try:
        with lzma.LZMAFile(input_file, 'rb') as f_in:
            with open(output_file, 'wb') as f_out:
                chunk_size = 8192
                while True:
                    try:
                        chunk = f_in.read(chunk_size)
                        if not chunk:
                            break
                        f_out.write(chunk)
                    except EOFError:
                        print("Warning: File appears to be truncated, but partial extraction completed")
                        break
        print(f"Extraction completed (possibly partial): {output_file}")
    except Exception as e:
        print(f"Extraction failed: {e}")

def unpack_rootfs(input_file: str, rootfs_out: str, crc32_out: str):
    with open(input_file, "rb") as f:
        f.seek(-4, os.SEEK_END)
        crc32_bytes = f.read(4)
        crc32 = struct.unpack("<I", crc32_bytes)[0]
        print(f"Extracted CRC32: 0x{crc32:08x}")
    
    with open(crc32_out, "wb") as f:
        f.write(crc32_bytes)
        
    with open(input_file, "rb") as f:
        data = f.read()
    
    with open(rootfs_out, "wb") as f:
        f.write(data[:-4])
    
    hash = get_rootfs_hash(data[:-4])
    print(f"Calculated Hash: 0x{hash:08x}")
    if hash != crc32:
        print("Warning: Hash mismatch!")

def extract(srcfile: str, export_path: str):
    with open(srcfile, "rb") as f:
        headlen = struct.unpack(">I", f.read(4))[0]
        header_data = f.read(headlen)

    with open(f"{export_path}/header_info.json", "wb") as f:
        f.write(gzip.decompress(
            b"\x1f\x8b\x08\x00\x6f\x9b\x4b\x59\x02\x03" + header_data
        ))

    with open(srcfile, "rb") as f:
        f.seek(4 + headlen)
        fw = f.read()
    
    with open(f"{export_path}/firmware.bin", "wb") as f:
        f.write(gzip.decompress(fw))
    
    unpack_7zip(f"{export_path}/firmware.bin", f"{export_path}/firmware")

def main():
    if len(sys.argv) < 2:
        print("用法: python unpack_rootfs.py [固件文件] {保存位置}")
        sys.exit(1)
    firmware_file = sys.argv[1]
    export_path = sys.argv[2] if len(sys.argv) == 3 else "./dump"

    
    if os.path.exists(export_path):
        shutil.rmtree(export_path)

    os.mkdir(export_path)

    extract(firmware_file, export_path)
    decode_rootfs(f"{export_path}/firmware/boot/rootfs", f"{export_path}/rootfs.xz")
    os.mkdir(f"{export_path}/rootfs")
    unpack_rootfs(f"{export_path}/rootfs.xz", f"{export_path}/rootfs/rootfs.xz", f"{export_path}/rootfs/rootfs_crc.bin")
    xz_unpack_robust(f"{export_path}/rootfs/rootfs.xz", f"{export_path}/rootfs/rootfs.ext2")
    unpack_7zip(f"{export_path}/rootfs/rootfs.ext2", f"{export_path}/rootfs/system")
    find_and_decrypt(f"{export_path}/rootfs/system")

if __name__ == "__main__":
    main()
