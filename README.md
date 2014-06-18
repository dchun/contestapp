run commands
```
mkdir contestapp
cd contestapp
rvm --ruby-version use 2.1.2@contestapp --create

gem install rails -v 4.0.3 --no-ri --no-rdoc
rails new .
bundle install

rails generate controller Dashboard index
```

add to config/routes.rb
```
root 'dashboard#index'
```

add to Gemfile
```
gem "execjs"
gem "twitter-bootstrap-rails"
gem "bootstrap-sass"
```

run commands
```
bundle install
rails generate bootstrap:install sass
rails g bootstrap:layout application fluid -f
```

run commands
```
git init
git remote add origin path_to_remote_repository
git add --all
git commit -am "Initial commit"
git push -u origin master
```

add to Gemfile
```
ruby '2.1.2'
group :production do
  gem "rails_12factor"
  gem "pg"
end
```

modify Gemfiel
```
group :development, :test do
  gem "sqlite3"
end
```

run command
```
bundle install
```