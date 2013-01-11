#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'libfchat/fchat'
require 'yaml'

class Libfchat::Fchat

  # Join chatrooms on invite
  def got_CIU(message)
    #Annoyingly, the json for this varies for public and private rooms.
    #So just try both and call it a day.
    self.send('JCH',message['name'])
    self.send('JCH',message['channel'])
  end
  
  # Respond to private messages
  def got_PRI(message)
    msg = "Bottlebot 1.0 by Jippen Faddoul ( http://github.com/jippen/fchat_bottlebot_ruby )"
    self.send('PRI',message['character'],msg)
    sleep(1)
  end
  
  # Respond to messages in chatrooms
  def got_MSG(message)
    p "------"
    if message['message'].downcase =~ /^!spin/
      msg = message['character'] + ": " + @deck.draw()
      self.send('MSG',message['channel'],msg)
      sleep(1)
    end
  end
end

bot = Libfchat::Fchat.new("Bottlebot by Jippen Faddoul ( http://github.com/jippen/fchat_bottlebot_ruby )","1.0")
config = YAML.load_file('bottlebot.yaml')

bot.login(config['server'],config['username'],config['password'],config['character'])
