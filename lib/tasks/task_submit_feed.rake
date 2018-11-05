namespace :task_submit_feed do
  desc "改定フィードの実行"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    Product.new.submit_feed(user)
  end
end
