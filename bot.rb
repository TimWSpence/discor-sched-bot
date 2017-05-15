require 'discordrb'
require 'fileutils'
require 'pathname'
require 'securerandom'
require 'time'

$command_prefix = :sched

class ServerEventStore

  def initialize(data_dir, server)
    @data_dir = data_dir.join(server)
    if !File.exist?(@data_dir)
      FileUtils.mkdir_p(@data_dir)
    end
  end

  def store(channel, id, event)
    current = _retrieve(channel)
    current[id] = event
    _store(channel, current)
  end

  def retrieve(channel, id)
    current = _retrieve(channel)
    if current
      current[id]
    else
      nil
    end
  end

  def delete(channel, id)
    current = _retrieve(channel)
    current.delete(id)
    _store(channel, current)
  end

  def list(channel)
    current = _retrieve(channel)
    current.delete_if { |key, value| value.time < Time.now }
    _store(channel, current)
    if current.empty?
      "There are no events currently scheduled"
    else
      current.values.map(&:print_pretty).join("\n")
    end
  end

  private
  def _retrieve(channel)
    begin
      content = File.read(@data_dir.join(channel))
      Marshal.load(content)
    rescue => e
      puts "Error is #{e}"
      {}
    end
  end

  def _store(channel, events)
    File.open(@data_dir.join(channel), "wb") do |f|
      f.write(Marshal.dump(events))
    end
  end

end



class Event

  attr_reader :id, :name, :time, :accepted, :declined, :maybe

  def initialize(id, name, time)
    @id = id
    @name = name
    @time = time
    @accepted = []
    @declined = []
    @maybe = []
  end

  def print_pretty
    "#{@id}: #{@name} scheduled for #{@time}"
  end

  def responses
    <<~EOF
Yes: #{@accepted.map(&:name).join(', ')}
No: #{@declined.map(&:name).join(', ')}
Maybe: #{@maybe.map(&:name).join(', ')}
    EOF
  end

  def accept(user)
    remove_user_from_lists(user)
    @accepted.push(User.new(user.id, user.username))
  end

  def decline(user)
    remove_user_from_lists(user)
    @declined.push(User.new(user.id, user.username))
  end

  def maybe(user)
    remove_user_from_lists(user)
    @maybe.push(User.new(user.id, user.username))
  end

  private
  def remove_user_from_lists(user)
    @accepted.delete_if {|u| u.id == user.id }
    @declined.delete_if {|u| u.id == user.id }
    @maybe.delete_if {|u| u.id == user.id }
  end

end

class User

  attr_reader :id, :name

  def initialize(id, name)
    @id = id
    @name = name
  end
end

def handle_create(event, args)
  id = SecureRandom.uuid
  name = args[1]
  time = Time.parse(args[2..-1].join(' '))
  if time < Time.now
    event.respond "Cannot create an event in the past"
  else
    $newstore.store(event.channel.name, id, Event.new(id, name, time))
    event.respond "New event #{name} scheduled for #{time}"
  end
end

def handle_list(event, args)
  event.respond $newstore.list(event.channel.name)
end

def handle_yes(event, args)
  handle_missing(event, args) do |scheduled|
    scheduled.accept(event.user)
    $newstore.store(event.channel.name, scheduled.id, scheduled)
    nil
  end
end

def handle_no(event, args)
  handle_missing(event, args) do |scheduled|
    scheduled.decline(event.user)
    $newstore.store(event.channel.name, scheduled.id, scheduled)
    nil
  end
end

def handle_maybe(event, args)
  handle_missing(event, args) do |scheduled|
    scheduled.maybe(event.user)
    $newstore.store(event.channel.name, scheduled.id, scheduled)
    nil
  end
end

def handle_delete(event, args)
  handle_missing(event, args) do |scheduled|
    $newstore.delete(event.channel.name, scheduled.id)
    nil
  end
end

def handle_responses(event, args)
  handle_missing(event, args) do |scheduled|
    puts "Responses for event: #{scheduled}"
    scheduled.responses
  end
end

def handle_missing(event, args, &block)
  event_id = args[1]
  scheduled = $newstore.retrieve(event.channel.name, event_id)
  if scheduled
    event.respond block[scheduled]
  else
    event.respond "No event found with id #{event_id}"
  end
end

def handle_help(event, args)
  event.respond <<~EOF
Usage: !#{$command_prefix} <COMMAND> <ARGS>
where <COMMAND> one of:
list
  list all registered future events
create name time
  Create a new event at the given time
delete id
  Delete the event with the given id
accept|yes id
  Register for the event with the given id
decline|no id
  Decline the event with the given id
maybe
  Sit on the fence for the event with the given id (Don't be that guy!)
responses
  List the responses to the event (yes, no, maybe)
  EOF
end

$newstore = ServerEventStore.new(Pathname.new(".data"), "Bot-test")

def main()
  bot = Discordrb::Commands::CommandBot.new token: '', client_id: 311083321994248192, prefix: '!'

  puts "This bot's invite URL is #{bot.invite_url}."
  puts 'Click on it to invite it to your server.'

  FileUtils.mkdir_p('.data')

  bot.command $command_prefix do |event, *args|
    puts args
    case args.first
    when 'create'
      handle_create(event, args)
    when 'delete'
      handle_delete(event, args)
    when 'list'
      handle_list(event, args)
    when /accept|yes/
      handle_yes(event, args)
    when /decline|no/
      handle_no(event, args)
    when 'maybe'
      handle_maybe(event, args)
    when 'help'
      handle_help(event, args)
    when 'responses'
      handle_responses(event, args)
    else event.respond "Command not recognised"
    end
  end

  bot.run

end

main()
