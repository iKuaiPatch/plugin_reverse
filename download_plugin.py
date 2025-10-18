import requests
import json
import os, shutil

baseurl = 'https://routerostop.oss-cn-shanghai.aliyuncs.com/plugins/release'
plugins = baseurl + '/plugins.json'

with open('files.txt', 'r') as f:
    files = f.readlines()

files = [x.strip() for x in files]

def download_plugin(name: str, platform: str, version: str, build: str):
    if platform == 'all':
        filename = f'plugin-{name}-v{version}-Build{build}.ipk'
    else:
        filename = f'plugin-{name}-{platform}-v{version}-Build{build}.ipk'
    url = baseurl + '/ipk/' + filename
    print(f"Downloading {url} ...")
    r = requests.get(url)
    if r.status_code == 200:
        with open(f'./plugins/{filename}', 'wb') as f:
            f.write(r.content)
        print(f"Saved to ./plugins/{filename}")
    else:
        print(f"Failed to download {url}, status code: {r.status_code}")
    
    if url not in files:
        with open('files.txt', 'a') as f:
            f.write(url + '\n')

def get_all_plguns():
    r = requests.get(plugins)
    if r.status_code == 200:
        with open('./plugins/plugins.json', 'wb') as f:
            f.write(r.content)
        data = r.json()
        for plugin in data:
            name = plugin['name']
            version = plugin['version']
            build = plugin['build']
            platform = plugin['compatibility']
            if platform[0] == 'all':
                download_plugin(name, 'all', version, build)
            else:
                for p in platform:
                    download_plugin(name, p, version, build)

if __name__ == '__main__':
    get_all_plguns()