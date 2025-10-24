import base64, os, subprocess, json
from Crypto.Cipher import AES
import hashlib, binascii
from passlib.utils.pbkdf2 import pbkdf1
import shutil
import gzip
from sh2c_decrypt import find_and_decrypt

def unpack_7zip(path: str, outdir: str):
    if not os.path.exists(outdir):
        os.mkdir(outdir)
    subprocess.run(['7z', 'x', '-o' + outdir, path, '-y'])

def hasher(algo, data):
    hashes = {'md5': hashlib.md5, 'sha256': hashlib.sha256,
    'sha512': hashlib.sha512}
    h = hashes[algo]()
    h.update(data)

    return h.digest()

# pwd and salt must be bytes objects
def openssl_kdf(algo, pwd, salt, key_size, iv_size):
    if algo == 'md5':
        temp = pbkdf1(pwd, salt, 1, 16, 'md5')
    else:
        temp = b''

    fd = temp    
    while len(fd) < key_size + iv_size:
        temp = hasher(algo, temp + pwd + salt)
        fd += temp

    key = fd[0:key_size]
    iv = fd[key_size:key_size+iv_size]

    # print('salt=' + binascii.hexlify(salt).decode('ascii').upper())
    # print('key=' + binascii.hexlify(key).decode('ascii').upper())
    # print('iv=' + binascii.hexlify(iv).decode('ascii').upper())

    return key, iv

def aes_decrypt(password, ciphertext, salted=False):

    if salted:
        # skip header "Salted__"
        ciphertext = ciphertext[8:]
        salt = ciphertext[:8]

        key_length = 16  # AES-128

        #skip salt
        ciphertext = ciphertext[8:]
    else:
        salt = b''
        key_length = 32  # AES-256
    
    iv_length = 16
    key=None
    iv=None
    key,iv=openssl_kdf(algo="md5",pwd=password,salt=salt,key_size=key_length,iv_size=iv_length)

    cipher = AES.new(key, AES.MODE_CBC, iv)
    plaintext = cipher.decrypt(ciphertext)
    plaintext = plaintext.rstrip(b'\0')
    plaintext = plaintext[:-plaintext[-1]]

    return plaintext

def main():
    if os.path.exists('pkgdata'):
        shutil.rmtree('pkgdata')
    if os.path.exists('pkgdata_unpack'):
        shutil.rmtree('pkgdata_unpack')
    os.mkdir('pkgdata_unpack')

    with open('pkgdata.b64', 'r') as f:
        pkgdata = f.read()

    with open('pkgdata.tar', 'wb') as f:
        f.write(base64.b64decode(pkgdata))

    unpack_7zip('pkgdata.tar', 'pkgdata')
    unpack_7zip('pkgdata/pkgdata', 'pkgdata')
    os.remove('pkgdata/pkgdata')

    with open('./pkgdata/db/.__DB.3.x86_64', 'r') as f:
        ciphertext = f.read()

    password = b'ikupdat-d~#-'
    encrypted_data = base64.b64decode(ciphertext)
    decrypted_data = aes_decrypt(password, encrypted_data, salted=False)
    decrypted_data = decrypted_data
    print(decrypted_data.decode('utf-8'))

    with open('./pkgdata_unpack/db.json', 'wb') as f:
        f.write(decrypted_data)

    json_data = json.loads(decrypted_data.decode('utf-8'))
    for pkg in json_data:
        try:
            password = pkg['secret_key'].encode('utf-8')
            if os.path.exists(f'./pkgdata/{pkg["name"]}.bin.pkg'):
                with open(f'./pkgdata/{pkg["name"]}.bin.pkg', 'rb') as f:
                    encrypted_data = f.read()
                decrypted_data = aes_decrypt(password, encrypted_data, salted=True, type=pkg['encryption'])
                with open(f'./pkgdata_unpack/{pkg["name"]}.bin', 'wb') as f:
                    f.write(decrypted_data)
                print(f'Decrypted {pkg["name"]} successfully')
            else:
                print(f'./pkgdata/{pkg["name"]}.bin.pkg not found')
        except Exception as e:
            print(f'Error processing {pkg["name"]}: {e}')
    

    gzip_header = b'\x0A\x1F\x8B\x08\x00'
    for root, dirs, files in os.walk('pkgdata_unpack'):
        for file in files:
            path = os.path.join(root, file)
            with open(path, 'rb') as f:
                file = f.read()
            # find gzip header
            idx = file.find(gzip_header)
            if idx != -1:
                pkgname = os.path.basename(path).split('.')[0]
                os.mkdir(f'./pkgdata_unpack/{pkgname}')
                with open(f'./pkgdata_unpack/{pkgname}/install.sh', 'wb') as f:
                    f.write(file[:idx])
                data = file[idx:]
                magic = b"\x1f\x8b"
                pos = data.find(magic)
                if pos == -1:
                    with open(f'./pkgdata_unpack/{pkgname}/{pkgname}', 'wb') as f:
                        f.write(data)
                    print("gzip header not found")
                    continue
                try:
                    print(f'Extracting {pos} {pkgname}...')
                    data = gzip.decompress(data[pos:])
                    with open(f'./pkgdata_unpack/{pkgname}/{pkgname}.tar', 'wb') as f:
                        f.write(data)
                    unpack_7zip(f'./pkgdata_unpack/{pkgname}/{pkgname}.tar', f'./pkgdata_unpack/{pkgname}/{pkgname}')
                except Exception as e:
                    print(f'Error decompressing {pkgname}: {e}')
                    with open(f'./pkgdata_unpack/{pkgname}/{pkgname}', 'wb') as f:
                        f.write(data)
    
    find_and_decrypt('./pkgdata_unpack')
    

if __name__ == '__main__':
    # main()
    with open('appinst_8.1.45', 'r') as f:
        data = f.read()
    password = b'ikupdat-d~#-'
    encrypted_data = base64.b64decode(data)
    decrypted_data = aes_decrypt(password, encrypted_data, salted=False)
    decrypted_data = decrypted_data
    print(decrypted_data.decode('utf-8'))

    with open('appinst_8.1.45.bin.ikp', 'rb') as f:
        encrypted_data = f.read()
    
    password = b'ikuai8wbdbdssl'
    decrypted_data = aes_decrypt(password, encrypted_data, salted=True)
    with open(f'./appinst_8.1.45.bin', 'wb') as f:
        f.write(decrypted_data)
