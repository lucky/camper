# The MIT License
# 
# Copyright (c) 2008 Jared Kuolt
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'rubygems'
require 'tinder'
require 'xmpp4r-simple'
require 'daemons'
require 'yaml'

module Camper
  Commands = { "users" => Proc.new { |c| c.users }}

  module CampfireExtension
    def msg(msg, type=:speak)
      attempts = 0
      begin
        attempts += 1
        self.send(type, msg)
      rescue TimeoutError, SocketError => e
        retry if attempts < 3
        raise e
      end
    end
  end

  class Room
    def initialize(config)
      @config = config.symbolize_keys!
      chat.extend(CampfireExtension)
    end

    def config
      @config
    end

    def im
      @im ||= Jabber::Simple.new(config[:jabber][:user], 
                                 config[:jabber][:pass])
    end

    def campfire
      unless @campfire
        @campfire = Tinder::Campfire.new(config[:campfire][:domain], :ssl => config[:campfire][:ssl])
        @campfire.login(config[:campfire][:user], config[:campfire][:pass])
      end
      @campfire
    end

    def chat
      @chat ||= campfire.find_room_by_name config[:campfire][:room]
    end

    def im_deliver(msg)
      im.deliver(config[:deliver_to], msg)
    end

    def daemon_opts
      opts = [config[:campfire][:room]]
      opts << {:dir_mode => :normal, :dir => Camper::config_dir, :backtrace => true}
    end

    def users
      Hpricot(chat.users.join).search("span").collect {|e| e.inner_text }.join(", ")
    end

    def deliver_campfire_messages
      chat.listen.each do |msg|
        next if msg[:person].empty?
        text = "#{msg[:person]}: #{msg[:message]}".gsub(/(\\n)+/, "\n").gsub(/\\u003C/, '<').gsub(/\\u003E/, '>').gsub(/\\u0026/, "&")
        text.gsub!(/<a href=\\"(.*)\\" target=\\"_blank\\">(.*)<\/a>/, '\1')
        im_deliver(Hpricot(text).to_plain_text)
      end
    end

    def deliver_jabber_messages
      im.received_messages do |msg|
        next unless msg.type == :chat

        command = msg.body.scan(/^!(.*)/).flatten[0]

        if Commands.key?(command)
          im_deliver(Commands[command].call(self))
        else
          type = msg.body.strip =~ /\n/ ? :paste : :speak
          chat.msg(msg.body, type)
        end
      end
    end

    def iterate
      begin
        deliver_campfire_messages
        deliver_jabber_messages
        sleep 2
      rescue => e
        im_deliver("Error in Camper:\n\n#{e.class.name}\n#{e.backtrace.join("\n")}")
      end
    end

    def run
      Daemons.run_proc(*daemon_opts) do
        loop { iterate }
      end
    end 
  end

  def load_config(file=nil)
    file ||= "#{Camper::config_dir}config.yaml"
    YAML.load_file(file)
  end

  def start
    configs = Camper::load_config 
    configs["rooms"].each do |config|
      Room.new(config).run
    end
  end

  def config_dir
    "#{ENV['HOME']}/.camper/"
  end

  module_function :start, :config_dir, :load_config
end

class Hash

  def symbolize_keys!
    self.each do |k,v|
      self.delete k
      self[k.to_sym] = (v.is_a?(Hash)? v.symbolize_keys! : v )
    end
    self
  end

end

Camper::start
