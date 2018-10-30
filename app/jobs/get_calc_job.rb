class GetCalcJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user)
    logger.debug("==== GET CALC JOB ====")
    Product.new.calc_profit(user)
  end

end
