# Auto LaTeX Compiler

## Prepare

- Setup LXD, LXC CLI (Only Docker, Orbstack is OK)
- Target Directory (example: /home/test-latex)

## Process

1. launch LXC Container (ex: `lxc launch images:alpine/23 my-docker`)
2. mount directory into LXC container (ex: `lxc config device add my-docker shared disk source=/home/test-latex path=/mnt/shared`)
3. change execute mode on `watch.sh` (ex: `chmod +x watch.sh`)
4. add tex files into `source` directory.
5. run this command inside lxc container

If you have only Docker, please run `docker compose up -d`.

If there isn't some packages, create `Dockerfile`, and write code.
