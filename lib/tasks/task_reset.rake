namespace :task_reset do
  desc "情報のリセット"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    ItemResetJob.set(queue: :item_reset).perform_later(user)
  end
end
