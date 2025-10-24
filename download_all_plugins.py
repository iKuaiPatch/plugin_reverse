import requests
import json

with open('plugins.json', 'r', encoding='utf-8') as f:
    plugins = json.load(f)

urls = []

# url="$RMT_PLUGIN_BASE_URL/ipk/$platform/$name.ipk"
url = 'https://ikuai8-app.oss-cn-beijing.aliyuncs.com/plugins/releasev8/'
for plugin in plugins:
    name = plugin['name']
    platform = plugin['compatibility']
    for pf in platform:
        download_url = f"{url}ipk/{pf}/{name}.ipk"
        urls.append(download_url)
        print(f"Downloading {download_url} ...")
        r = requests.get(download_url)
        if r.status_code == 200:
            with open(f"plugins/{name}_{pf}.ipk", 'wb') as f:
                f.write(r.content)
        else:
            print(f"Failed to download {download_url}, status code: {r.status_code}")

with open('files.txt', 'r') as f:
    files = f.readlines()

for url in urls:
    if url not in files:
        with open('files.txt', 'a') as f:
            f.write(url + '\n')
        print(f"Added {url} to files.txt")
