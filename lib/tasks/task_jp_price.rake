namespace :task_jp_price do
  desc "日本アマゾンの価格情報取得"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    GetJpPriceJob.set(queue: :jp_new_item).perform_later(user, "New")
  end
end
