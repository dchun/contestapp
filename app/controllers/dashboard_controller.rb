class DashboardController < ApplicationController
  # GET /
  def index

    # Instantiate a new Contest so the form loads properly
    @contest = Contest.new

    # Load past results in reverse order
    @contests = current_account.contests.order("created_at desc")

    # Load the Products we want to use for Contests
    @products = current_account.products.order(:name)

  end

  # This method creates a Contest and returns the winner(s) in the notice message
  def create_contest
    @contest = current_account.contests.new(contest_params)

    respond_to do |format|
      if @contest.save

        # Pick a winner
        candidates = current_account.orders.candidate_list(params)
        contest_results = ContestResults.new(candidates)
        @contest.update_attribute(:order_id,contest_results.results)


        format.html { redirect_to root_path, notice: "Contest Winner: <a href='#{order_path(@contest.order)}'>#{@contest.order.email}</a>" }
        format.json { render action: 'show', status: :created, location: @order }

      else
        format.html { rredirect_to root_path, alert: "Unable to create a Contest" }
        format.json { render json: @contest.errors, status: :unprocessable_entity }
      end
    end

  end

  # GET /accounts/1/test_connection
  # GET /accounts/1/test_connection.json
  def test_connection
    # Connect to Shopify using our class
    ShopifyIntegration.new(url: current_account.shopify_account_url,
                           password: current_account.shopify_password,
                           account_id: current_account.id).connect()
    begin
      # The gem will throw an exception if unable to retrieve Shop information
      shop = ShopifyAPI::Shop.current
    rescue => ex
      @message = ex.message
    end

    if shop.present?
      respond_to do |format|
        # Report the good news
        format.html { redirect_to dashboard_index_path, notice: "Successfully Connected to #{shop.name}" }
        format.json { render json: "Successfully Connected to #{shop.name}" }
      end
    else
      respond_to do |format|
        # Return the message from the exception
        format.html { redirect_to dashboard_index_path, alert: "Unable to Connect: #{@message}" }
        format.json { render json: "Unable to Connect: #{@message}", status: :unprocessable_entity }
      end
    end
  end

  private

  # Never trust parameters from the scary internet, only allow the white list through.
  def contest_params
    params.require(:contest).permit(:name, :product_id, :start_date, :end_date, :max_results, :order_id)
  end
end
