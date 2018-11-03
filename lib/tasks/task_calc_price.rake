namespace :task_calc_price do
  desc "販売価格の計算"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    GetCalcJob.set(queue: :item_calc).perform_later(user)
  end
end
