class_name Version
extends RefCounted
## Номер сборки. CI подставляет сюда номер запуска (см. .github/workflows/build.yml).
## Клиент и сервер должны совпадать — иначе сервер попросит обновиться.
const BUILD := "dev"
