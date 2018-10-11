class Product < ApplicationRecord

  require 'peddler'

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
        asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
        logger.debug("===== asin =======\n" + asin.to_s)
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
        temp = tproducts.where(asin: asin)
        if temp != nil then
          temp.update(jp_price: lowestprice.to_f, jp_shipping: lowestship.to_f, jp_point: lowestpoint.to_f)
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

end
