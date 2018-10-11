class GetReportJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user)
    temp = Product.new
    temp.get_listing_report(user)
  end
  
end
