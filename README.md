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

#####Section 1
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

#####Section 2
make a private shopify app and run commands
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

#####Section 3
run command
```
git checkout -b ch03_03_shopify_connection
```

add to Gemfile
```
gem 'shopify_api'
```

run command
```
bundle install
```

create file app/services/shopify_integration.rb
```ruby
class ShopifyIntegration

  attr_accessor :api_key, :shared_secret, :url, :password

  def initialize(params)
    # Ensure that all the parameters are passed in
    %w{api_key shared_secret url password}.each do |field|
      raise ArgumentError.new("params[:#{field}] is required") if params[field.to_sym].blank?

      # If present, then set as an instance variable
      instance_variable_set("@#{field}", params[field.to_sym])
    end
  end

  # Uses the provided credentials to create an active Shopify session
  def connect

    # Initialize the gem
    ShopifyAPI::Session.setup({api_key: @api_key, secret: @shared_secret})

    # Instantiate the session
    session = ShopifyAPI::Session.new(@url, @password)

    # Activate the Session so that requests can be made
    return ShopifyAPI::Base.activate_session(session)

  end

  def import_orders

    # Local variables
    created = failed = 0
    page = 1


    # Get the first page of orders
    shopify_orders = ShopifyAPI::Order.find(:all, params: {limit: 50, page: page})

    # Keep going while we have more orders to process
    while shopify_orders.size > 0

      shopify_orders.each do |shopify_order|

        # See if we've already imported the order
        order = Order.find_by_shopify_order_id(shopify_order.id)

        unless order.present?

          # If not already imported, create a new order
          order = Order.new(number: shopify_order.name,
                            email: shopify_order.email,
                            first_name: shopify_order.billing_address.first_name,
                            last_name: shopify_order.billing_address.last_name,
                            shopify_order_id: shopify_order.id,
                            order_date: shopify_order.created_at,
                            total: shopify_order.total_price,
                            financial_status: shopify_order.financial_status
                            )

          # Iterate through the line_items
          shopify_order.line_items.each do |line_item|
            variant = Variant.find_by_shopify_variant_id(line_item.variant_id)
            if variant.present?
              order.order_items.build(variant_id: variant.id,
                                      shopify_product_id: line_item.product_id,
                                      shopify_variant_id: line_item.id,
                                      quantity:  line_item.quantity,
                                      unit_price: line_item.price)
            end
          end

          if order.save
            created += 1
          else
            failed += 1
          end
        end

      end

      # Grab the next page of products
      page += 1
      shopify_orders = ShopifyAPI::Order.find(:all, params: {limit: 50, page: page})


    end

    # Once we are done, return the results
    return {created: created,  failed: failed}
  end

  def import_products

    # Local variables
    created = failed = updated = 0
    page = 1

    # Grab the first page of products
    shopify_products = ShopifyAPI::Product.find(:all, params: {limit: 100, page: page})

    # Keep looping until no more products are returned
    while shopify_products.size > 0

      shopify_products.each do |shopify_product|

        # See if the product exists
        product = Product.find_by_shopify_product_id(shopify_product.id)

        # If so, attempt to update it
        if product.present?
          unless product.update_attributes(last_shopify_sync: DateTime.now, name: shopify_product.title)
            failed += 1
            next
          end
        else

          # Otherwise, create it
          product = Product.new(last_shopify_sync: DateTime.now, name: shopify_product.title, shopify_product_id: shopify_product.id)
          unless product.save
            failed += 1
            next
          end
        end

        # Iterate through the variants
        shopify_product.variants.each do |shopify_variant|

          # See if the variant exists
          variant = Variant.find_by_shopify_variant_id(shopify_variant.id)
          if variant.present?
            # If so, update it
            if variant.update_attributes(sku: shopify_variant.sku, barcode: shopify_variant.barcode, option1: shopify_variant.option1, option2: shopify_variant.option2, option3: shopify_variant.option3, product_id: product.id, shopify_variant_id: shopify_variant.id, price: shopify_variant.price, last_shopify_sync: DateTime.now)
              updated += 1
            else
              failed += 1
            end
          else
            # Otherwise create it
            if Variant.create(sku: shopify_variant.sku, barcode: shopify_variant.barcode, option1: shopify_variant.option1, option2: shopify_variant.option2, option3: shopify_variant.option3, product_id: product.id, shopify_variant_id: shopify_variant.id, price: shopify_variant.price, last_shopify_sync: DateTime.now)
              created += 1
            else
              failed += 1
            end
          end
        end

      end

      # Grab the next page of products
      page += 1
      shopify_products = ShopifyAPI::Product.find(:all, params: {limit: 100, page: page})


    end

    # Return the results once no more products are left
    return {created: created, updated: updated, failed: failed}

  end

end
```

