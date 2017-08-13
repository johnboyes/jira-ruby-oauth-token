require 'dotenv'
Dotenv.load

class App < Sinatra::Base
  enable :sessions

  before do
    session[:oauth] ||= {}

    @consumer ||= OAuth::Consumer.new(
      ENV['CONSUMER_KEY'],
      OpenSSL::PKey::RSA.new(IO.read(File.dirname(__FILE__) + "/#{ENV['PRIVATE_KEY_FILE']}")),
      {
      :site => ENV['SITE_DOMAIN'],
      :signature_method => 'RSA-SHA1',
      :scheme => :header,
      :http_method => :post,
      :request_token_path=> '/plugins/servlet/oauth/request-token',
      :access_token_path => '/plugins/servlet/oauth/access-token',
      :authorize_path => '/plugins/servlet/oauth/authorize'
    })

    @consumer.http.set_debug_output($stderr) if ENV['DEBUG'].downcase == 'true'

    if !session[:oauth][:request_token].nil? && !session[:oauth][:request_token_secret].nil?
      @request_token = OAuth::RequestToken.new(@consumer, session[:oauth][:request_token], session[:oauth][:request_token_secret])
    end

    if !session[:oauth][:access_token].nil? && !session[:oauth][:access_token_secret].nil?
      @access_token = OAuth::AccessToken.new(@consumer, session[:oauth][:access_token], session[:oauth][:access_token_secret])
    end
  end

  get '/' do
    if !session[:oauth][:access_token]
      "<h1>JIRA REST API OAuth Demo</h1>You're not signed in. Why don't you <a href=/signin>sign in</a> first."
    else
      <<-eos
        Access token: #{session[:oauth][:access_token]}
        Access token secret: #{session[:oauth][:access_token_secret]}
      eos
    end
  end

  get '/signin' do
    @request_token = @consumer.get_request_token(:oauth_callback => "http://#{request.host}:#{request.port}/auth")
    session[:oauth][:request_token] = @request_token.token
    session[:oauth][:request_token_secret] = @request_token.secret
    redirect @request_token.authorize_url
  end

  get "/auth" do
    @access_token = @request_token.get_access_token :oauth_verifier => params[:oauth_verifier]
    puts "access token"
    puts @access_token
    session[:oauth][:access_token] = @access_token.token
    session[:oauth][:access_token_secret] = @access_token.secret
    redirect "/"
  end

  get "/signout" do
    session[:oauth] = {}
    @current_user = nil
    redirect "/"
  end
end
