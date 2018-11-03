namespace :task_report_get do
  desc "レポート情報取得"
  task :operate, ['user'] => :environment do |task, args|
    user = args[:user]
    GetReportJob.set(queue: :get_report).perform_later(user)
  end
end
