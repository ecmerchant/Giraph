class GetUsPriceJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user, condition)
    Product.new.check_amazon_us_price(user, condition)
  end
end
