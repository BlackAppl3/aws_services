class ServicesController < ApplicationController
  def index
  end

  def receive_sns
    payload_data =  (JSON.parse request.raw_post) rescue {}
    puts "-------------------------- #{payload_data}"
    if payload_data["Type"] == "SubscriptionConfirmation"
      HTTParty.post(payload_data["SubscribeURL"])
    else
      client = Aws::SQS::Client.new(
          region: "us-east-1",
          credentials: Aws::Credentials.new(Figaro.env.AWS_ACCESS_KEY, Figaro.env.AWS_SECRET_KEY)
      )
      queue_url = client.get_queue_url({queue_name: "DummyQueue"}).to_h
      client.send_message({
                               queue_url: queue_url[:queue_url],
                               message_body: payload_data.to_json.to_s
                           })
    end
  end

  def generate_payload ; end

  def send_payload_to_sns
    client = Aws::SNS::Client.new(
        region: "us-east-1",
        credentials: Aws::Credentials.new(Figaro.env.AWS_ACCESS_KEY, Figaro.env.AWS_SECRET_KEY)
    )

    response = client.publish({
                                   target_arn: "arn:aws:sns:us-east-1:413021432718:DummyTopic1",
                                   message: params[:dummy][:message]
                              })

    redirect_to root_path
  end
end
