import requests, os

with open('./files.txt', 'r') as f:
    urls = f.readlines()

save_dir = './backup_files'

# 下载所有文件，并根据路径中的文件夹结构保存
for url in urls:
    url = url.strip()
    if not url:
        continue
    print(f"Downloading {url} ...")
    r = requests.get(url)
    if r.status_code == 200:
        path_parts = url.split('/')[3:]  # 去掉前面的域名部分
        file_path = os.path.join(save_dir, *path_parts)
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, 'wb') as f:
            f.write(r.content)
        print(f"Saved to {file_path}")
    else:
        print(f"Failed to download {url}, status code: {r.status_code}")