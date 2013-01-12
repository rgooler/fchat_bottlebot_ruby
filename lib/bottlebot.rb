#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'libfchat/fchat'
require 'yaml'
require 'logger'

class Bottlebot < Libfchat::Fchat
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
    @logger.info("got_MSG(#{message})")
    self.fix_skiplist(message['channel'])
    self.remove_from_skip_list(message['channel'], message['character'])
    if message['message'].downcase =~ /^!spin/
      @logger.info("got_MSG() - spinning the bottle")
      players = self.spin_list(message['channel'], message['character'])
      @logger.info("got_MSG() - players: #{players}")
      if players == []
        msg = "/me can't find anyone to play with!"
      else
        player = players.sample
        msg = "/me spins around, and eventually lands on [b]#{player}[/b]"
      end
      self.send('MSG',message['channel'],msg)
    elsif message['message'].downcase =~ /^!skip/
      person = message['message'].gsub(/^!skip/, '').strip
      @logger.info("got_MSG() - Skipping someone, possibly #{person}")
      if person == ''
        person = message['character']
      end
      @logger.info("got_MSG() - Skipping someone, actually #{person}")
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
    @logger.info("fix_skiplist(#{channel})")
    if @rooms[channel]['skiplist'] == nil
      @logger.info("fix_skiplist() - fixing")
      @rooms[channel]['skiplist'] = []
    end
    @logger.info("fix_skiplist() - #{@rooms[channel['skiplist']]}")
  end

  def spin_list(channel, character)
    eligible = @rooms[channel]['characters']
    eligible.delete(@me)
    eligible.delete(character)
    self.fix_skiplist(channel)
    @rooms[channel]['characters'].each { |char|
      @logger.info("char: #{char} - #{@users[char]}")
      if character_spinnable(channel, char) == false
        eligible.delete(char)
      end
    }
    return eligible
  end

  def character_spinnable(channel, character)
    puts "character_spinnable(#{channel}, #{character})"
    if @users[character]['status'] == 'busy'
      puts "Removing #{char} for being busy"
      return false
    elsif @users[char]['status'] == 'dnd'
      puts "Removing #{char} for being dnd"
      return false
    elsif @users[char]['status'] == 'away'
      puts "Removing #{char} for being away"
      return false
    elsif @rooms[channel]['skiplist'].include? char
      puts "Removing #{char} in skiplist"
      return false
    end
    return true
  end
end
