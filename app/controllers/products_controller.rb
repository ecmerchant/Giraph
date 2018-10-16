class ProductsController < ApplicationController

  require 'peddler'
  require 'rubyXL'
  require 'open-uri'

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  PER = 10
  def show
    @login_user = User.find_by(email: current_user.email)
    temp = Product.where(user: current_user.email)
    @counter = temp.count
    @products = temp.page(params[:page]).per(PER)
  end

  def setup
    @login_user = current_user
    @account = Account.find_or_create_by(user: current_user.email)
    if request.post? then
      @account.update(user_params)
    end
  end

  def customize
    @login_user = current_user
    @account = Account.find_or_create_by(user: current_user.email)
    @shipping_cost_A = ShippingCost.where(user: current_user.email, name: "送料表A").order(weight: "ASC")
    @shipping_cost_EMS = ShippingCost.where(user: current_user.email, name: "EMS送料表").order(weight: "ASC")
    if request.post? then
      @account.update(user_params)
    end
  end

  def shipping
    if request.post? then
      data = params[:shipping_list]
      if data != nil then
        ext = File.extname(data.path)
        if ext == ".xls" || ext == ".xlsx" then
          ftype = params[:shipping].to_i
          if ftype == 1 then
            list_name = "送料表A"
          else
            list_name = "EMS送料表"
          end

          temp = ShippingCost.where(user:current_user.email, name:list_name)
          if temp != nil then
            temp.delete_all
          end
          logger.debug("=== UPLOAD ===")
          p list_name

          workbook = RubyXL::Parser.parse(data.path)
          worksheet = workbook.first
          worksheet.each_with_index do |row, i|
            if row[0].value == nil then break end
            if i != 0 then
              weight = row[0].value.to_f
              shipping = row[1].value.to_f
              ShippingCost.find_or_create_by(
                user: current_user.email,
                name: list_name,
                weight: weight,
                cost: shipping
              )
            end
          end
        end
      end
    end
    redirect_to products_customize_path
  end

  def get_jp_price
    user = current_user.email
    condition = "New"
    GetJpPriceJob.perform_later(user, condition)
    redirect_to products_show_path
  end

  def get_us_price
    user = current_user.email
    condition = "New"
    GetUsPriceJob.perform_later(user, condition)
    redirect_to products_show_path
  end

  def get_jp_info
    user = current_user.email
    GetJpInfoJob.perform_later(user)
    redirect_to products_show_path
  end

  def import
    user = current_user.email
    if request.post? then
      data = params[:sku_list]
      if data != nil then
        ext = File.extname(data.path)
        if ext == ".xls" || ext == ".xlsx" then
          workbook = RubyXL::Parser.parse(data.path)
          worksheet = workbook.first
          sku_list = Array.new
          worksheet.each_with_index do |row, i|
            if row[0].value == nil then break end
            if i != 0 then
              asin = row[0].value.to_s
              sku = row[1].value.to_s
              sku_list << Product.new(user: user, asin: asin, sku: sku)
            end
          end
          if Rails.env == 'development'
            logger.debug("======= DEVELOPMENT =========")
            Product.import sku_list, :on_duplicate_key_update => [:asin]
            #Product.import sku_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:asin]}
          else
            logger.debug("======= PRODUCTION =========")
            Product.import sku_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:asin]}
          end
        end
      end
    end
    redirect_to products_show_path
  end

  def report
    user = current_user.email
    GetReportJob.perform_later(user)
    redirect_to products_show_path
  end

  def calculate
    user = current_user.email
    Product.new.calc_profit(user)
    redirect_to products_show_path
  end

  def exchange
    url = "https://info.finance.yahoo.co.jp/fx/"
    begin
      html = open(url) do |f|
        charset = f.charset
        f.read # htmlを読み込んで変数htmlに渡す
      end
      doc = Nokogiri::HTML.parse(html, nil)
      exrate = doc.xpath('//span[@id="USDJPY_top_bid"]')
      if exrate != nil then
        exrate = exrate.text.to_f
      end
      temp = Account.find_or_create_by(user: current_user.email)
      calc_rate = exrate * (100.0 - temp.payoneer_fee) / 100.0
      temp.update(
        exchange_rate: exrate,
        calc_ex_rate: calc_rate.round(2)
      )
      logger.debug(exrate)
    rescue OpenURI::HTTPError => error
      logger.debug("==== EXCHANGE RATE ERROR ====")
      logger.debug(error)
    end
    redirect_to products_show_path
  end

  private
  def user_params
     params.require(:account).permit(:user, :shipping_weight, :max_roi, :listing_shipping, :delivery_fee, :payoneer_fee, :seller_id, :aws_access_key_id, :secret_key, :us_seller_id1, :us_aws_access_key_id1, :us_secret_key1, :us_seller_id2, :us_aws_access_key_id2, :us_secret_key2, :cw_api_token, :cw_room_id)
  end

end
