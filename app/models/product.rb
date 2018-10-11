class Product < ApplicationRecord

  require 'peddler'

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

    logger.debug(sid)
    logger.debug(skey)
    logger.debug(awskey)

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
      sleep(15)
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
    logger.debug("===== End FBA check =====")
  end

end
