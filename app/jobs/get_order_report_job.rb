class GetOrderReportJob < ApplicationJob
  queue_as :get_order_report

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user, start_date, end_date)
    OrderList.new.get_order_report(user, start_date, end_date)
  end
end
