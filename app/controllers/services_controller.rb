class ServicesController < ApplicationController
  def index
  end

  def receive_sns
    payload_data =  (JSON.parse request.raw_post) rescue {}
    if payload_data["Type"] == "SubscriptionConfirmation"
      HTTParty.post(payload_data["SubscribeURL"])
    else
      client = Aws::SQS::Client.new(
          region: "us-east-1",
          credentials: Aws::Credentials.new("YourAccessKey", "YourSecretKey"))
      queue_url = client.get_queue_url({queue_name: "DummyQueue"}).to_h
      client.send_message({
                               queue_url: queue_url[:queue_url],
                               message_body: payload_data.to_json
                           })
    end
  end
end
