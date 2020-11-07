# Send to Point of Sale
def pos(str)
    `./print_pos.py "#{str}"`
end

# # # # # # # # # # #
# TWITTER Listener  #
# # # # # # # # # # #
require 'twitter'

$received_tweets = $received_tweets || []
$twitter_last_checked = Time.now - 10*60

def check_tweets()
    twitter = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
        config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
        config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
        config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
    end

    return false unless $twitter_last_checked < Time.now - 60
    puts("Checking Tweets")
    new_messages = false
    twitter.mentions_timeline.each do |tweet|
        next if tweet.created_at.to_datetime < Date.today
        tweet = {
            user: tweet.user,
            message: tweet.text,
            time: tweet.created_at.strftime("%r")
        }
        next if $received_tweets.include? tweet
        $received_tweets << tweet
        new_messages = true
        pos("New Tweet - #{tweet[:time]}")
        pos("@#{tweet[:user].screen_name} (#{tweet[:user].friends_count}/#{tweet[:user].followers_count}):")
        pos("#{tweet[:message]}")
        pos("")
    end
    $twitter_last_checked = Time.now
    return new_messages
end

# # # # # # # # #
# MAIL Listener #
# # # # # # # # #
require 'mail'

pop_user = ENV['EMAIL_POP_USER']
pop_pass = ENV['EMAIL_POP_PASS']

Mail.defaults do
    retriever_method :pop3, :address => "pop.fastmail.com",
                            :port    => 995,
                            :user_name => pop_user,
                            :password => pop_pass,
                            :enable_ssl => true
end

$received_emails = $received_emails || []
$email_last_checked = Time.now - 10*60

def check_email()
    # Only check email every minute
    return false unless $email_last_checked < Time.now - 60
    puts("Checking Email")
    new_messages = false
    Mail.all.each do |email|
        email = {
            from: email.from,
            subject: email.subject,
            time: email.date.strftime("%r")
        }
        next if $received_emails.include? email
        $received_emails << email
        pos("New Email - #{email[:time]}")
        pos("From: #{email[:from].join(", ")}")
        pos("#{email[:subject]}")
        pos("")
        new_messages = true
    end
    $email_last_checked = Time.now
    return new_messages
end

pos("Offline Notification System")
pos("")

loop do 
    update = false
    update = update || check_email()
    update = update || check_tweets()
    pos("") if update
end