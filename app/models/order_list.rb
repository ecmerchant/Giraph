class OrderList < ApplicationRecord

  require 'peddler'
  require 'activerecord-import'

  def get_order_report(user, start_date, end_date)
    logger.debug("===== START ORDER REPORT =====")
    per_num = ENV['PER_LIST_NUM']
    if per_num == nil then
       per_num = 1000
    else
      per_num = per_num.to_i
    end
    mp = "ATVPDKIKX0DER"  #アメリカアマゾン
    account = Account.find_by(user: user)
    sid = account.us_seller_id1
    skey = account.us_secret_key1
    awskey = account.us_aws_access_key_id1
    orders = OrderList.where(user: user)
    report_type = "_GET_FLAT_FILE_ORDERS_DATA_"
    products = Product.where(user: user)
    ex_rate = account.calc_ex_rate

=begin
    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n注文レポート取得開始\n開始時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )
=end
    client = MWS.reports(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    mws_options = {
      start_date: start_date,
      end_date: end_date
    }

    response = client.request_report(report_type, mws_options)
    parser = response.parse
    reqid = parser.dig('ReportRequestInfo', 'ReportRequestId')

    mws_options = {
      report_request_id_list: reqid,
    }
    process = ""
    logger.debug(reqid)

    once = false
    dcounter = 0

    sleep(10)
    while process != "_DONE_" && process != "_DONE_NO_DATA_" && process != "_CANCELLED_"
      response = client.get_report_request_list(mws_options)
      parser = response.parse
      process = parser.dig('ReportRequestInfo', 'ReportProcessingStatus')
      logger.debug(process)
      if process == "_DONE_" then
        genid = parser.dig('ReportRequestInfo', 'GeneratedReportId')
        break
      elsif process == "_DONE_NO_DATA_" then
        genid = "NODATA"
        break
      elsif process == "_CANCELLED_" then
        genid = "NODATA"
        break
      end
      sleep(10)
    end

    logger.debug("====== GENERATE ID =======")
    logger.debug(genid)

    if genid.to_s != "NODATA" then
      response = client.get_report(genid)
      parser = response.parse
      logger.debug("====== REPORT DATA OK =======")
      counter = 0
      parser.each_slice(per_num) do |rows|
        sku_lists = Array.new
        rows.each do |row|
          sku = row[7].to_s
          order_id = row[0].to_s
          quantity = row[9].to_i
          sale = row[11].to_f
          order_date = row[2].in_time_zone

          tag = orders.find_by(sku: sku)
          if tag != nil then
            cost = tag.cost_price
            shipping = tag.listing_shipping
          else
            cost = nil
            shipping = nil
          end
          calc_rate = ex_rate

          temp = products.find_by(sku: sku)
          if temp != nil then
            amazon_fee = temp.referral_fee_rate * sale + temp.variable_closing_fee.to_f
            amazon_fee = amazon_fee.round(2)
          else
            amazon_fee = nil
          end

          if cost != nil then
            profit = (sale - amazon_fee) * calc_rate - cost - shipping
            roi = profit / (cost + shipping + amazon_fee * calc_rate)
          else
            profit = nil
            roi = nil
          end

          logger.debug("==== VARIAIBLE =====")
          logger.debug(sku)
          logger.debug(order_id)
          logger.debug(sale)
          logger.debug(quantity)
          logger.debug(order_date)
          logger.debug(cost)
          logger.debug(shipping)
          logger.debug(amazon_fee)
          logger.debug(profit)
          logger.debug(roi)

          counter += 1
          if sku != nil then
            dcounter += 1
            logger.debug("No." + counter.to_s + ", SKU: " + sku.to_s + ", Order: " + order_id.to_s)
            sku_lists << OrderList.new(user: user, order_date: order_date, order_id: order_id, sku: sku, sales: sale, amazon_fee: amazon_fee, ex_rate: calc_rate, cost_price: cost, listing_shipping: shipping, profit: profit, roi: roi)
          end
        end

        OrderList.import sku_lists, on_duplicate_key_update: {constraint_name: :for_upsert_order, columns: [:user, :sales, :amazon_fee, :ex_rate, :profit, :roi]}, validate: false

        rows = nil
        sku_lists = nil
      end
    end
    logger.debug(counter.to_s)
    logger.debug("===== END REPORT =====")
=begin
    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n注文レポート取得終了\nレポートID：" + genid.to_s + "\n有効商品商品数：" + dcounter.to_s + "\n終了時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )
=end
  end

end
