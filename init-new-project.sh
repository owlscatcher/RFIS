#!/bin/bash

read -p 'Input project name: ' PROJECT_NAME

mkdir $PROJECT_NAME && cd ./$PROJECT_NAME

touch Dockerfile docker-compose.yml

echo 'FROM ruby:2.7.1-alpine' > Dockerfile
echo '' >> Dockerfile
echo 'ARG RAILS_ROOT=/'$PROJECT_NAME'' >> Dockerfile
echo 'ARG PACKAGES="vim openssl-dev postgresql-dev build-base curl nodejs yarn less tzdata git postgresql-client bash screen"' >> Dockerfile
echo '' >> Dockerfile
echo 'RUN apk update \' >> Dockerfile
echo '    && apk upgrade \' >> Dockerfile
echo '    && apk add --update --no-cache $PACKAGES' >> Dockerfile
echo '' >> Dockerfile
echo 'RUN gem install bundler:2.1.4' >> Dockerfile
echo '' >> Dockerfile
echo 'RUN mkdir $RAILS_ROOT' >> Dockerfile
echo 'WORKDIR $RAILS_ROOT' >> Dockerfile
echo '' >> Dockerfile
echo 'ADD . $RAILS_ROOT' >> Dockerfile
echo 'ENV PATH=$RAILS_ROOT/bin:${PATH}' >> Dockerfile
echo '' >> Dockerfile
echo 'EXPOSE 3000' >> Dockerfile
echo "CMD bundle exec rails s -b '0.0.0.0' -p 3000" >> Dockerfile

docker build -t $PROJECT_NAME .
docker run -v $(pwd):/$PROJECT_NAME $PROJECT_NAME bash -c "gem install rails pg && rails new /$PROJECT_NAME --database=postgresql --javascript=webpack --skip-hotwire --skip-spring --skip-turbolinks"

sed -i 's/WORKDIR $RAILS_ROOT/WORKDIR $RAILS_ROOT\n\nCOPY Gemfile Gemfile.lock .\/\nRUN bundle install --jobs 5\n\nCOPY package.json yarn.lock .\/\nRUN yarn install --frozen-lockfile/g' Dockerfile

sudo chown -cR $(id -u):$(id -g) ./

docker build -t $PROJECT_NAME .

echo "version: '3.7'" > docker-compose.yml
echo ""
echo "services:" >> docker-compose.yml
echo "  web:" >> docker-compose.yml
echo "    build: ." >> docker-compose.yml
echo "    volumes: &web-volumes" >> docker-compose.yml
echo "      - &app-volume .:/$PROJECT_NAME:cached" >> docker-compose.yml
echo "      - ~/.ssh:/root/.ssh" >> docker-compose.yml
echo "      - ~/.bash_history:/root/.bash_history" >> docker-compose.yml
echo "      - &bundle-cache-volume bundle_cache:/bundle_cache" >> docker-compose.yml
echo "    ports:" >> docker-compose.yml
echo "      - 3000:3000" >> docker-compose.yml
echo "      - 3001:3001" >> docker-compose.yml
echo "      - 3002:3002" >> docker-compose.yml
echo "    depends_on:" >> docker-compose.yml
echo "      - db" >> docker-compose.yml
echo "    environment: &web-environment" >> docker-compose.yml
echo "      BUNDLE_PATH: /bundle_cache" >> docker-compose.yml
echo "      GEM_HOME: /bundle_cache" >> docker-compose.yml
echo "      GEM_PATH: /bundle_cache" >> docker-compose.yml
echo "      RAILS_PORT: 3000" >> docker-compose.yml
echo "      RUBYOPT: -W:no-deprecated -W:no-experimental" >> docker-compose.yml
echo "    command: bundle exec rails s -b "0.0.0.0" -p 3000" >> docker-compose.yml
echo "" >> docker-compose.yml
echo "  db:" >> docker-compose.yml
echo "    image: postgres:11.4" >> docker-compose.yml
echo "    ports:" >> docker-compose.yml
echo "      - 5432:5432" >> docker-compose.yml
echo "    environment:" >> docker-compose.yml
echo "      POSTGRES_USER: postgres" >> docker-compose.yml
echo "      POSTGRES_PASSWORD: postgres" >> docker-compose.yml
echo "" >> docker-compose.yml
echo "volumes:" >> docker-compose.yml
echo "  bundle_cache:" >> docker-compose.yml

sudo chown -cR $(id -u):$(id -g) ./

docker-compose build
docker-compose run --rm web bash -c "bundle install"

sudo chown -cR $(id -u):$(id -g) ./

echo "default: &default" > ./config/database.yml
echo "  adapter: postgresql" >> ./config/database.yml
echo "  host: <%= ENV['DATABASE_HOST'] || 'localhost' %>" >> ./config/database.yml
echo "  username: <%= ENV['DATABASE_USERNAME'] || nil %>" >> ./config/database.yml
echo "  password: <%= ENV['DATABASE_PASSWORD'] %>" >> ./config/database.yml
echo "  encoding: unicode" >> ./config/database.yml
echo "" >> ./config/database.yml
echo "development:" >> ./config/database.yml
echo "  <<: *default" >> ./config/database.yml
echo "  database: <%= ENV['DATABASE_NAME'] || '"$PROJECT_NAME"_development' %>" >> ./config/database.yml
echo "" >> ./config/database.yml
echo "test:" >> ./config/database.yml
echo "  <<: *default" >> ./config/database.yml
echo "  database: "$PROJECT_NAME"_test" >> ./config/database.yml
echo "  port: <% (ENV['CI_NAME'] == 'codeship') ? 5433 : 5432 %>" >> ./config/database.yml
echo "" >> ./config/database.yml
echo "production:" >> ./config/database.yml
echo "  <<: *default" >> ./config/database.yml
echo "  database: <%= ENV['DATABASE_NAME'] %>" >> ./config/database.yml
echo "  username: <%= ENV['DATABASE_USERNAME'] %>" >> ./config/database.yml
echo "  password: <%= ENV['DATABASE_PASSWORD'] %>" >> ./config/database.yml
echo "  host: <%= ENV['DATABASE_HOST'] %>" >> ./config/database.yml
echo "  port: <%= ENV['DATABASE_PORT'] %>" >> ./config/database.yml

sed -i 's/RUBYOPT: -W:no-deprecated -W:no-experimental/RUBYOPT: -W:no-deprecated -W:no-experimental\n      DATABASE_HOST: db\n      DATABASE_USERNAME: postgres\n      DATABASE_PASSWORD: postgres/g' docker-compose.yml
sed -i "s/group :development, :test do/group :development, :test do\n\tgem 'factory_bot_rails'\n\tgem 'rubocop'/g" Gemfile
sed -i 's/"private": "true",/"private": "true",\n\t"scripts": {\n\t\t"lint": "node_modules\/.bin\/eslint app\/javascript"\n\t},/g' package.json

cp ../dotfiles/.* ./

docker-compose run --rm web bash -c "rails db:create db:migrate"
docker-compose run --rm web bash -c "bundle install"
docker-compose run --rm web bash -c "bundle exec rubocop -a"
docker-compose up