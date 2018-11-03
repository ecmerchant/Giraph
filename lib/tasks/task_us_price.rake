namespace :task_us_price do
  desc "米国アマゾンの価格取得"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    GetUsPriceJob.set(queue: :us_new_item).perform_later(user, "New")
  end
end
