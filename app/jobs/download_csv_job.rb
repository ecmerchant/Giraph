class DownloadCsvJob < ApplicationJob
  queue_as :download_csv

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user, target_columns)
    Product.new.output(user, target_columns)
  end
end