add to config/routes.rb
```ruby
  resources :accounts do
    member do
      get 'test_connection'
    end
  end
```

modify app/controllers/accounts_controller.rb
```ruby
  before_action :set_account, only: [:show, :edit, :update, :destroy, :test_connection]
```

add to app/controllers/accounts_controller.rb
```ruby
  # GET /accounts/1/test_connection
  # GET /accounts/1/test_connection.json
  def test_connection
    # Connect to Shopify using our class
    ShopifyIntegration.new(api_key: @account.shopify_api_key,
                           shared_secret: @account.shopify_shared_secret,
                           url: @account.shopify_account_url,
                           password: @account.shopify_password).connect()
    begin
      # The gem will throw an exception if unable to retrieve Shop information
      shop = ShopifyAPI::Shop.current
    rescue => ex
      @message = ex.message
    end

    if shop.present?
      respond_to do |format|
        # Report the good news
        format.html { redirect_to @account, notice: "Successfully Connected to #{shop.name}" }
        format.json { render json: "Successfully Connected to #{shop.name}" }
      end
    else
      respond_to do |format|
        # Return the message from the exception
        format.html { redirect_to @account, alert: "Unable to Connect: #{@message}" }
        format.json { render json: "Unable to Connect: #{@message}", status: :unprocessable_entity }
      end
    end
  end
```

add to app/views/account/show.html.erb
```
  <%= link_to "Test Connection", test_connection_account_path(@account),
              :class => 'btn' %>
```

run commands
```
git add --all
git commit -am "Shopify connection and related UI"
git checkout master
git merge ch03_03_shopify_connection
git push
```

#####Section 4
run command
```
git checkout -b ch03_04_product_import
```

run commands
```
rails g scaffold Product name:string shopify_product_id:integer last_shopify_sync:datetime

rails g scaffold Variant product_id:integer:index shopify_variant_id:integer option1:string option2:string option3:string sku:string barcode:string price:float last_shopify_sync:datetime

bundle exec rake db:migrate
       
bundle exec rake db:migrate RAILS_ENV=test

rails g bootstrap:themed Products -f

rails g bootstrap:themed Variants -f
```

add to app/views/layouts/application.html.erb
```
<ul class="nav">
	<li><%= link_to "Products", products_path  %></li>
	<li><%= link_to "Accounts", accounts_path  %></li>
</ul>
```

modify app/models/product.rb
```ruby
  has_many :variants
```

modify app/models/variant.rb
```ruby
  belongs_to :product
```

modify config/routes.rb
```ruby
resources :products do
  resources :variants
end
```

add to app/controllers/variants_controller.rb
```ruby
  before_action :set_product  
```
```ruby
  def set_product
    @product = Product.find(params[:product_id])
  end
```

modify app/controllers/variants_controller.rb
```ruby
  def set_variant
    @variant = @product.variants.find(params[:id])
  end
```

modify config/routes/rb
```ruby
resources :products do
  collection do
    get 'import'
  end
  resources :variants
end
```

add to app/controllers/products_controller.rb
```ruby
# GET /products/import
# GET /products/import.json
  def import
  # For now we'll use the first Account in the database
    account = Account.first
  # Instantiate the ShopifyIntegration class
    shopify_integration = ShopifyIntegration.new(
    api_key: account.shopify_api_key,
    shared_secret: account.shopify_shared_secret,
    url: account.shopify_account_url,
    password: account.shopify_password)
    respond_to do |format|
      shopify_integration.connect
      result = shopify_integration.import_products
      format.html { redirect_to ({action: :index}), notice: "#{result[:created].to_i} created, #{result[:updated]} updated, #{result[:failed]} failed." }
    end 
  end
```

add to app/views/products/index.html.erb
```
<p><a href="<%= import_products_path %>">Import Products</a></p>
```

run commands
```
git add --all
git commit -am "Shopify Product Import"
git checkout master
git merge ch03_04_product_import
git push
```

#####Section 5
run command
```
git checkout -b ch03_05_order_import
```

run commands
```
rails g scaffold Order number:string email:string first_name:string last_name:string shopify_order_id:integer order_date:datetime total:float line_item_count:integer financial_status:string
       
rails g model OrderItem order_id:integer:index variant_id:integer:index shopify_product_id:integer:integer shopify_variant_id:integer:index unit_price:float quantity:integer

bundle exec rake db:migrate
       
bundle exec rake db:migrate RAILS_ENV=test

rails g bootstrap:themed Orders -f
```

add to app/models/order.rb
```ruby
  has_many :order_items
```

add to app/models/order_item.rb
```ruby
  belongs_to :order
```

