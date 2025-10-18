import base64
import os
import shutil
import gzip

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
    with open(file, 'rb') as f:
        content = f.read()
    decrypt = aes_decrypt(b'zVhJuay70scMhBUb', content, salted=True, type='aes-128-cbc')
    basename = os.path.basename(file).split('.ipk')[0]
    save_path = './plugins_unpack/' + basename
    with open(save_path + '.tar', 'wb') as f:
        f.write(gzip.decompress(decrypt))
    unpack_7zip(save_path + '.tar', save_path)
    os.remove(save_path + '.tar')


find_and_decrypt('./plugins_unpack')
