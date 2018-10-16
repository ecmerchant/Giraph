class Product < ApplicationRecord

  require 'peddler'
  require 'activerecord-import'

  #validates :sku, uniqueness: { scope: [:user] }

  #日本アマゾン商品情報の取得
  def check_amazon_jp_info(user)
    logger.debug ("==== START JP INFO ======")
    tproducts = Product.where(user:user)
    asins = tproducts.group(:asin).pluck(:asin)
    buffer = ShippingCost.where(user: user)

    t_a = buffer.where(name: "送料表A").order(weight: "ASC")
    t_ems = buffer.where(name: "EMS送料表").order(weight: "ASC")
    table_a = Array.new
    table_ems = Array.new

    t_a.each do |row|
      tb = [row.weight, row.cost]
      table_a.push(tb)
    end

    t_ems.each do |row|
      tb = [row.weight, row.cost]
      table_ems.push(tb)
    end

    shipping_table = Hash.new
    shipping_table["送料表A"] = table_a
    shipping_table["EMS送料表"] = table_ems

    mp = "A1VC38T7YXB528"
    temp = Account.find_by(user: user)
    sid = temp.seller_id
    skey = temp.secret_key
    awskey = temp.aws_access_key_id

    package_weight = temp.shipping_weight

    client = MWS.products(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    asins.each_slice(5) do |tasins|
      logger.debug("============")
      p tasins
      response = client.get_matching_product_for_id(mp, "ASIN", tasins)
      parser = response.parse
      parser.each do |product|
        if product.class == Hash then
          asin = product.dig('Products', 'Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== ASIN =======\n" + asin.to_s)
          buf = product.dig('Products', 'Product', 'AttributeSets', 'ItemAttributes')
          if buf != nil then
            title = buf.dig("Title")
            size_Height = buf.dig("PackageDimensions", "Height", "__content__").to_f * 2.54
            size_Length = buf.dig("PackageDimensions", "Length", "__content__").to_f * 2.54
            size_Width = buf.dig("PackageDimensions", "Width", "__content__").to_f * 2.54
            size_Weight = buf.dig("PackageDimensions", "Weight", "__content__").to_f * 0.4536

            size_Height = size_Height.round(2)
            size_Length = size_Length.round(2)
            size_Width = size_Width.round(2)
            size_Weight = size_Weight.round(2)
          else
            logger.debug("=== CASE NO DATA ===")
            title = "データなし"
            size_Height = 0
            size_Length = 0
            size_Width = 0
            size_Weight = 0
            shipping_cost = 0
          end
        else
          logger.debug("array")
          asin = product.dig(1, 'Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== ASIN =======\n" + asin.to_s)
          buf = product.dig(1, 'Product', 'AttributeSets', 'ItemAttributes')
          if buf != nil then
            size_Height = buf.dig("PackageDimensions", "Height", "__content__").to_f * 2.54
            size_Length = buf.dig("PackageDimensions", "Length", "__content__").to_f * 2.54
            size_Width = buf.dig("PackageDimensions", "Width", "__content__").to_f * 2.54
            size_Weight = buf.dig("PackageDimensions", "Weight", "__content__").to_f * 0.4536

            size_Height = size_Height.round(2)
            size_Length = size_Length.round(2)
            size_Width = size_Width.round(2)
            size_Weight = size_Weight.round(2)
          else
            logger.debug("=== CASE NO DATA ===")
            size_Height = 0
            size_Length = 0
            size_Width = 0
            size_Weight = 0
          end
        end

        temp = tproducts.where(asin: asin)

        total_size = size_Height + size_Length + size_Width
        max_size = [size_Height, size_Length, size_Width].max

        if total_size > 80 || max_size > 50 then
          shipping_type = "EMS送料表"
        else
          shipping_type = "送料表A"
        end

        t_table = shipping_table[shipping_type]
        shipping_cost = 0
        t_table.each do |row|
          if size_Weight + package_weight < row[0] then
            shipping_cost = row[1]
            break
          end
        end

        if temp != nil then
          temp.update(
            jp_title: title,
            size_length: size_Length,
            size_width: size_Width,
            size_height: size_Height,
            size_weight: size_Weight,
            listing_shipping: shipping_cost
          )
        end
        if tasins.length != 5 then
          p "end"
          break
        end
      end
    end
  end

  #日本アマゾンFBA価格の監視
  def check_amazon_jp_price(user, condition)
    logger.debug ("==== START JP CHECK ======")
    tproducts = Product.where(user:user)
    asins = tproducts.group(:asin).pluck(:asin)

    mp = "A1VC38T7YXB528"
    temp = Account.find_by(user: user)
    sid = temp.seller_id
    skey = temp.secret_key
    awskey = temp.aws_access_key_id

    client = MWS.products(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    asins.each_slice(20) do |tasins|
      p tasins
      response = client.get_lowest_offer_listings_for_asin(mp, tasins,{item_condition: "New"})
      parser = response.parse

      parser.each do |product|
        if product.class == Hash then
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== ASIN =======\n" + asin.to_s)
          buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
          lowestprice = 0
          lowestship = 0
          lowestpoint = 0
          logger.debug (buf.class)
          if buf.class == Array then
            logger.debug("=== CASE ARRAY ===")
            buf.each do |listing|
              logger.debug("=== EACH ITEM ===")
              logger.debug (listing.class)
              logger.debug (listing)
              if listing.class == Hash then
                fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
                if fullfillment == "Amazon" then
                  lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                  lowestship = listing.dig('Price', 'Shipping','Amount')
                  lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                  break
                end
              end
            end
          elsif buf.class == Hash
            logger.debug("=== CASE HASH ===")
            listing = buf
            logger.debug (listing)
            fullfillment = listing.dig('Qualifiers','FulfillmentChannel')
            if fullfillment == "Amazon" then
              lowestprice = listing.dig('Price', 'ListingPrice','Amount')
              lowestship = listing.dig('Price', 'Shipping','Amount')
              lowestpoint = listing.dig('Price', 'Points','PointsNumber')
            end
          else
            logger.debug("=== CASE NO DATA ===")
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
          end
        else
          logger.debug("====== CASE ARRAY ======")
          asin = parser.dig(1, 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== ASIN =======\n" + asin.to_s)
          buf = parser.dig(1, 'LowestOfferListings', 'LowestOfferListing')
          lowestprice = 0
          lowestship = 0
          lowestpoint = 0
          logger.debug (buf.class)
          if buf.class == Array then
            logger.debug("=== CASE ARRAY ===")
            buf.each do |listing|
              logger.debug("=== EACH ITEM ===")
              logger.debug (listing.class)
              logger.debug (listing)
              if listing.class == Hash then
                fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
                if fullfillment == "Amazon" then
                  lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                  lowestship = listing.dig('Price', 'Shipping','Amount')
                  lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                  break
                end
              end
            end
          elsif buf.class == Hash
            logger.debug("=== CASE HASH ===")
            listing = buf
            logger.debug (listing)
            fullfillment = listing.dig('Qualifiers','FulfillmentChannel')
            if fullfillment == "Amazon" then
              lowestprice = listing.dig('Price', 'ListingPrice','Amount')
              lowestship = listing.dig('Price', 'Shipping','Amount')
              lowestpoint = listing.dig('Price', 'Points','PointsNumber')
            end
          else
            logger.debug("=== CASE NO DATA ===")
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
          end
        end
        temp = tproducts.where(asin: asin)
        cost = lowestprice.to_f - lowestpoint.to_f
        if temp != nil then
          temp.update(jp_price: lowestprice.to_f, jp_shipping: lowestship.to_f, jp_point: lowestpoint.to_f, cost_price: cost)
        end
      end
    end
  end


  #アメリカアマゾン最低価格の監視
  def check_amazon_us_price(user, condition)
    logger.debug ("==== START US PRICE CHECK ======")
    tproducts = Product.where(user:user)
    asins = tproducts.group(:asin).pluck(:asin)

    mp = "ATVPDKIKX0DER" #アマゾンアメリカ
    #mp = "A1VC38T7YXB528"
    temp = Account.find_by(user: user)
    sid = temp.us_seller_id1
    skey = temp.us_secret_key1
    awskey = temp.us_aws_access_key_id1

    client = MWS.products(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    asins.each_slice(20) do |tasins|
      p tasins
      requests = []
      i = 0
      #最低価格の取得
      response = client.get_lowest_offer_listings_for_asin(mp, tasins,{item_condition: "New"})
      parser = response.parse
      parser.each do |product|
        if product.class == Hash then
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== US ASIN =======\n" + asin.to_s)
          buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
          lowestprice = 0
          lowestship = 0
          lowestpoint = 0
          if buf.class == Array then
            logger.debug("=== CASE ARRAY ===")
            buf.each do |listing|
              logger.debug("=== EACH ITEM ===")
              if listing.class == Hash then
                fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
                lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                lowestship = listing.dig('Price', 'Shipping','Amount')
                lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                break
              end
            end
          elsif buf.class == Hash
            logger.debug("=== CASE HASH ===")
            listing = buf
            fullfillment = listing.dig('Qualifiers','FulfillmentChannel')
            lowestprice = listing.dig('Price', 'ListingPrice','Amount')
            lowestship = listing.dig('Price', 'Shipping','Amount')
            lowestpoint = listing.dig('Price', 'Points','PointsNumber')
          else
            logger.debug("=== CASE NO DATA ===")
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
          end
        else
          logger.debug("====== CASE ARRAY ======")
          asin = parser.dig(1, 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== ASIN =======\n" + asin.to_s)
          buf = parser.dig(1, 'LowestOfferListings', 'LowestOfferListing')
          lowestprice = 0
          lowestship = 0
          lowestpoint = 0
          if buf.class == Array then
            logger.debug("=== CASE ARRAY ===")
            buf.each do |listing|
              logger.debug("=== EACH ITEM ===")
              if listing.class == Hash then
                fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
                lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                lowestship = listing.dig('Price', 'Shipping','Amount')
                lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                break
              end
            end
          elsif buf.class == Hash
            logger.debug("=== CASE HASH ===")
            listing = buf
            fullfillment = listing.dig('Qualifiers','FulfillmentChannel')
            lowestprice = listing.dig('Price', 'ListingPrice','Amount')
            lowestship = listing.dig('Price', 'Shipping','Amount')
            lowestpoint = listing.dig('Price', 'Points','PointsNumber')
          else
            logger.debug("=== CASE NO DATA ===")
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
          end
        end
        temp = tproducts.where(asin: asin)
        if temp != nil then
          temp.update(
            us_price: lowestprice.to_f,
            us_shipping: lowestship.to_f,
            us_point: lowestpoint.to_f
          )
        end

        prices = {
          ListingPrice: { Amount: lowestprice.to_f, CurrencyCode: "USD", }
        }
        request = {
          MarketplaceId: mp,
          IdType: "ASIN",
          IdValue: asin,
          PriceToEstimateFees: prices,
          Identifier: "req" + i.to_s,
          IsAmazonFulfilled: true
        }
        requests[i] = request
        i += 1
      end

      #手数料の取得
      logger.debug("====== GET FEE ESTIMATE =======")
      response2 = client.get_my_fees_estimate(requests)
      parser2 = response2.parse
      buf = parser2.dig("FeesEstimateResultList", "FeesEstimateResult")
      j = 0
      referral_fee = 0
      variable_closing_fee = 0
      per_item_fee = 0
      fba_fees = 0
      buf.each do |result|
        logger.debug("====== FEE ESTIMATE ASINS =======")
        asin = result.dig("FeesEstimateIdentifier", "IdValue")
        fees = result.dig("FeesEstimate")
        price = result.dig("FeesEstimateIdentifier", "PriceToEstimateFees", "ListingPrice", "Amount")
        j += 1
        logger.debug(asin.to_s + " " + j.to_s)
        if fees != nil then
          lists= fees.dig("FeeDetailList", "FeeDetail")
          lists.each do |fee|
            feetype = fee.dig("FeeType")
            logger.debug(feetype)
            case feetype
              when "ReferralFee" then
                referral_fee = fee.dig("FinalFee", "Amount")
                logger.debug(referral_fee.to_f)
              when "VariableClosingFee" then
                variable_closing_fee = fee.dig("FinalFee", "Amount")
                logger.debug(variable_closing_fee.to_f)
              when "PerItemFee" then
                per_item_fee = fee.dig("FinalFee", "Amount")
                logger.debug(per_item_fee.to_f)
              when "FBAFees" then
                fba_fees = fee.dig("FinalFee", "Amount")
                logger.debug(fba_fees.to_f)
            end
          end
        end

        temp = tproducts.where(asin: asin)

        if temp != nil then
          logger.debug("=== UPDATE ===")
          logger.debug(referral_fee.to_f)
          logger.debug((referral_fee.to_f / price.to_f).round(2))
          logger.debug(variable_closing_fee.to_f)
          if referral_fee.to_f != 0 then
            rate = (referral_fee.to_f / price.to_f).round(2)
          else
            rate = 0.0
          end
          temp.update(
            referral_fee: referral_fee.to_f,
            referral_fee_rate: rate,
            variable_closing_fee: variable_closing_fee.to_f
          )
        end
      end
    end
  end


  #出品レポートの取得
  def get_listing_report(user)
    logger.debug("===== Start Listing Report =====")
    mp = "A1VC38T7YXB528"
    temp = Account.find_by(user: user)
    sid = temp.seller_id
    skey = temp.secret_key
    awskey = temp.aws_access_key_id
    products = Product.where(user:user)
    report_type = "_GET_FLAT_FILE_OPEN_LISTINGS_DATA_"

    client = MWS.reports(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    response = client.request_report(report_type)
    parser = response.parse
    reqid = parser.dig('ReportRequestInfo', 'ReportRequestId')

    mws_options = {
      report_request_id_list: reqid,
    }
    process = ""
    logger.debug(reqid)
    while process != "_DONE_" && process != "_DONE_NO_DATA_"
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
      end
      sleep(20)
    end

    logger.debug("====== generated id =======")
    logger.debug(genid)

    if genid.to_s != "NODATA" then
      response = client.get_report(genid)
      parser = response.parse
      logger.debug("====== report data is ok =======")
      parser.each do |row|
        tsku = row[0].to_s
        tasin = row[1].to_s
        logger.debug("SKU: " + tsku.to_s + ", ASIN: " + tasin.to_s)
        Product.find_or_create_by(
          user: user,
          sku: tsku,
          asin: tasin
        )
      end
    end
    logger.debug("===== End Report =====")
  end


  #販売価格の計算
  def calc_profit(user)
    products = Product.where(user: user)
    account = Account.find_by(user: user)
    calc_ex_rate = account.calc_ex_rate
    delivery_fee_default = account.delivery_fee
    max_roi = account.max_roi
    targets = products.pluck(:asin, :cost_price, :us_price, :us_shipping, :referral_fee, :variable_closing_fee, :listing_shipping, :referral_fee_rate, :sku)

    targets.each_slice(10) do |tag|
      asin_list = Array.new

      tag.each do |temp|
        logger.debug(temp)
        asin = temp[0]
        cost = temp[1].to_f
        us_price = temp[2].to_f
        us_shipping = temp[3].to_f
        referral_fee = temp[4].to_f
        variable_closing_fee = temp[5].to_f
        shipping = temp[6].to_f
        referral_fee_rate = temp[7].to_f
        sku = temp[8]

        min_price = (((cost + shipping + delivery_fee_default) / calc_ex_rate + variable_closing_fee) / (1.0 - referral_fee_rate)).round(2)

        if us_price != 0 then
          list_price = us_price + us_shipping
          profit = (list_price - referral_fee - variable_closing_fee) * calc_ex_rate - cost - shipping - delivery_fee_default
          profit = profit.round(0)
        else
          profit = max_roi / 100.0 * (cost + shipping + delivery_fee_default + (referral_fee + variable_closing_fee) * calc_ex_rate).round(0)
          profit = profit.round(0)
          list_price = ((cost + profit) / calc_ex_rate).round(2)
        end
        if list_price < min_price then
          list_price = min_price
          profit = list_price * calc_ex_rate - cost
          profit = profit.round(0)
        end
        roi = profit / (cost + shipping + delivery_fee_default + (referral_fee + variable_closing_fee) * calc_ex_rate).round(1)
        roi = roi * 100.0
        if cost != 0 then
          list_price = list_price.round(2)
        else
          list_price = 0.0
          profit = 0.0
        end
        asin_list << Product.new(user:user, sku:sku, asin:asin, us_listing_price: list_price, profit: profit, minimum_listing_price: min_price)
      end
      logger.debug("================")

      if Rails.env == 'development'
        logger.debug("======= DEVELOPMENT =========")
        Product.import asin_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:us_listing_price, :profit, :minimum_listing_price]}
      else
        logger.debug("======= PRODUCTION =========")
        Product.import asin_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:us_listing_price, :profit, :minimum_listing_price]}
      end

    end

  end

end
