namespace :task_us_price do
  desc "米国アマゾンの価格取得"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    fee_check = ENV['FEE_CHECK']
    if fee_check == nil then
      fee_check = "FALSE"
    end
    
    GetUsPriceJob.set(queue: :us_new_item).perform_later(user, "New", fee_check)
  end
end
