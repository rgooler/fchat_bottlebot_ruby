#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'libfchat/fchat'
require 'yaml'
require 'logger'

class Bottlebot < Libfchat::Fchat
  attr_accessor :last_spun
  attr_accessor :current_player

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
    elsif message['message'] == 'dump'
      print @users.inspect
    elsif message['message'] == 'dumproom'
      @rooms.each { |r|
        puts r
        @rooms[r]['characters'].each {|char|
          puts @users[char]
        }  
      }
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
    @logger.info("got_MSG()")
    @logger.info("got_MSG() - #{message['message']}")
    self.fix_skiplist(message['channel'])
    @logger.info("got_MSG() - fix_skiplist()")
    self.remove_from_skip_list(message['channel'], message['character'])
    @logger.info("got_MSG() - remove_from_skip_list()")
    if message['message'] == '!skip'
      self.add_to_skip_list(message['channel'], message['character'])
    elsif message['message'] =~ /^!skip/
      person = message['message'].gsub(/^!skip/, '').strip
      self.add_to_skip_list(message['channel'], person)
    elsif message['message'] =~ /^!spin/
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
    else
      @logger.info("gotMSG() - parseFail")
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

    @rooms[channel]['skiplist'] << person
    self.MSG(channel, "Now skipping: [b]#{person}[/b]")
  end

  def fix_skiplist(channel)
    if @rooms[channel]['skiplist'] == nil
      @rooms[channel]['skiplist'] = []
    end
  end

  def spin_list(channel, character)
    @logger.info("spin_list()")
    eligible = @rooms[channel]['characters']
    @logger.info("eligible - #{eligible}")
    self.fix_skiplist(channel)
    @logger.info("fix skip list")
    eligible.delete_if { |c| character_spinnable(channel, c) == false }
    eligible.delete(character)
    return eligible
  end

  def character_spinnable(channel, character)  
    fix_skiplist(channel)
    status = @users[character]['status']
    begin
      if ['busy', 'dnd', 'away'].include? status
        return false
      elsif character == @me
        return false
      elsif @rooms[channel]['skiplist'].include? character
        return false
      else
        return true
      end
    rescue
      return false
    end
  end
end
