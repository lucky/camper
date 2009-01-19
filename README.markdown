# Camper

A Campfire (37Signals) to Jabber interface

## Requirements

- rubygems
- tinder
- xmpp4r-simple
- daemons

*Note*: Tinder requires Hpricot, which requires a build utilities and Ruby
development headers.

## Configuration

You must setup a config.yaml file in a $HOME/.camper directory, formatted like so:

    rooms: 
    - deliver_to: mainjabberaccount@example.com
      campfire: 
        ssl: true
        domain: campfiresubdomain 
        pass: foo
        user: campfireaccount@example.com 
        room: My Chat Room
      jabber: 
        pass: foo
        user: jabberproxy@example.com
    - deliver_to: anotherjabberaccount@example.com
      campfire: 
        ssl: true
        domain: campfiresubdomain 
        pass: bar
        user: anothercampfireaccount@example.com 
        room: My Chat Room
      jabber: 
        pass: bar
        user: anotherjabberproxy@example.com

