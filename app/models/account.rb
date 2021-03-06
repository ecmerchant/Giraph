class Account < ApplicationRecord
  def msend(message, api_token, room_id)
    base_url = "https://api.chatwork.com/v2"
    if message != nil && api_token != nil && room_id != nil then
      endpoint = base_url + "/rooms/" + room_id  + "/messages"
      request = Typhoeus::Request.new(
        endpoint,
        method: :post,
        params: { body: message },
        headers: {'X-ChatWorkToken'=> api_token}
      )
      request.run
      res = request.response.body
      logger.debug(res)
    else
      logger.debug('======= Chatwork Invalid =========')
    end
  end
end
