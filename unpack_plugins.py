import base64
import os
import shutil
import gzip
import tarfile

from sh2c_decrypt import find_and_decrypt
from pkgdata import unpack_7zip, aes_decrypt

if os.path.exists('plugins_unpack'):
    shutil.rmtree('plugins_unpack')

os.mkdir('plugins_unpack')

ipk = []
for root, dirs, files in os.walk('plugins'):
    for file in files:
        if file.endswith('.ipk'):
            ipk.append(os.path.join(root, file))

print(f"找到 {len(ipk)} 个 ipk 文件:")
for file in ipk:
    print(f"解包 {file} ...")

    # check is tar
    try:
        tar = tarfile.open(file, 'r:')
        name = tar.extractfile('verifys/name').read().decode().strip()
        content = tar.extractfile(f'verifys/{name}').read()
        print("Read ipk as tar")
    except Exception as e:
        print(f"Read raw ipk: {e}")
        with open(file, 'rb') as f:
            content = f.read()
    
    decrypt = aes_decrypt(b'kingGC@21#13!888', content, salted=True)
    basename = os.path.basename(file).split('.ipk')[0]
    save_path = './plugins_unpack/' + basename
    try:
        with open(save_path + '.tar', 'wb') as f:
            f.write(gzip.decompress(decrypt))
    except Exception as e:
        print(f"解压 gzip 失败，尝试直接保存: {e}")
        with open(save_path + '.tar', 'wb') as f:
            f.write(decrypt)
        exit(1)
    unpack_7zip(save_path + '.tar', save_path)
    os.remove(save_path + '.tar')

find_and_decrypt('./plugins_unpack')