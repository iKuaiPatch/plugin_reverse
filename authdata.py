import base64
import os
from sh2c_decrypt import find_and_decrypt

if os.path.exists('authdata'):
    os.remove('authdata')

os.mkdir('authdata')

with open('authdata.b64', 'r') as f:
    authdata = f.read()

with open('./authdata/authdata', 'wb') as f:
    f.write(base64.b64decode(authdata))

find_and_decrypt('./authdata')
