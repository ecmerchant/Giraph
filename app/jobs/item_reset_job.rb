class ItemResetJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user)
    data = Product.where(user: user).pluck(:sku)
    data.each_slice(1000) do |tdata|
      uplist = Array.new
      tdata.each do |row|
        logger.debug(row)
        if row != nil then
          uplist << Product.new(user: current_user.email, sku: row.to_s, revised: false)
        end
      end
      Product.import uplist, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:revised]}
      tdata = nil
      uplist = nil
    end
  end
end
