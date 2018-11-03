namespace :task_reset do
  desc "情報のリセット"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]

    products = Product.where(user: user, sku_checked: false)
    products.delete_all

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
