class GetFeedResultJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user, feed_id)
    temp = Feed.new
    temp.get_result(user, feed_id)
  end

end
