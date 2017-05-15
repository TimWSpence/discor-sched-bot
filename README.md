Overview
========

A scheduling bot for [Discord](https://discordapp.com/)

Example usage
-------------
`!sched create partay 2017-08-05 20:00`    create a new event

`!sched list`                              list all current events

`!sched yes <ID of event>`                 accept invitation to event

`!sched responses <ID of event>`           list current responses to event

`!sched help`                              display help text

Installation
------------

### Prerequisites
1. The required version of Ruby installed (currently 2.3.0). If you do not have Ruby installed, I thoroughly recommend [RVM](https://rvm.io/rvm/install)
2. [Bundler](http://bundler.io/) can then be installed via: ```gem install bundler```

### Installing sched bot
```
bundle install
ruby bot.rb
```

Note that you have to edit your client id and token in a file called config.yml, as per https://discordapp.com/developers/applications/me
