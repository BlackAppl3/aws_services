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

  def generate_payload
    client = Aws::CognitoIdentityProvider::Client.new(
        region: "us-east-1",
        access_key_id: Figaro.env.AWS_ACCESS_KEY,
        secret_access_key: Figaro.env.AWS_SECRET_KEY
    )
    begin
    @user_info = client.get_user({
                               access_token: session[:access_token]
                           })
    rescue StandardError => e

    end
  end

  def send_payload_to_sns
    client = Aws::SNS::Client.new(
        region: "us-east-1",
        credentials: Aws::Credentials.new(Figaro.env.AWS_ACCESS_KEY, Figaro.env.AWS_SECRET_KEY)
    )
    begin
      #cognito_client = Aws::CognitoIdentityProvider::Client.new(
      #    region: "us-east-1",
      #    access_key_id: Figaro.env.AWS_ACCESS_KEY,
      #    secret_access_key: Figaro.env.AWS_SECRET_KEY
      #)
      #
      #cognito_client.get_user({
      #                            access_token: session[:access_token]
      #                        })

      headers = {
          "Authorization" => session[:identity_token],
          "Content-Type" => "application/json"
      }

      response = HTTParty.get("https://j5ftmdzhsa.execute-api.us-east-1.amazonaws.com/DummyStage/", :headers => headers)

      unless response.code == 200 and response["success"] == "true"
        redirect_to root_path, :flash => { error: 'You are not authenticated to send payload' } and return
      end

    rescue StandardError => e
      redirect_to root_path, :flash => { error: 'You are not authenticated to send payload' } and return
    end
    response = client.publish({
                                   target_arn: Figaro.env.SNS_TOPIC_ARN,
                                   message: params[:dummy][:message]
                              })

    redirect_to root_path
  end

  def sign_up_cognito_user
    secret_hash = -> (client_secret, username, client_id) {
      return Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', client_secret, username + client_id))
    }
    client = Aws::CognitoIdentityProvider::Client.new(
        region: "us-east-1",
        access_key_id: Figaro.env.AWS_ACCESS_KEY,
        secret_access_key: Figaro.env.AWS_SECRET_KEY
    )
    auth_object = {
        client_id: Figaro.env.CLIENT_APP,
        username: params[:dummy][:username],
        #secret_hash: secret_hash.call("SECRET", params[:dummy][:username], "CLIENT APP"),
        password: params[:dummy][:password],
        user_attributes: [
            {
                name: "email",
                value: params[:dummy][:email],
            }
        ]
    }
    client.sign_up(auth_object)
    redirect_to generate_payload_path
  end

  def login_cognito_user
    client = Aws::CognitoIdentityProvider::Client.new(
        region: "us-east-1",
        access_key_id: Figaro.env.AWS_ACCESS_KEY,
        secret_access_key: Figaro.env.AWS_SECRET_KEY
    )
    response = client.initiate_auth({
              client_id: Figaro.env.CLIENT_APP,
              auth_flow: "USER_PASSWORD_AUTH",
              auth_parameters: {
                    "USERNAME" => params[:dummy][:username],
                    "PASSWORD" => params[:dummy][:password]
                  }
              })
    session[:access_token] = response.to_hash[:authentication_result][:access_token]
    session[:identity_token] = response.authentication_result.id_token
    redirect_to generate_payload_path
  end

  def signout_cognito
    client = Aws::CognitoIdentityProvider::Client.new(
        region: "us-east-1",
        access_key_id: Figaro.env.AWS_ACCESS_KEY,
        secret_access_key: Figaro.env.AWS_SECRET_KEY
    )

    client.global_sign_out({
                               access_token: session[:access_token]
                           })
    session.delete(:access_token)
    session.delete(:identity_token)
    redirect_to generate_payload_path
  end
end