add to app/views/layouts/application.html.erb
```
<li><%= link_to "Orders", orders_path %></li>
```

run commands
```
git add --all
git commit -am "Shopify connection and related UI"
git checkout master
git merge ch03_05_order_import
git push
```

#####Section 6
run command
```
git checkout -b ch03_06_ui_cleanup
```

modify app/views/layouts/application.html.erb
```
<div class="row-fluid">
     <% if content_for?(:sidebar) %>
     <div class="span3">
       <div class="well sidebar-nav">
         <%= yield(:sidebar) %>
        </div>
      </div>
      <div class="span9">
        <%= bootstrap_flash %>
           <%= yield %>
      </div>
      <% else %>
        <div class="span12">
           <%= bootstrap_flash %>
              <%= yield %>
           </div>
      <% end %>
</div>
```

add to app/views/dashboard/index.html.erb
```
<%- content_for :sidebar do-%>
	<h4>Welcome!</h4>
	<p>This is the Dashboard for your account.  You'll be able to
	view past contest results, as well as create new ones.</p>
<%- end -%>
```

run commands
```
git add --all
git commit -am "UI cleanup"
git checkout master
git merge ch03_06_ui_cleanup
git push
```

#####Section 7
run command
```
git checkout -b ch03_07_winner_selection
```

create and add to app/services/contest_results.rb
```ruby
class ContestResults
  def initialize(array)
    raise ArgumentError.new("array is required") if array.blank?
    @array = array
  end

  #Picks <count> winners
  def results(count=1)
    if count.to_i < 2
      @array.sample
    else
      @array.sample(count)
    end 
  end
end
```

run commands
```
git add --all
git commit -am "Random winner selection"
git checkout master
git merge ch03_07_winner_selection
git push
```

#####Section 8
run command
```
git checkout -b ch03_08_contests
```

modify app/views/dashboard/index.html.erb
```
<%- content_for :sidebar do -%>
  <h4>New Contest</h4>
  <p>Use the form below to run a new Contest. Fields marked
   with * are required.</p>
  <form>
    <div class="control-group">
      <label for="name">Contest Name *</label>
      <div class="controls">
        <input type="text" class="text_field" id="name"
        class="name" required/>
      </div>
    </div>
    <div class="control-group">
      <label for="name">Type *</label>
      <div class="controls">
        <select id="product" name="product" required>
          <option>Any Product</option>
          <optgroup label="Specific Product">
            <option>Product A</option>
            <option>Product B</option>
          </optgroup>
        </select>
      </div>
    </div>
    <div class="control-group">
      <label for="name">Order Date Range (optional)</label>
      <div class="controls">
        <input type="text" class="text_field" id="from-
        date" name="from-date"/> to
        <input type="text" class="text_field" id="to-date"
        name="to-date"/>
      </div>
    </div>
    <div class="control-group">
      <label for="name">Max # (optional)</label>
      <div class="controls">
        <input type="text" class="text_field" id="limit"
        name="limit"/>
      </div>
    </div>
    <div class="form-actions">
      <input type="submit" value="Submit" class="btn"/>
      <%= link_to t('.cancel', :default =>
        t("helpers.links.cancel")),
        dashboard_index_path, :class => 'btn' %>
    </div>
  </form>
<%- end -%>

<h1>Contests</h1>
<table class="table table-striped">
  <thead> 
    <tr>
      <th>Name</th>
      <th>Criteria</th>
      <th>Winner</th>
      <th>Date</th>
    </tr>
  </thead>
  <tbody>
   <tr>
     <td>Customer Appreciation Giveaway</td>
     <td>Purchase made within last 30 days</td>
     <td>Order #1010, John Doe</td>
     <td>October 22, 2013</td>
   </tr>
 </tbody>
</table>
```

add to config/routes.rb
```ruby
get "dashboard/index"
```

run commands
```
rails g model Contest name:string product_id:integer start_date:datetime end_date:datetime max_results:integer order_id:integer:index

bundle exec rake db:migrate

bundle exec rake db:migrate RAILS_ENV=test
```

add to app/models/contest.rb
```ruby
  belongs_to :order
  validates_presence_of :name
  def criteria
    results = []
    results << "Product Name: #{product_name}" if
    product_name.present?
    results << "Start Date: #{I18n.l start_date.to_date,
    format: :short}" if start_date.present?
    results << "End Date: #{I18n.l end_date.to_date,
    format: :short}" if end_date.present?
    results << "Max #: #{max_results}" if
    max_results.present?
    return results.join(', ')
  end
```

