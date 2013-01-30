require 'thread'
require 'curses'
require 'yaml'
require 'twitter'

require_relative 'scroller.rb'

def load_config

   conf = YAML::load(File.read('conf/account.yaml'))

   Twitter.configure do |config|

      # set application details
      config.consumer_key = conf['consumerkey']
      config.consumer_secret = conf['consumersecret']

      # set access token details
      config.oauth_token = conf['oauthtoken']
      config.oauth_token_secret = conf['oauthtokensecret']

   end
end

def get_tweets(context)

   tweets = nil

   if context.length == 0 then
      tweets = Twitter.home_timeline
   else
      tweets = Twitter.search(context, :count => 20, :result_type => 'recent').results
   end

   tweets

end

def colorize_tweet(from, text, win)

   orig = Curses.color_pair(Curses::COLOR_BLUE) | Curses::A_NORMAL
   user = Curses.color_pair(Curses::COLOR_RED) | Curses::A_NORMAL
   tag  = Curses.color_pair(Curses::COLOR_GREEN) | Curses::A_NORMAL
   url  = Curses.color_pair(Curses::COLOR_MAGENTA) | Curses::A_NORMAL

   # first, print who the tweet was made by in blue
   win.addstr("<")
   win.attron(orig) { win.addstr("#{from}") }
   win.addstr("> ")

   text.split(' ').each do |word|
      case word
         when /^@.*$/ then win.attron(user) { win.addstr(word) }
         when /^#.*$/ then win.attron(tag) { win.addstr(word) }
         when /^https?:\/\/[\S]+$/ then win.attron(url) { win.addstr(word) }
         else win.addstr(word)
      end

      win.addstr(' ')
   end

end

begin
   current_tweets = []
   context = ""
   running = true
   force_clear = false
   mutex = Mutex.new
   resource = ConditionVariable.new

   load_config

   Curses.init_screen
   Curses.start_color
   Curses.use_default_colors

   # initialize some colours
   Curses.init_pair(Curses::COLOR_BLACK, Curses::COLOR_BLACK, -1)
   Curses.init_pair(Curses::COLOR_BLUE, Curses::COLOR_BLUE, -1)
   Curses.init_pair(Curses::COLOR_RED, Curses::COLOR_RED, -1)
   Curses.init_pair(Curses::COLOR_GREEN, Curses::COLOR_GREEN, -1)
   Curses.init_pair(Curses::COLOR_MAGENTA, Curses::COLOR_MAGENTA, -1)

   # create the channel window
   channel = ScrollerWindow.new(Curses.lines - 3, Curses.cols, 0, 0)
   channel.refresh


   # create the refresh-thread to re-paint the
   # channel window
   redraw_thread = Thread.new do
      while running do
         mutex.synchronize do
            begin
               # get all tweets for the current context
               tweets = get_tweets(context)

               # filter out tweets that are already on screen
               filtered = tweets.select { |t| !current_tweets.include?(t.id) }
               current_tweets.concat(filtered.collect { |t| t.id })

               # check if we want a clear
               if force_clear then
                  channel.window.clear
                  force_clear = false
               end

               # present tweets
               filtered.map do |tweet|
                  colorize_tweet(tweet.from_user, tweet.text, channel.window)
                  channel.println("")
               end
            rescue Exception => e
               channel.println("Fail: " + e.to_s)
            end

            resource.wait(mutex, 60)
         end
      end
   end

   # create the speech window
   talk = ScrollerWindow.new(3, Curses.cols, Curses.lines - 3, 0)
   talk.refresh

   while running do
      # take input from the talk window
      command = talk.window.getstr()

      # interpret the command
      running = false if /^\/quit$/.match(command)
      resource.signal if /^\/refresh$/.match(command)

      # test if we're switching contexts
      context_parts = /^\/show (?<context>.*)$/.match(command)
      if context_parts != nil then
         context = context_parts['context']
         current_tweets = []
         force_clear = true
         resource.signal
      end

   end

   # let the redraw thread know that it's over
   resource.signal

   # join it back up
   redraw_thread.join

   channel.close
   talk.close

ensure
   Curses.close_screen
end