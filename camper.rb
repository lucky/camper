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
require 'cgi'
require 'tinder'
require 'xmpp4r-simple'
require 'daemons'
require 'yaml'

module Camper
  class Config
    def Config.load(file=nil)
      file ||= "#{Camper::config_dir}config.yaml"
      YAML.load_file(file)
    end
  end

  class Room
    def initialize(config)
      @config = config
    end

    def config
      @config
    end

    def im
      @im ||= Jabber::Simple.new(config["jabber"]["user"], 
                                 config["jabber"]["pass"])
    end

    def campfire
      unless @campfire
        @campfire = Tinder::Campfire.new(config["campfire"]["domain"], :ssl => config["campfire"]["ssl"])
        @campfire.login(config["campfire"]["user"], config["campfire"]["pass"])
      end
      @campfire
    end

    def chat
      @chat ||= campfire.find_room_by_name config["campfire"]["room"]
    end

    def im_deliver(msg)
      im.deliver(config["deliver_to"], msg)
    end

    def daemon_opts
      opts = [config["campfire"]["room"]]
      opts << {:dir_mode => :normal, :dir => Camper::config_dir, :backtrace => true}
    end

    def run
      Daemons.run_proc(*daemon_opts) do
        loop do 
          begin
            chat.listen.each do |msg|
              next if msg[:person].to_s != ''
              text = "#{msg[:person]}: #{msg[:message]}".gsub(/(\\n)+/, "\n").gsub(/\\u003C/, '<').gsub(/\\u003E/, '>').gsub(/\\u0026/, "&")
              text.gsub!(/<a href=\\"(.*)\\" target=\\"_blank\\">(.*)<\/a>/, '\1')
              text.gsub!(/<\/?[^>]*>/, "")
              text = CGI::unescapeHTML(text)
              im_deliver(text)
            end
            im.received_messages { |msg| chat.speak(msg.body) if msg.type == :chat }
            sleep 2
          rescue TimeoutError, SocketError
          rescue => e
            im_deliver("Error in Camper:\n\n#{e.class.name}\n#{e.backtrace.join("\n")}")
          end
        end
      end
    end 
  end

  def start
    configs = Camper::Config.load
    configs["rooms"].each do |config|
      Room.new(config).run
    end
  end

  def config_dir
    "#{ENV['HOME']}/.camper/"
  end

  module_function :start, :config_dir
end

Camper::start
