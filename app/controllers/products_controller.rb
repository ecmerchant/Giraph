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
    @account = Account.find_by(user: current_user.email)
  end

  def revise
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    @feeds = Feed.where(user: current_user.email)
    limit = ENV['PER_REVISE_NUM']
    @products = @feeds.where.not(result: "成功").page(params[:error_page]).per(PER)
    @sproducts = @feeds.where(result: "成功").page(params[:success_page]).per(PER)
    if request.post? then
      SubmitFeedJob.perform_later(current_user.email)
    end
  end

  def result
    user = current_user.email
    feed_id = Account.find_by(user: user).feed_submission_id
    #GetFeedResultJob.set(queue: :feed_result).perform_later(user, feed_id)

    Feed.new.get_result(user, feed_id)

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
    redirect_to products_show_path
  end

  def get_us_price
    user = current_user.email

    fee_check = ENV['FEE_CHECK']
    if fee_check == nil then
      fee_check = "TRUE"
    end
    condition = "New"
    GetUsPriceJob.set(queue: :us_new_item).perform_later(user, condition, fee_check)
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

  def clear
    if request.delete? then
      products = Product.where(user: current_user.email, sku_checked: false)
      products.delete_all
    end
    redirect_to products_show_path
  end

  def reset
    if request.post? then
      ItemResetJob.set(queue: :item_reset).perform_later(current_user.email)
    end
    redirect_to products_show_path
  end

  def order
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    @orders = OrderList.where(user: current_user.email)
    if request.post? then
      res = params[:order]
      start_date = Time.parse(res[:st_date]).iso8601
      end_date = Time.parse(res[:en_date]).iso8601
      logger.debug(start_date)
      logger.debug(end_date)
      OrderList.new.get_order_report(current_user.email, start_date, end_date)
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
    if request.delete? then
      @products = Product.where(user: current_user.email)
      if @products != nil then
        @products.delete_all
      end
    end
    redirect_to root_path
  end

  def download
    @products = Product.where(user: current_user.email)
    account = Account.find_by(user: current_user.email)
    account.update(
      csv_path: "データ作成中",
      csv_created_at: Time.now
    )
    if @products != nil then
      logger.debug("== start download ==")
      respond_to do |format|
        format.html do
          redirect_to products_show_path
        end
        format.csv do
          logger.debug("csv")
          #DownloadCsvJob.perform_later(current_user.email, nil)
          tt = Time.now
          strTime = tt.strftime("%Y%m%d%H%M")
          fname = "商品データ_" + strTime + ".csv"
          send_data render_to_string, filename: fname, type: :csv
          #redirect_to products_show_path
        end
      end
    end
  end

  def output
    account = Account.find_by(user: current_user.email)
    download_file_name = account.csv_path
    if download_file_name != nil then
      send_file download_file_name
    else
      redirect_to products_show_path
    end
  end

  def order_download
    respond_to do |format|
      format.html do
        redirect_to products_order_path
      end
      format.csv do
        tt = Time.now
        strTime = tt.strftime("%Y%m%d%H%M")
        fname = "注文データ_" + strTime + ".csv"
        @orders = OrderList.where(user: current_user.email)
        send_data render_to_string, filename: fname, type: :csv
      end
    end
  end

  def order_upload
    if request.post? then
      data = params[:order_list]
      if data != nil then
        list = Array.new
        CSV.foreach(data.path, encoding: "SJIS") do |buf|
          temp = buf[0]
          row = temp.split("\t")
          logger.debug(row[0])
          order_id = row[1]
          sku = row[2]
          sale = row[3].to_f
          fee = row[4].to_f
          rate = row[5].to_f
          cost = row[6].to_f
          shipping = row[7].to_f
          user = current_user.email

          if cost != nil then
            profit = (sale - fee) * rate - cost - shipping
            roi = profit / (cost + shipping + fee * rate)
            profit = profit.round(0)
            roi = (roi * 100.0).round(1)
          else
            profit = nil
            roi = nil
          end
          logger.debug(sku)
          logger.debug(order_id)
          logger.debug(cost)
          if sku != "SKU" && sku != nil then
            list << OrderList.new(user: user, order_id: order_id, sku: sku, sales: sale, cost_price: cost, listing_shipping: shipping, profit: profit, roi: roi)
          end
        end
        OrderList.import list, on_duplicate_key_update: {constraint_name: :for_upsert_order, columns: [:cost_price, :listing_shipping, :profit, :roi]}, validate: false
      end
    end
    redirect_to products_order_path
  end

  private
  def user_params
     params.require(:account).permit(:user, :shipping_weight, :max_roi, :listing_shipping, :delivery_fee, :payoneer_fee, :seller_id, :aws_access_key_id, :secret_key, :us_seller_id1, :us_aws_access_key_id1, :us_secret_key1, :us_seller_id2, :us_aws_access_key_id2, :us_secret_key2, :cw_api_token, :cw_room_id, :handling_time)
  end

end
