class ProductsController < ApplicationController

  require 'peddler'
  before_action :authenticate_user!, only: :get

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def show
    @login_user = User.find_by(email: current_user.email)
  end

  def setup
    @login_user = current_user
    @account = Account.find_or_create_by(user: current_user.email)
    if request.post? then
      @account.update(user_params)
    end
  end

  def get_jp_price
    user = current_user.email
    Product.new.check_amazon_jp_price(user,"")
    redirect_to products_show_path
  end

  def report
    user = current_user.email
    GetReportJob.perform_later(user)
    redirect_to products_show_path
  end

  private
  def user_params
     params.require(:account).permit(:user, :seller_id, :aws_access_key_id, :secret_key, :cw_api_token, :cw_room_id)
  end

end
