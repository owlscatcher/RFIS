# Rails: fast-init script

This script:
- Created/set-up new docker images and init rails project
- Createed/set-up docker-compose file and attached postgres database
- Added esling and rubocop into project

## How tu use?
Just clone repos and start script:
```
git clone https:/github.com/owlscatcher/RFIS \
  cd ./RFIS \
  sudo chmod +X init-new-project.sh \
  sh init-new-project.sh
```

## Dependency
- docker && docker-compose
