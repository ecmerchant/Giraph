class ProductsController < ApplicationController

  require 'peddler'
  require 'rubyXL'
  require 'open-uri'

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  PER = 40
  def show
    @login_user = User.find_by(email: current_user.email)
    temp = Product.where(user: current_user.email).order("updated_at DESC")
    @counter = temp.count
    @products = temp.page(params[:page]).per(PER)
  end

  def revise
    @login_user = current_user
    limit = ENV['PER_REVISE_NUM']
    if request.post? then
      @targets = Product.where(user: current_user.email, shipping_type: "default", revised: false)
      @targets = @targets.order("calc_updated_at DESC").limit(limit)
      temp = @targets.pluck(:sku, :us_listing_price, :on_sale, :listing_condition, :shipping_type)
      @targets.update(revised: true)
      logger.debug(temp)
      tag = Product.new
      feed_id = tag.submit_feed(current_user.email, temp)
      logger.debug("====== Feed Subission ID ======")
      logger.debug(feed_id)
      logger.debug("===============================")
    else
      @account = Account.find_by(user: current_user.email)
      @feeds = Feed.where(user: current_user.email)
    end
  end

  def result
    user = current_user.email
    feed_id = Account.find_by(user: user).feed_submission_id
    GetFeedResultJob.set(queue: :feed_result).perform_later(user, feed_id)
    redirect_to products_revise_path
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
    GetJpPriceJob.set(queue: :jp_new_item).perform_later(user, condition)
    condition = "Used"
    GetJpPriceJob.set(queue: :jp_used_item).perform_later(user, condition)
    redirect_to products_show_path
  end

  def get_us_price
    user = current_user.email

    fee_check = ENV['FEE_CHECK']
    if fee_check == nil then
      fee_check = "FALSE"
    end
    condition = "New"
    GetUsPriceJob.set(queue: :us_new_item).perform_later(user, condition, fee_check)
    condition = "Used"
    GetUsPriceJob.set(queue: :us_used_item).perform_later(user, condition, fee_check)
    redirect_to products_show_path
  end

  def get_jp_info
    user = current_user.email
    GetJpInfoJob.set(queue: :jp_new_info).perform_later(user, "New")
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
            Product.import sku_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:asin]}
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
    GetReportJob.set(queue: :get_report).perform_later(user)
    redirect_to products_show_path
  end

  def calculate
    user = current_user.email
    GetCalcJob.set(queue: :item_calc).perform_later(user)
    redirect_to products_show_path
  end

  def reset
    Product.all.update(revised: false)
    redirect_to products_show_path
  end

  def order
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    if request.post? then


    else
      @orders = OrderList.where(user: current_user.email)
    end
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

  def delete
    @products = Product.where(user: current_user.email)
    if @products != nil then
      @products.delete_all
    end
    redirect_to root_path
  end

  def download

    shift = ENV['DL_SHIFT'].to_i
    range = ENV['DL_RANGE'].to_i

    @products = Product.where(user: current_user.email).offset(shift).limit(range)

    if @products != nil then
      logger.debug("== start download ==")
      respond_to do |format|
        format.html do
        end
        format.csv do
          logger.debug("csv")
          tt = Time.now
          strTime = tt.strftime("%Y%m%d%H%M")
          fname = "商品データ_" + strTime + ".csv"
          send_data render_to_string, filename: fname, type: :csv
        end
      end
    end
  end

  private
  def user_params
     params.require(:account).permit(:user, :shipping_weight, :max_roi, :listing_shipping, :delivery_fee, :payoneer_fee, :seller_id, :aws_access_key_id, :secret_key, :us_seller_id1, :us_aws_access_key_id1, :us_secret_key1, :us_seller_id2, :us_aws_access_key_id2, :us_secret_key2, :cw_api_token, :cw_room_id, :handling_time)
  end

end
