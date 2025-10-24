from pkgdata import aes_decrypt
import gzip

with open("appinst_8.1.46.bin", "rb") as f:
    data = f.read()

# aes-128-cbc
decrypted = aes_decrypt(b'kingGC@21#13!888', data, salted=True)
with open("appinst_8.1.46.bin.dec", "wb") as f:
    f.write(gzip.decompress(decrypted))