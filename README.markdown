# Camper

A Campfire (37Signals) to Jabber interface

## Requirements

- rubygems
- tinder
- xmpp4r-simple
- daemons
- yaml

## Configuration

You must setup a config.yaml file in a $HOME/.camper directory, formatted like so:

    rooms: 
    - deliver_to: mainjabberaccount@example.com
      campfire: 
        ssl: true
        domain: campfiresubdomain 
        pass: foobar
        user: campfireaccount@example.com 
        room: My Chat Room
      jabber: 
        pass: foobar
        user: jabberproxy@example.com

