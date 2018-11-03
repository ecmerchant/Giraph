namespace :task_jp_info do
  desc "日本アマゾンの商品情報取得"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    GetJpInfoJob.set(queue: :jp_new_info).perform_later(user, "New")
  end
end
