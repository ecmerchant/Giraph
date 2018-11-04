class Feed < ApplicationRecord

  require 'peddler'
  require 'activerecord-import'

  def get_result(user, feed_submission_id)
    logger.debug("===== Get Feed Result =====")
    mp = "ATVPDKIKX0DER"  #アメリカアマゾン
    temp = Account.find_by(user: user)
    sid = temp.us_seller_id1
    skey = temp.us_secret_key1
    awskey = temp.us_aws_access_key_id1

    client = MWS.feeds(
      marketplace: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    response = client.get_feed_submission_result(feed_submission_id)
    parser = response.parse

    logger.debug(response.summary)
    logger.debug(response.content)

    temp = Feed.where(user: user).pluck(:sku)
    temp.each_slice(1000) do |feeds|
      uplist = Array.new
      feeds.each do |tt|
        tsku = tt
        uplist << Feed.new(user: user, sku: tsku, result: "成功")
      end
      Feed.import uplist, on_duplicate_key_update: {constraint_name: :for_upsert_feed, columns: [:result]}
      feeds = nil
      uplist = nil
    end

    if parser != nil then
      parser.each_slice(1000) do |rows|
        feed_list = Array.new
        rows.each do |row|
          tsku = row[1]
          if tsku != "sku" then
            terror = "エラー：" + row[4].to_s
            feed_list << Feed.new(user: user, sku: tsku, result: terror)
            logger.debug(tsku + " " + teeror)
          end
        end
        Feed.import feed_list, on_duplicate_key_update: {constraint_name: :for_upsert_feed, columns: [:result]}
        rows = nil
        feed_list = nil
      end
    end
  end
end