add to app/models/order.rb
```ruby
  # This method constructs the query based on
  # the passed-in parameters
  def self.candidate_list(params={})
    params[:order] ||= "order_date asc"
    orders = order(params[:order]).includes(:order_items)
    if params[:limit].present?
      orders = orders.limit(params[:limit].to_i)
    end
    if params[:product_id].present?
      orders = orders.where("order_items.shopify_product_id" =>
        params[:product_id].to_i)
    end
    if params[:start_date].present?
      orders = orders.where(["orders.order_date >= ?",
        params[:start_date]])
    end
    if params[:end_date].present?
      orders = orders.where(["orders.order_date <= ?",
        params[:end_date]])
    end
    
    # .pluck returns an array containing the specified field
    return orders.pluck(:id).uniq
  end
```

modify app/controllers/dashboard_controller.rb
```ruby
  def index
    # Load past results in reverse order
    @contests = Contest.order("created_at desc")
         
    # Instantiate a new Contest so the form loads properly
    @contest = Contest.new

    # Load the Products we want to use for Contests
    @products = Product.all.order(:name)
  end

  # This method creates a Contest and returns
  # the winner(s) in the notice message
  def create_contest
    @contest = Contest.new(contest_params)
  
    # Store the name of the product for easier readability
    @contest.product_name = Product.find_by_shopify_product_id(contest_params[:product_id]).try(:name) if contest_params[:product_id].present?
    respond_to do |format|
      if @contest.save
        # Pick a winner
        candidates = Order.candidate_list(params)
        contest_results = ContestResults.new(candidates)
           
        # Save the winner
        @contest.update_attribute(:order_id, contest_results.results)
        format.html { redirect_to root_path, notice: "Contest Winner: <a href='#{order_path(@contest.order)}'>#{@contest.order.email}</a>" }
        format.json { render action: 'show', status: :created, location: @contest }
      else
        format.html { redirect_to root_path, alert: "Unable to create a Contest" }
        format.json { render json: @contest.errors, status: :unprocessable_entity }
      end 
    end
  end

private
  def contest_params
    params.require(:contest).permit(:name, :product_id, :start_date, :end_date, :max_results, :order_id)
  end
```

add to config/routes.rb
```ruby
post "create_contest" => 'dashboard#create_contest'
```

replace app/views/dashboard/index.html.erb
```ruby
<%- model_class = Contest -%>
<%- content_for :sidebar do -%>
<h4>New Contest</h4>
<p>Use the form below to run a new Contest. Fields marked with * are required.</p>
  <%= form_for @contest, :url => create_contest_path do |f| %>
    <div class="control-group">
       <%= f.label :name, "Contest Name *"  %>
      <div class="controls">
        <%= f.text_field :name, :class => 'text_field', :required => true %>
      </div>
    </div>
    <div class="control-group">
      <%= f.label :product_id, "Type *" %>
      <div class="controls">
        <select id="contest_product_id" name="contest[product_id]" required="required">
          <option>Any Product</option>
          <optgroup label="Specific Product">
            <%- @products.each do |product| -%>
              <option value="<%= product.shopify_product_id %>"><%= product.name %></option>
            <%- end -%>
          </optgroup>
        </select>
      </div>
    </div>
    <div class="control-group">
      <%= f.label :start_date, "Order Date Range (optional)" %>
      <div class="controls">
        <%= f.text_field :start_date, :class => 'text_field' %>
        <%= f.text_field :end_date, :class => 'text_field' %>
      </div>
    </div>
    <div class="control-group">
      <%= f.label :max_results, "Max # (optional)" %>
      <div class="controls">
        <%= f.text_field :max_results, :class => 'text_field' %>
      </div>
    </div>
    <div class="form-actions">
      <input type="submit" value="Submit" class="btn"/>
      <%= link_to t('.cancel', :default => t("helpers.links.cancel")),
      root_path, :class => 'btn' %>
    </div>
    <!-- End form -->
  <%- end -%>
  <!-- End sidebar -->
<%- end -%>
<h1>Contests</h1>
<table class="table table-striped">
  <thead>
    <tr>
      <th>Name</th>
      <th>Criteria</th>
      <th>Winner</th>
      <th>Date</th>
    </tr>
  </thead>
  <tbody>
    <% @contests.each do |contest| %>
    <tr>
      <td><%= contest.name %></td>
      <td><%= contest.criteria %></td>
      <% if contest.order.present? %>
      <td>Order <%= link_to contest.order.number, order_path(contest.order) %>, <%= contest.order.first_name %> <%= contest.order.last_name %> (<%= mail_to contest.order.email, contest.order.email %>)</td>
      <% else %>
        <td>Error picking winner</td>
      <% end %>
      <td><%=l contest.created_at, format: :long %></td>
    </tr>
    <% end %>
  </tbody>
</table>
```