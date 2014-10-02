require 'thread'
require 'twitter'
require 'yaml'
require 'obscenity'

class TwitterStream

  def initialize
    @callbacks = []
    creds = File.join(__dir__, '../config/twitter.yml')
    $logger.info "Loading Twitter credentials from #{File.absolute_path(creds)}"
    @twitter_config = YAML::load_file(creds)

    Obscenity.config do |config|
      config.blacklist = "./badwords.yml"
    end

    stream
  end

  def tw_client
    Twitter::Streaming::Client.new do |config|
      config.consumer_key = @twitter_config["consumer_key"]
      config.consumer_secret = @twitter_config["consumer_secret"]
      config.access_token = @twitter_config["access_token"]
      config.access_token_secret = @twitter_config["access_token_secret"]
    end
  end

  def ontweet(&block)
    @callbacks << block
  end

  def stream
    Thread.new do
      retry_count = 0
      begin
        filter_bounds = "-180,-90,180,90"
        $logger.info "Making connection to Twitter streaming API..."
        tw_client.filter(locations: filter_bounds) do |object|
          if object.is_a? Twitter::Tweet
            tweet = object.to_h
            if Obscenity.profane? tweet[:text] then
              tweet["obscene"] = true
            end
            @callbacks.each { |c| c.call(tweet) }
            retry_count = 0
          elsif object.is_a? Twitter::Streaming::StallWarning
            $logger.warn "Falling behind!"
          end
        end
      rescue => e
        retry_count += 1
        $logger.error "Stream connection error: #{e.message}"
        retry_delay = retry_count * 5
        $logger.error "Reconnecting in #{retry_delay} seconds"
        sleep retry_delay
        retry
      end
    end
  end

end