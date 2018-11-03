namespace :task_submit_feed do
  desc "改定フィードの実行"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    limit = ENV['PER_REVISE_NUM']
    targets = Product.where(user: user, shipping_type: "default", revised: false)
    targets = targets.order("calc_updated_at DESC").limit(limit)
    temp = targets.pluck(:sku, :us_listing_price, :on_sale, :listing_condition, :shipping_type)
    tag = Product.new
    feed_id = tag.submit_feed(current_user.email, temp)
    logger.debug("====== Feed Subission ID ======")
    logger.debug(feed_id)
    logger.debug("===============================")
  end
end
