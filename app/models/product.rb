class Product < ApplicationRecord

  require 'peddler'
  require 'activerecord-import'
  require 'typhoeus'
  require 'open-uri'

  PER_NOTICE = ENV['PER_NOTICE'].to_i

  #日本アマゾン商品情報の取得
  def check_amazon_jp_info(user, condition)
    logger.debug ("==== START JP INFO ======")
    tproducts = Product.where(user:user, listing_condition: condition)
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
    account = Account.find_by(user: user)
    sid = account.seller_id
    skey = account.secret_key
    awskey = account.aws_access_key_id
    package_weight = account.shipping_weight

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n商品情報取得開始 (" + condition.to_s + ")\n開始時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

    client = MWS.products(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    time_counter1 = Time.now.strftime('%s%L').to_i
    counter = 0
    total_counter = 0

    if tproducts.count > 0 then
      asins = tproducts.order("info_updated_at ASC NULLS FIRST").group(:asin, :info_updated_at).pluck(:asin)
      asins.each_slice(5) do |tasins|
        update_list = Array.new
        response = nil
        time_counter2 = nil
        diff_time = nil
        Retryable.retryable(tries: 5, sleep: 2.0) do
          time_counter2 = Time.now.strftime('%s%L').to_i
          diff_time = time_counter2 - time_counter1
          while diff_time < 1000.0 do
            sleep(0.02)
            time_counter2 = Time.now.strftime('%s%L').to_i
            diff_time = time_counter2 - time_counter1
          end
          time_counter1 = Time.now.strftime('%s%L').to_i
          response = client.get_matching_product_for_id(mp, "ASIN", tasins)
        end

        parser = response.parse
        parser.each do |product|
          if product.class == Hash then
            asin = product.dig('Products', 'Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
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
              title = "データなし"
              size_Height = 0
              size_Length = 0
              size_Width = 0
              size_Weight = 0
              shipping_cost = 0
            end
          else
            asin = product.dig(1, 'Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
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
              size_Height = 0
              size_Length = 0
              size_Width = 0
              size_Weight = 0
            end
          end

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
          if asin != nil then
            if tasins.include?(asin) then
              update_list << Product.new(user: user, asin: asin, listing_condition: condition, jp_title: title, size_length: size_Length, size_width: size_Width, size_height: size_Height, size_weight: size_Weight, listing_shipping: shipping_cost, shipping_weight: package_weight, info_updated_at: Time.now)
            end
          end
          counter += 1
          total_counter += 1
        end

        Product.import update_list, on_duplicate_key_update: {constraint_name: :for_asin_upsert, columns: [:jp_title, :size_length, :size_width, :size_height, :size_weight, :listing_shipping, :shipping_weight, :info_updated_at]}
        update_list = nil

        if counter > PER_NOTICE - 1 then
          t = Time.now
          strTime = t.strftime("%Y年%m月%d日 %H時%M分")
          msg = "商品情報取得中 (" + condition.to_s + ")\n取得時刻：" + strTime + "\n" + total_counter.to_s + "件取得済み"
          account.msend(
            msg,
            account.cw_api_token,
            account.cw_room_id
          )
          counter = 0
        end
        logger.debug("==== JP_INFO: No." + total_counter.to_s + ", Diff: " + diff_time.to_s + "====")
      end
    end

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n商品情報取得終了 (" + condition.to_s + ")\n終了時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

    if condition == "New" then
      GetJpInfoJob.set(queue: :jp_used_info).perform_later(user, "Used")
    end

    if condition == "Used" then
      GetJpInfoJob.set(queue: :jp_new_info).perform_later(user, "New")
    end

  end

  #日本アマゾンFBA価格の監視
  def check_amazon_jp_price(user, condition)
    logger.debug ("==== START JP CHECK ======")

    mp = "A1VC38T7YXB528"
    account = Account.find_by(user: user)
    sid = account.seller_id
    skey = account.secret_key
    awskey = account.aws_access_key_id

    client = MWS.products(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n日本アマゾン価格取得開始 (" + condition.to_s + ")\n開始時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

    jp_interval = ENV['JP_INTERVAL']
    if jp_interval == nil then
      jp_interval = 920.0
    else
      jp_interval = jp_interval.to_f
    end 

    counter = 0
    total_counter = 0
    time_counter1 = Time.now.strftime('%s%L').to_i
    tproducts = Product.where(user: user, listing_condition: condition, shipping_type: "default")

    if tproducts.count > 0 then
      asins = tproducts.order("jp_price_updated_at ASC NULLS FIRST").group(:asin, :jp_price_updated_at).pluck(:asin)
      asins.each_slice(10) do |tasins|
        update_list = Array.new
        response = nil
        time_counter2 = nil
        diff_time = nil

        Retryable.retryable(tries: 5, sleep: 2.0) do
          time_counter2 = Time.now.strftime('%s%L').to_i
          diff_time = time_counter2 - time_counter1
          while diff_time < 920.0 do
            sleep(0.02)
            time_counter2 = Time.now.strftime('%s%L').to_i
            diff_time = time_counter2 - time_counter1
          end
          time_counter1 = Time.now.strftime('%s%L').to_i
          response = client.get_lowest_offer_listings_for_asin(mp, tasins,{item_condition: condition})
        end

        parser = response.parse
        parser.each do |product|
          if product.class == Hash then
            asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
            buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
            jp_stock = false
            if buf.class == Array then
              buf.each do |listing|
                if listing.class == Hash then
                  fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
                  domestic = listing.dig('Qualifiers', 'ShipsDomestically')
                  shipping = listing.dig('Qualifiers', 'ShippingTime')

                  if fullfillment == "Amazon" && domestic == "True" && shipping["Max"] == "0-2 days" then
                    if condition == "New" then
                      lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                      lowestship = listing.dig('Price', 'Shipping','Amount')
                      lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                      jp_stock = true
                      break
                    else
                      subcondition = listing.dig('Qualifiers', 'ItemSubcondition')
                      if subcondition == "Mint" || subcondition == "Very Good" then
                        lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                        lowestship = listing.dig('Price', 'Shipping','Amount')
                        lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                        jp_stock = true
                        break
                      end
                    end
                  end
                end
              end
            elsif buf.class == Hash
              listing = buf
              fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
              domestic = listing.dig('Qualifiers', 'ShipsDomestically')
              shipping = listing.dig('Qualifiers', 'ShippingTime')

              if fullfillment == "Amazon" && domestic == "True" && shipping["Max"] == "0-2 days" then
                if condition == "New" then
                  lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                  lowestship = listing.dig('Price', 'Shipping','Amount')
                  lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                  jp_stock = true
                else
                  subcondition = listing.dig('Qualifiers', 'ItemSubcondition')
                  if subcondition == "Mint" || subcondition == "Very Good" then
                    lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                    lowestship = listing.dig('Price', 'Shipping','Amount')
                    lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                    jp_stock = true
                  end
                end
              end
            else
              lowestprice = 0
              lowestship = 0
              lowestpoint = 0
              jp_stock = false
            end
          else
            asin = parser.dig(1, 'Identifiers', 'MarketplaceASIN', 'ASIN')
            buf = parser.dig(1, 'LowestOfferListings', 'LowestOfferListing')
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
            jp_stock = false
            if buf.class == Array then
              buf.each do |listing|
                if listing.class == Hash then
                  fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
                  domestic = listing.dig('Qualifiers', 'ShipsDomestically')
                  shipping = listing.dig('Qualifiers', 'ShippingTime')

                  if fullfillment == "Amazon" && domestic == "True" && shipping["Max"] == "0-2 days" then
                    if condition == "New" then
                      lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                      lowestship = listing.dig('Price', 'Shipping','Amount')
                      lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                      jp_stock = true
                      break
                    else
                      subcondition = listing.dig('Qualifiers', 'ItemSubcondition')
                      if subcondition == "Mint" || subcondition == "Very Good" then
                        lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                        lowestship = listing.dig('Price', 'Shipping','Amount')
                        lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                        jp_stock = true
                        break
                      end
                    end
                  end
                end
              end
            elsif buf.class == Hash
              listing = buf
              fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
              domestic = listing.dig('Qualifiers', 'ShipsDomestically')
              shipping = listing.dig('Qualifiers', 'ShippingTime')

              if fullfillment == "Amazon" && domestic == "True" && shipping["Max"] == "0-2 days" then
                if condition == "New" then
                  lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                  lowestship = listing.dig('Price', 'Shipping','Amount')
                  lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                  jp_stock = true
                else
                  subcondition = listing.dig('Qualifiers', 'ItemSubcondition')
                  if subcondition == "Mint" || subcondition == "Very Good" then
                    lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                    lowestship = listing.dig('Price', 'Shipping','Amount')
                    lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                    jp_stock = true
                  end
                end
              end
            else
              lowestprice = 0
              lowestship = 0
              lowestpoint = 0
              jp_stock = false
            end
          end

          cost = lowestprice.to_f - lowestpoint.to_f

          if asin != nil then
            if tasins.include?(asin) then
              update_list << Product.new(user: user, asin: asin, listing_condition: condition, shipping_type: "default", jp_price: lowestprice.to_f, jp_shipping: lowestship.to_f, jp_point: lowestpoint.to_f, cost_price: cost, on_sale: jp_stock, jp_price_updated_at: Time.now)
            end
          end
          counter += 1
          total_counter += 1
        end

        Product.import update_list, on_duplicate_key_update: {constraint_name: :for_asin_upsert, columns: [:jp_price, :jp_shipping, :jp_point, :cost_price, :on_sale, :shipping_type, :jp_price_updated_at]}
        update_list = nil

        if counter > PER_NOTICE - 1 then
          t = Time.now
          strTime = t.strftime("%Y年%m月%d日 %H時%M分")
          msg = "日本アマゾン価格取得中 (" + condition.to_s + ")\n取得時刻：" + strTime + "\n" + total_counter.to_s + "件取得済み"
          account.msend(
            msg,
            account.cw_api_token,
            account.cw_room_id
          )
          counter = 0
        end
        logger.debug("==== JP_PRICE_" + condition.to_s.upcase + ": No." + total_counter.to_s + ", Diff: " + diff_time.to_s + "====")
      end
    end

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n日本アマゾン価格取得終了 (" + condition.to_s + ")\n終了時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

    if condition == "New" then
      GetJpPriceJob.set(queue: :jp_used_item).perform_later(user, "Used")
    end

    if condition == "Used" then
      GetJpPriceJob.set(queue: :jp_new_item).perform_later(user, "New")
    end

  end


  #アメリカアマゾン最低価格の監視
  def check_amazon_us_price(user, condition, fee_check)
    logger.debug ("==== START US PRICE CHECK ======")
    tproducts = Product.where(user: user, listing_condition: condition)

    mp = "ATVPDKIKX0DER" #アマゾンアメリカ
    account = Account.find_by(user: user)
    sid = account.us_seller_id1
    skey = account.us_secret_key1
    awskey = account.us_aws_access_key_id1

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n米国アマゾン価格取得開始 (" + condition.to_s + ")\n開始時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

    counter = 0
    total_counter = 0

    client = MWS.products(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )
    time_counter1 = Time.now.strftime('%s%L').to_i

    if tproducts.count > 0 then
      asins = tproducts.order("us_price_updated_at ASC NULLS FIRST").group(:asin, :us_price_updated_at).pluck(:asin)
      asins.each_slice(10) do |tasins|
        requests = []
        i = 0
        #最低価格の取得
        update_list = Array.new
        response = nil
        time_counter2 = nil
        diff_time = nil

        Retryable.retryable(tries: 5, sleep: 2.0) do
          time_counter2 = Time.now.strftime('%s%L').to_i
          diff_time = time_counter2 - time_counter1
          while diff_time < 1005.0 do
            sleep(0.02)
            time_counter2 = Time.now.strftime('%s%L').to_i
            diff_time = time_counter2 - time_counter1
          end
          time_counter1 = Time.now.strftime('%s%L').to_i
          response = client.get_lowest_offer_listings_for_asin(mp, tasins,{item_condition: condition})
        end

        parser = response.parse
        parser.each do |product|
          if product.class == Hash then
            asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
            buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
            if buf.class == Array then
              buf.each do |listing|
                if listing.class == Hash then
                  fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
                  if condition == "New" then
                    lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                    lowestship = listing.dig('Price', 'Shipping','Amount')
                    lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                    break
                  else
                    subcondition = listing.dig('Qualifiers', 'ItemSubcondition')
                    if subcondition == "Mint" || subcondition == "Very Good" then
                      lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                      lowestship = listing.dig('Price', 'Shipping','Amount')
                      lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                      break
                    end
                  end
                end
              end
            elsif buf.class == Hash
              listing = buf
              fullfillment = listing.dig('Qualifiers','FulfillmentChannel')
              if condition == "New" then
                lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                lowestship = listing.dig('Price', 'Shipping','Amount')
                lowestpoint = listing.dig('Price', 'Points','PointsNumber')
              else
                subcondition = listing.dig('Qualifiers', 'ItemSubcondition')
                if subcondition == "Mint" || subcondition == "Very Good" then
                  lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                  lowestship = listing.dig('Price', 'Shipping','Amount')
                  lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                end
              end
            else
              lowestprice = 0
              lowestship = 0
              lowestpoint = 0
            end
          else
            asin = parser.dig(1, 'Identifiers', 'MarketplaceASIN', 'ASIN')
            buf = parser.dig(1, 'LowestOfferListings', 'LowestOfferListing')
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
            if buf.class == Array then
              buf.each do |listing|
                if listing.class == Hash then
                  fullfillment = listing.dig('Qualifiers', 'FulfillmentChannel')
                  if condition == "New" then
                    lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                    lowestship = listing.dig('Price', 'Shipping','Amount')
                    lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                    break
                  else
                    subcondition = listing.dig('Qualifiers', 'ItemSubcondition')
                    if subcondition == "Mint" || subcondition == "Very Good" then
                      lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                      lowestship = listing.dig('Price', 'Shipping','Amount')
                      lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                      break
                    end
                  end
                end
              end
            elsif buf.class == Hash
              listing = buf
              fullfillment = listing.dig('Qualifiers','FulfillmentChannel')
              if condition == "New" then
                lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                lowestship = listing.dig('Price', 'Shipping','Amount')
                lowestpoint = listing.dig('Price', 'Points','PointsNumber')
              else
                subcondition = listing.dig('Qualifiers', 'ItemSubcondition')
                if subcondition == "Mint" || subcondition == "Very Good" then
                  lowestprice = listing.dig('Price', 'ListingPrice','Amount')
                  lowestship = listing.dig('Price', 'Shipping','Amount')
                  lowestpoint = listing.dig('Price', 'Points','PointsNumber')
                end
              end
            else
              lowestprice = 0
              lowestship = 0
              lowestpoint = 0
            end
          end

          if asin != nil then
            if tasins.include?(asin) then
              update_list << Product.new(user: user, asin: asin, listing_condition: condition, us_price: lowestprice.to_f, us_shipping: lowestship.to_f, us_point: lowestpoint.to_f, us_price_updated_at: Time.now)
            end
          end
          counter += 1
          total_counter += 1
          prices = {
            ListingPrice: {Amount: lowestprice.to_f, CurrencyCode: "USD"}
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

        Product.import update_list, on_duplicate_key_update: {constraint_name: :for_asin_upsert, columns: [:us_price, :us_shipping, :us_point, :us_price_updated_at]}
        update_list = nil

        #手数料の取得
        if fee_check == "TRUE" then
          logger.debug("====== GET FEE ESTIMATE =======")
          update_list = Array.new
          response2 = nil
          Retryable.retryable(tries: 5, sleep: 2.0) do
            response2 = client.get_my_fees_estimate(requests)
          end
          parser2 = response2.parse

          buf = parser2.dig("FeesEstimateResultList", "FeesEstimateResult")
          j = 0
          referral_fee = 0
          variable_closing_fee = 0
          per_item_fee = 0
          fba_fees = 0
          buf.each do |result|
            tmp = result.dig("FeesEstimateIdentifier")
            asin = result.dig("FeesEstimateIdentifier", "IdValue")
            fees = result.dig("FeesEstimate")
            price = result.dig("FeesEstimateIdentifier", "PriceToEstimateFees", "ListingPrice", "Amount")

            if fees != nil then
              lists= fees.dig("FeeDetailList", "FeeDetail")
              checker = 0
              lists.each do |fee|
                feetype = fee.dig("FeeType")
                case feetype
                  when "ReferralFee" then
                    referral_fee = fee.dig("FinalFee", "Amount")
                    checker += 1
                  when "VariableClosingFee" then
                    variable_closing_fee = fee.dig("FinalFee", "Amount")
                    checker += 1
                  when "PerItemFee" then
                    per_item_fee = fee.dig("FinalFee", "Amount")
                  when "FBAFees" then
                    fba_fees = fee.dig("FinalFee", "Amount")
                end
                if checker == 2 then break end
              end
            end

            if referral_fee.to_f != 0 then
              if referral_fee.to_f > 1.0 && referral_fee.to_f > price.to_f then
                rate = (referral_fee.to_f / price.to_f).round(2)
              else
                rate = 0.15
              end
            else
              rate = 0.15
            end

            if price.to_f == 0 then
              rate = 0.15
            end

            if asin != nil then
              if tasins.include?(asin) then
                update_list << Product.new(user: user, asin: asin, listing_condition: condition, referral_fee: referral_fee.to_f, referral_fee_rate: rate, variable_closing_fee: variable_closing_fee.to_f, us_price_updated_at: Time.now)
              end
            end
          end
          Product.import update_list, on_duplicate_key_update: {constraint_name: :for_asin_upsert, columns: [:referral_fee, :referral_fee_rate, :variable_closing_fee, :us_price_updated_at]}
          update_list = nil
        end
        if counter > PER_NOTICE - 1 then
          t = Time.now
          strTime = t.strftime("%Y年%m月%d日 %H時%M分")
          msg = "米国アマゾン価格取得中 (" + condition.to_s + ")\n取得時刻：" + strTime + "\n" + total_counter.to_s + "件取得済み"
          account.msend(
            msg,
            account.cw_api_token,
            account.cw_room_id
          )
          counter = 0
        end
        logger.debug("==== US_PRICE_" + condition.to_s.upcase + ": No." + total_counter.to_s + ", Diff: " + diff_time.to_s + "====")
      end
    end

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n米国アマゾン価格取得終了 (" + condition.to_s + ")\n終了時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

    if condition == "New" then
      GetUsPriceJob.set(queue: :us_used_item).perform_later(user, "Used", fee_check)
    end

    if condition == "Used" then
      GetUsPriceJob.set(queue: :us_new_item).perform_later(user, "New", fee_check)
    end

  end

  #出品情報の取得
  def get_my_price(user)
    logger.debug ("==== START LISTING PRICE CHECK ======")
    tproducts = Product.where(user:user)
    skus = tproducts.group(:sku).pluck(:sku)

    mp = "ATVPDKIKX0DER" #アマゾンアメリカ
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

    skus.each_slice(20) do |tskus|
      response = client.get_my_price_for_sku(mp, tskus)
      parser = response.parse
      parser.each do |product|

      end
    end
  end

  #出品レポートの取得
  def get_listing_report(user)
    logger.debug("===== Start Listing Report =====")
    per_num = ENV['PER_LIST_NUM']
    if per_num == nil then
       per_num = 1000
    else
      per_num = per_num.to_i
    end
    #mp = "A1VC38T7YXB528"
    mp = "ATVPDKIKX0DER"  #アメリカアマゾン
    account = Account.find_by(user: user)
    sid = account.us_seller_id1
    skey = account.us_secret_key1
    awskey = account.us_aws_access_key_id1
    products = Product.where(user: user)
    report_type = "_GET_FLAT_FILE_OPEN_LISTINGS_DATA_"
    #report_type = "_GET_MERCHANT_LISTINGS_ALL_DATA_"

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n出品レポート取得開始\n開始時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

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

    once = false
    dcounter = 0

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

      if once == false then
        logger.debug("====== UPDATE SKU START =======")
        targets = products.where.not(sku_checked: false).pluck(:sku)
        targets.each_slice(1000) do |tag|
            sku_update_list = Array.new
            tag.each do |tsku|
              sku_update_list << Product.new(user: user, sku: tsku, sku_checked: false)
            end
            Product.import sku_update_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:sku_checked]}, validate: false
            sku_update_list = nil
        end
        logger.debug("====== UPDATE SKU END =======")
        once = true
      else
        sleep(60)
      end
    end

    logger.debug("====== generated id =======")
    logger.debug(genid)

    if genid.to_s != "NODATA" then

      response = client.get_report(genid)
      parser = response.parse
      logger.debug("====== report data is ok =======")
      counter = 0
      parser.each_slice(per_num) do |rows|
        asin_list = Array.new
        rows.each do |row|
          logger.debug(row)
          tsku = row[0].to_s
          tasin = row[1].to_s
          quantity = row[3].to_i
          #status = row[28]
          #channel = row[26]
          counter += 1

          #if status == "Inactive" then
          #  listing = false
          #else
          #  listing = true
          #end

          if quantity == 0 then
            listing = false
          else
            listing = true
          end


          #if channel == "DEFAULT" then
          #  shipping_type = "default"
          #else
          #  shipping_type = "amazon"
          #end

          #skuで判断
          if tsku.include?("_F_") then
            shipping_type = "amazon"
          else
            if tsku.include?("fba") then
              shipping_type = "amazon"
            else
              shipping_type = "default"
            end
          end

          if tsku.include?("used") then
            listing_condition = "Used"
          else
            listing_condition = "New"
          end

          if shipping_type == "default" then
            if tsku != nil && tasin != nil then
              if tsku.include?(tasin) then
                dcounter += 1
                logger.debug("No." + counter.to_s + ", SKU: " + tsku.to_s + ", ASIN: " + tasin.to_s)
                asin_list << Product.new(user: user, sku: tsku, asin: tasin, listing: listing , shipping_type: shipping_type, listing_condition: listing_condition, sku_checked: true)
              end
            end
          end
        end

        begin
          Product.import asin_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:asin, :listing, :shipping_type, :listing_condition, :sku_checked]}, validate: false
        rescue => e
          logger.debug("========== EMG ============")
          Product.import asin_list, on_duplicate_key_ignore: true
        end

        rows = nil
        asin_list = nil
        logger.debug("=========================")
        logger.debug(counter.to_s)
      end
    end
    logger.debug(counter.to_s)
    logger.debug("===== End Report =====")

    Product.where(user: user, sku_checked: false).delete_all

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n出品レポート取得終了\nレポートID：" + genid.to_s + "\n有効商品商品数：" + dcounter.to_s + "\n終了時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

  end


  #販売価格の計算
  def calc_profit(user)
    products = Product.where(user: user)
    account = Account.find_by(user: user)
    ex_rate = account.exchange_rate
    calc_ex_rate = account.calc_ex_rate
    delivery_fee_default = account.delivery_fee
    max_roi = account.max_roi
    payoneer_fee = account.payoneer_fee
    temp = products.all
    temp = temp.order("calc_updated_at ASC")
    targets = temp.pluck(:asin, :cost_price, :us_price, :us_shipping, :referral_fee, :variable_closing_fee, :listing_shipping, :referral_fee_rate, :sku)

    #===========
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
      calc_rate = exrate * (100.0 - account.payoneer_fee) / 100.0
      account.update(
        exchange_rate: exrate,
        calc_ex_rate: calc_rate.round(2)
      )
      logger.debug(exrate)
    rescue OpenURI::HTTPError => error
      logger.debug("==== EXCHANGE RATE ERROR ====")
      logger.debug(error)
    end
    #===========


    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n価格計算開始\n開始時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )

    counter = 0
    total_counter = 0

    targets.each_slice(1000) do |tag|
      asin_list = Array.new
      tag.each do |temp|
        asin = temp[0]
        cost = temp[1].to_f
        us_price = temp[2].to_f
        us_shipping = temp[3].to_f
        referral_fee = temp[4].to_f
        variable_closing_fee = temp[5].to_f
        shipping = temp[6].to_f
        referral_fee_rate = temp[7].to_f
        sku = temp[8]

        us_sell_fee = 0.0

        if referral_fee_rate > 0.50 then
          referral_fee_rate = 0.15
        end

        if (1.0 - referral_fee_rate) != 0 then
          min_price = (((cost + shipping + delivery_fee_default) / calc_ex_rate + variable_closing_fee) / (1.0 - referral_fee_rate)).round(2)
        else
          min_price = us_price
        end

        if min_price * referral_fee_rate < 1.0 then
          min_price = min_price + 1.0 - min_price * referral_fee_rate
        end

        if us_price > 0.0 then
          list_price = us_price + us_shipping
          if list_price < min_price then
            list_price = min_price
          end

          us_sell_fee = list_price * referral_fee_rate
          if us_sell_fee < 1.0 then
            us_sell_fee = 1.0
          end

          profit = (list_price - us_sell_fee - variable_closing_fee) * calc_ex_rate - cost - shipping - delivery_fee_default
          profit = profit.round(0)
        else
          profit = max_roi / 100.0 * (cost + shipping + delivery_fee_default + (referral_fee + variable_closing_fee) * calc_ex_rate).round(0)
          profit = profit.round(0)
          list_price = ((cost + profit) / calc_ex_rate).round(2)
          us_sell_fee = list_price * referral_fee_rate
          if us_sell_fee < 1.0 then
            us_sell_fee = 1.0
          end
        end

        roi = profit / (cost + shipping + delivery_fee_default + (us_sell_fee + variable_closing_fee) * calc_ex_rate).round(1)
        roi = roi * 100.0
        roi = roi.round(1)

        if cost != 0 then
          list_price = list_price.round(2)
        else
          list_price = 0.0
          profit = 0.0
        end

        #skuで判断
        if sku.include?("_F_") then
          shipping_type = "amazon"
        else
          shipping_type = "default"
        end

        if sku.include?("fba") then
          shipping_type = "amazon"
        else
          shipping_type = "default"
        end

        if sku.include?("used") then
          listing_condition = "Used"
        else
          listing_condition = "New"
        end
        asin_list << Product.new(user: user, sku: sku, asin: asin, us_listing_price: list_price, profit: profit, minimum_listing_price: min_price, max_roi: max_roi, calc_ex_rate: calc_ex_rate, roi: roi, delivery_fee: delivery_fee_default, payoneer_fee: payoneer_fee, exchange_rate: ex_rate, shipping_type: shipping_type, listing_condition: listing_condition, calc_updated_at: Time.now)
        counter += 1
        total_counter += 1
      end
      Product.import asin_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:asin, :us_listing_price, :profit, :minimum_listing_price, :max_roi, :roi, :calc_ex_rate, :delivery_fee, :payoneer_fee, :exchange_rate, :shipping_type, :listing_condition, :calc_updated_at]}
      asin_list = nil
      if counter > (PER_NOTICE * 5 - 1) then
        t = Time.now
        strTime = t.strftime("%Y年%m月%d日 %H時%M分")
        msg = "価格計算開始\n取得時刻：" + strTime + "\n" + total_counter.to_s + "件計算済み"
        account.msend(
          msg,
          account.cw_api_token,
          account.cw_room_id
        )
        counter = 0
      end
    end

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n価格計算取得終了\n終了時刻：" + strTime + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )
    #GetCalcJob.set(queue: :item_calc).perform_later(user)
  end

  #価格改定
  def submit_feed(user)
    mp = "ATVPDKIKX0DER"  #アメリカアマゾン
    account = Account.find_by(user: user)
    sid = account.us_seller_id1
    skey = account.us_secret_key1
    awskey = account.us_aws_access_key_id1
    handling_time = account.handling_time
    calc_on = ENV['CALC_ON']

    if calc_on == "TRUE" then
      Product.new.calc_profit(user)
    end

    limit = ENV['PER_REVISE_NUM'].to_i

    if limit == 0 then
      limit = 20000
    end

    targets = Product.where(user: user, shipping_type: "default", revised: false)
    if targets.count > 0 then
      t = Time.now
      strTime = t.strftime("%Y年%m月%d日 %H時%M分")
      msg = "=========================\n価格改定開始\n開始時刻：" + strTime + "\n========================="
      account.msend(
        msg,
        account.cw_api_token,
        account.cw_room_id
      )
      targets = targets.order("jp_price_updated_at DESC NULLS LAST").limit(limit)
      data = targets.pluck(:sku, :us_listing_price, :on_sale, :listing_condition, :shipping_type)
    else
      t = Time.now
      strTime = t.strftime("%Y年%m月%d日 %H時%M分")
      msg = "=========================\n価格改定開始（未改定商品なし）\n開始時刻：" + strTime + "\n========================="
      account.msend(
        msg,
        account.cw_api_token,
        account.cw_room_id
      )

      t = Time.now
      strTime = t.strftime("%Y年%m月%d日 %H時%M分")
      msg = "=========================\n価格改定フラグのクリア\n開始時刻：" + strTime + "\n========================="
      account.msend(
        msg,
        account.cw_api_token,
        account.cw_room_id
      )

      data = Product.where(user: user).pluck(:sku)
      data.each_slice(1000) do |tdata|
        uplist = Array.new
        tdata.each do |row|
          logger.debug(row)
          if row != nil then
            uplist << Product.new(user: user, sku: row.to_s, revised: false)
          end
        end
        Product.import uplist, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:revised]}
        tdata = nil
        uplist = nil
      end

      targets = Product.where(user: user, shipping_type: "default", revised: false)
      targets = targets.order("jp_price_updated_at DESC NULLS LAST").limit(limit)
      data = targets.pluck(:sku, :us_listing_price, :on_sale, :listing_condition, :shipping_type)
    end

    client = MWS.feeds(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    stream = ""
    File.open('app/others/Flat_File_PriceInventory_us.txt') do |file|
      file.each_line do |row|
        stream = stream + row
      end
    end
    st = Date.today.strftime("%Y-%m-%d") + "T00:00:00+09:00"

    temp = Feed.where(user: user)
    if temp != nil then
      temp.delete_all
    end
    htime = handling_time

    data.each_slice(1000) do |tdata|
      uplist = Array.new
      skulist = Array.new
      tdata.each do |row|
        logger.debug(row)
        sku = row[0]
        if sku != nil || sku != "" then
          if row[2] == true then
            quantity = 1
            price = row[1]
          else
            quantity = 0
            price = ""
          end

          fulfillment_channel = row[4]
          listing = false
          if price != "" then
            if price != 0 then
              buf = [sku, price, 0.1, price, quantity, htime, fulfillment_channel]
              listing = true
            else
              buf = [sku, "", "", "", 0, htime, fulfillment_channel]
              listing = false
            end
          else
            buf = [sku, "", "", "", 0, htime, fulfillment_channel]
            listing = false
          end
          part = buf.join("\t")
          stream = stream + part + "\n"
          uplist << Feed.new(user: user.to_s, sku: sku.to_s, price: price.to_s, quantity: quantity.to_s, handling_time: htime.to_s, fulfillment_channel: fulfillment_channel.to_s)
          skulist << Product.new(user: user, sku: sku.to_s, revised: true, listing: listing)
        end
      end
      Feed.import uplist
      Product.import skulist, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:revised, :listing]}
      uplist = nil
      skulist = nil
      tdata = nil
    end
    logger.debug(stream)
    feed_type = "_POST_FLAT_FILE_PRICEANDQUANTITYONLY_UPDATE_DATA_"
    parser = client.submit_feed(stream, feed_type)
    doc = Nokogiri::XML(parser.body)
    submissionId = doc.xpath(".//mws:FeedSubmissionId", {"mws"=>"http://mws.amazonaws.com/doc/2009-01-01/"}).text

    account.update(
      feed_submission_id: submissionId.to_s,
      feed_submit_at: DateTime.now,
      feed_status: "改定実行中"
    )

    GetFeedResultJob.set(queue: :feed_result).perform_later(user, submissionId)

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    msg = "=========================\n価格改定終了\n終了時刻：" + strTime + "\nフィードID：" + submissionId.to_s + "\n========================="
    account.msend(
      msg,
      account.cw_api_token,
      account.cw_room_id
    )
  end

  #商品データのダウンロード
  def output(user, target_columns)
    products = Product.where(user: user)

    t = Time.now
    strTime = t.strftime("%Y%m%d_%H%M%S")
    fname = "products_data_" + strTime + "_"

    #一時ファイルの作成
    temp_dir = 'tmp'
    fpath = nil
    temp_file = Tempfile.open([fname, ".csv"], temp_dir) do |f|
      bom = "\uFEFF"
      csv_string = CSV.generate(bom) do |csv|
        header = [
          "ASIN",
          "SKU",
          "日本価格[円]",
          "日本ポイント",
          "仕入値[円]",
          "奥行[cm]",
          "幅[cm]",
          "高さ[cm]",
          "重量[kg]",
          "梱包重量[kg]",
          "アメリカ最安値[$]",
          "アメリカ最安値の送料[$]",
          "最大ROI[%]",
          "アメリカ販売価格[$]",
          "AmazonReferralFee[$]",
          "販売手数料[%]",
          "VariableClosingFee[$]",
          "送料[円]",
          "発送代行手数料[円]",
          "為替レート[円/$]",
          "Payoneer手数料[%]",
          "計算為替[円/$]",
          "利益[円]",
          "最低販売価格[$]",
          "ROI[%]",
          "国内在庫",
          "出品中"
        ]

        shift = ENV['DL_SHIFT'].to_i
        range_max = ENV['DL_RANGE'].to_i
        if shift == 0 then
          shift = 0
        end

        if range_max == 0 then
          range_max = 200000
        end

        pos = shift
        range = 20000

        csv << header
        loop do
          results = products.offset(pos).limit(range).pluck(
            :asin,
            :sku,
            :jp_price,
            :jp_point,
            :cost_price,
            :size_length,
            :size_width,
            :size_height,
            :size_weight,
            :shipping_weight,
            :us_price,
            :us_shipping,
            :max_roi,
            :us_listing_price,
            :referral_fee,
            :referral_fee_rate,
            :variable_closing_fee,
            :listing_shipping,
            :delivery_fee,
            :exchange_rate,
            :payoneer_fee,
            :calc_ex_rate,
            :profit,
            :minimum_listing_price,
            :roi,
            :on_sale,
            :listing
          )
          break if results.empty?
          results.each do |result|
            csv << result
          end
          pos += range
          break if pos > range_max
        end
      end
      f.write(csv_string)
      fpath = f.path
      f.close(false)
    end

    account = Account.find_by(user: user)
    account.update(
      csv_path: fpath,
      csv_created_at: t
    )
  end
end
