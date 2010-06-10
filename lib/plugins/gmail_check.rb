require "net/imap"
require "kconv"
require "termcolor"

class Gmail
  def initialize(username, password)
    begin
      @imap = Net::IMAP.new('imap.gmail.com', 993, true, nil, false)
      @imap.login(username, password)
    rescue Exception => e
      puts e
      exit
    end
  end

  def fetch(select="INBOX", ids="UNSEEN")
    begin
      puts "fetching gmail messages..."
      @imap.examine(select)
      ids = @imap.search(ids)
      puts "you have <red>#{ids.length}</red> unread messages.".termcolor
      return if ids.length < 1
      @imap.fetch(ids, "ENVELOPE").each_with_index do |mail, i|
        sender = mail.attr["ENVELOPE"].sender[0]
        name = sender.name || sender.mailbox || sender.host
        subject = mail.attr["ENVELOPE"].subject || "(no subject)"
        puts "<90>#{i+1}:</90><green>#{name.toutf8} : </green>".termcolor +
             TermColor.colorize("#{subject.toutf8}", 'yellow')
      end
    rescue Exception => e
      puts e
    ensure
      @imap.disconnect
    end
  end
end

module Termtter::Client
  register_command(
    :name => :gmail, :alias => :gm,
    :help => ["gmail,gm", "Just check unread gmail messages"],
    :exec_proc => lambda { |arg|
      username = config.plugins.gmail.username
      password = config.plugins.gmail.password
      if username.empty?
        username = create_highline.ask('Username: ')
      end
      if password.empty?
        password = create_highline.ask('Password: ') { |q| q.echo = false }
      end
      Gmail.new(username, password).fetch
    }
  )
  
  register_command(
    :name => :gmail_open, :alias => :gmo,
    :help => ["gmail_open,gmo", "Open gmail with your browser"],
    :exec_proc => lambda { |arg| open_uri "https://mail.google.com"}
  )
end

# fetch titles from unread gmail messages
# usage: hit 'gmail' command without arg, then name and password will be asked
# you can set them at .termtter/config as follows;
#      config.plugins.gmail.username = 'username'
#      config.plugins.gmail.password = 'password'
# more info => :hp12c http://d.hatena.ne.jp/keyesberry/20100221/p1

