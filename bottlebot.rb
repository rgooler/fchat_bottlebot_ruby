#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'libfchat/fchat'
require 'yaml'
require 'pp'

class Libfchat::Fchat
  attr_accessor :last_spun
  attr_accessor :current_player


  # Join chatrooms on invite
  def got_CIU(message)
    #Annoyingly, the json for this varies for public and private rooms.
    #So just try both and call it a day.
    self.send('JCH',message['name'])
    self.send('JCH',message['channel'])
  end
  
  # Respond to private messages
  def got_PRI(message)
    if message['message'] =~ /^join/
      room = message['message'].gsub(/^join/, '').strip
      self.JCH(room)
    elsif message['message'] =~ /^lookup/
      who = message['message'].gsub(/^lookup/, '').strip
      msg = "[b]#{who}:[/b]\n"
      msg += @users[who]['status'] + "\n"
      msg += @users[who]['message'] 
      self.PRI(message['character'], msg)
    elsif message['message'] =~ /^leave/
      if @friends.include? message['character']
        room = message['message'].gsub(/^leave/, '').strip
        self.LCH(room)
      else
        msg = "I'm sorry, you're not allowed to ask me to leave that room"
        self.PRI(message['character'], msg)
      end
    else
      msg = "Bottlebot 1.0 by Jippen Faddoul ( http://github.com/jippen/fchat_bottlebot_ruby )"
      msg += "\nCommands:\n"
      msg += "join <room> - Joins a chatroom (If private, /invite the bot instead)"
      msg += "leave <room> - Leaves a chatroom (If private, /invite the bot instead)"
      self.PRI(message['character'], msg)
      sleep(@msg_flood)
    end
  end
  
  # Respond to messages in chatrooms
  def got_MSG(message)
    if @spam
      puts "got_MSG(#{message})"
    end
    self.fix_skiplist(message['channel'])
    self.remove_from_skip_list(message['channel'], message['character'])
    if message['message'].downcase =~ /^!spin/
      if @spam
        puts "got_MSG() - spinning the bottle"
      end
      players = self.spin_list(message['channel'], message['character'])
      if @spam
        puts "got_MSG() - players: #{players}"
      end
      if players == []
        msg = "/me can't find anyone to play with!"
      else
        player = players.sample
        msg = "/me spins around, and eventually lands on [b]#{player}[/b]"
      end
      self.send('MSG',message['channel'],msg)
    elsif message['message'].downcase =~ /^!skip/
      person = message['message'].gsub(/^!skip/, '').strip
      if @spam
        puts "got_MSG() - Skipping someone, possibly #{person}"
      end
      if person == ''
        person = message['character']
      end
      if @spam
        puts "got_MSG() - Skipping someone, actually #{person}"
      end
      self.add_to_skip_list(message['channel'], person)
    end
  end

  def remove_from_skip_list(channel, person)
    self.fix_skiplist(channel)
    @rooms[channel]['skiplist'].delete(person)
  end

  # Perform a case-insensitive search for a user in a room
  def search_for_character(channel, person)
    if @rooms[channel]['characters'].include? person
      return person
    else
      re = /\A#{Regexp.escape(person)}\z/i
      @rooms[channel]['characters'].each { |char|
        if char =~ re
          return char
        end
      }
    end
    return nil
  end

  def add_to_skip_list(channel, person)
    self.fix_skiplist(channel)
    person = self.search_for_character(channel, person)
    if person == nil
      return
    end

    msg = "Now skipping: [b]#{person}[/b]"
    @rooms[channel]['skiplist'] << person
    self.MSG(channel, msg)
  end

  def fix_skiplist(channel)
    if @spam
      puts "fix_skiplist(#{channel})"
    end
    if @rooms[channel]['skiplist'] == nil
      if @spam
        puts "fix_skiplist() - fixing"
      end
      @rooms[channel]['skiplist'] = []
    end
    if @spam
      puts "fix_skiplist() - #{@rooms[channel['skiplist']]}"
    end
  end

  def spin_list(channel, character)
    eligible = @rooms[channel]['characters']
    eligible.delete(@me)
    self.fix_skiplist(channel)
    puts "I am #{self.me}"
    @rooms[channel]['characters'].each do |char|
      puts "char: #{char} - #{@users[char]}"
      if @users[char]['status'] == 'busy'
        puts "Removing #{char} for being busy"
        eligible.delete(char)
      elsif @users[char]['status'] == 'dnd'
        puts "Removing #{char} for being dnd"
        eligible.delete(char)
      elsif @users[char]['status'] == 'away'
        puts "Removing #{char} for being away"
        eligible.delete(char)
      elsif @rooms[channel]['skiplist'].include? char
        puts "Removing #{char} in skiplist"
        eligible.delete(char)
      elsif char == character
        puts "Removing #{char} == character"
        eligible.delete(char)
      end
    end
    return eligible
  end
end

bot = Libfchat::Fchat.new("Bottlebot by Jippen Faddoul ( http://github.com/jippen/fchat_bottlebot_ruby )","1.0")
config = YAML.load_file('bottlebot.yaml')

bot.login(config['server'],config['username'],config['password'],config['character'])
