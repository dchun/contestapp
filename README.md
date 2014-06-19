####Chapter 2 - Setting Up
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

modify Gemfile
```
group :development, :test do
  gem "sqlite3"
end
```

run commands
```
bundle install

git add --all
git commit -am "Required Heroku gems"
git push

heroku create contestapp
git push heroku master
heroku run rake db:migrate

heroku open
```
####Chapter 3 - Building A Private App

run command
```
git checkout -b ch03_01_gem_updates
```

add to Gemfile inside development and test group
```
# Helpful gems
gem "better_errors" # improves error handling
gem "binding_of_caller" # used by better errors
# Testing frameworks
gem 'rspec-rails' # testing framework
gem "factory_girl_rails" # use factories, not fixtures
gem "capybara" # simulate browser activity
gem "fakeweb"
# Automated testing
gem 'guard' # automated execution of test suite upon change
gem "guard-rspec" # guard integration with rspec
# Only install the rb-fsevent gem if on Max OSX
gem 'rb-fsevent' # used for Growl notifications
```

run commands
```
bundle install

rails generate rspec:install

guard init rspec

git add --all
git commit -am "Added gems for testing"
git checkout master
git merge ch03_01_gem_updates
git push
```

make a private app and run commands
```
git checkout -b ch03_02_shopify_credentials

rails g scaffold Account shopify_account_url:string shopify_api_key:string shopify_password:string shopify_shared_secret:string

bundle exec rake db:migrate
bundle exec rake db:migrate RAILS_ENV=test

rails g bootstrap:themed Accounts -f

bundle exec guard
```

modify app/views/layouts/application.html.erb
```
<a class="brand" href="/">Contestapp</a>
<div class="container-fluid nav-collapse">
	<ul class="nav">
		<li><%= link_to "Accounts", accounts_path%></li>
	</ul>
</div><!--/.nav-collapse -->
```

add to app/models/account.rb
```
validates_presence_of :shopify_account_url
validates_presence_of :shopify_api_key
validates_presence_of :shopify_password
validates_presence_of :shopify_shared_secret
```

run commands
```
git add --all
git commit -am "Account model and related files"
git checkout master
git merge ch03_02_shopify_credentials
git push
```


