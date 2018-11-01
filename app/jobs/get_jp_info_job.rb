class GetJpInfoJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user, condition)
    logger.debug("==== GET JP INFO JOB ====")
    Product.new.check_amazon_jp_info(user, condition)
  end

end
