class SubmitFeedJob < ApplicationJob
  queue_as :submit_feed

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user, data)
    Product.new.submit_feed(user, data)
  end

end
