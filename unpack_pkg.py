import os, shutil, sys
import gzip
import base64
from sh2c_decrypt import find_and_decrypt

def unpack_pkg(path: str, outdir: str):

    if not os.path.exists(outdir):
        os.mkdir(outdir)

    with open(path, "rb") as f:
        pkg_data = f.read()

    # 拼接 gzip 头
    header = bytes([0x1f, 0x8b, 0x08, 0x00, 0x6f, 0x9b, 0x4b, 0x59, 0x02, 0x03])
    gz_data = header + pkg_data

    # 解压 gzip
    b64_data = gzip.decompress(gz_data)

    # base64 解码
    final_data = base64.b64decode(b64_data)

    # 写入最终文件
    filename = os.path.basename(path).split('.')[0]
    savepath = os.path.join(outdir, filename)

    os.makedirs(savepath, exist_ok=True)
    final_path = os.path.join(savepath, os.path.basename(path))
    with open(final_path, "wb") as f:
        f.write(final_data)

    print(f"解压完成：{final_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python unpack_pkg.py [pkg文件]")
        sys.exit(1)
    
    pkg_file = sys.argv[1]
    unpack_pkg(pkg_file, "./unpacked_pkg")
    find_and_decrypt("./unpacked_pkg")

