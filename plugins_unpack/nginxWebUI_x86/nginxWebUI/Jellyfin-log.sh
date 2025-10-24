docker pull jellyfin/jellyfin


docker save -o jellyfin_latest.tar jellyfin/jellyfin:latest



docker ps

docker exec -it 6237cacbbdc5 /bin/bash


docker pull cym1102/nginxwebui:latest


docker run -itd \
  -v /home/nginxWebUI:/home/nginxWebUI \
  -e BOOT_OPTIONS="--server.port=8080" \
  --net=host \
  --restart=always \
  cym1102/nginxwebui:latest