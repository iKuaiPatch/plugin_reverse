import base64
import os
import subprocess
import shutil
import gzip

from sh2c_decrypt import find_and_decrypt
from pkgdata import unpack_7zip, aes_decrypt

if os.path.exists('autodata'):
    shutil.rmtree('autodata')

os.mkdir('autodata')

with open('autodata.b64', 'r') as f:
    autodata = f.read()

with open('./autodata/autodata.tar', 'wb') as f:
    f.write(gzip.decompress(base64.b64decode(autodata)))

unpack_7zip('./autodata/autodata.tar', 'autodata')

ipk = []
for root, dirs, files in os.walk('autodata'):
    for file in files:
        if file.endswith('.ipk'):
            ipk.append(os.path.join(root, file))

print(f"找到 {len(ipk)} 个 ipk 文件:")
for file in ipk:
    print(f"解包 {file} ...")
    with open(file, 'rb') as f:
        content = f.read()
    decrypt = aes_decrypt(b'htd37I2swF6nkvDK', content, salted=True, type='aes-128-cbc')
    basename = file.split('.ipk')[0]
    with open(basename + '.tar', 'wb') as f:
        f.write(gzip.decompress(decrypt))
    unpack_7zip(basename + '.tar', basename)
    os.remove(basename + '.tar')

find_and_decrypt('./autodata')
