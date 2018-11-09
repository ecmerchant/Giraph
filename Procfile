web: bundle exec puma -C config/puma.rb
worker: TERM_CHILD=1 QUEUES=download_csv,item_reset,submit_feed,feed_result,item_calc,jp_new_item,us_new_item,jp_new_info,jp_used_item,us_used_item,jp_used_info,* rake environment resque:work
web: rake task_jp_price:operate["shigemiyagi@gmail.com"]
web: rake task_us_price:operate["shigemiyagi@gmail.com"]
