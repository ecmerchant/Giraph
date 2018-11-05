class SubmitFeedJob < ApplicationJob
  queue_as :submit_feed

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user)
    Product.new.submit_feed(user)
  end

end
