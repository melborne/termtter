module Termtter::Client
  register_command(
    :name => :more,
    :exec_proc => lambda {|arg|
      break if Readline::HISTORY.length < 2
      i = Readline::HISTORY.length - 2
      input = ""
      cnt = 0
      begin
        input = Readline::HISTORY[i]
        i -= 1
        cnt += 1
        return if i <= 0
      end while input == "more" or input =~ /^(some|o|uri-open|uo|[0-7])/
      begin
        if input =~ /^(l|list|s|search|user search)(\s+|$)/
          input.slice!(/\s*#(\d+)/)
          cnt += $1.nil? ? 1 : $1.to_i
          Termtter::Client.execute(input + " ##{cnt}")
        end
        if input =~ /^(google_web|google|gs
                       |google_blog|gb
                       |google_book|gbk
                       |google_image|gi
                       |google_video|gv
                       |google_news|gn
                       |google_patent|gp
                       |google_next_page|gnext)(\s+|$)/x
          Termtter::Client.execute("google_next_page")
        end
      rescue CommandNotFound => e
        warn "Unknown command \"#{e}\""
        warn 'Enter "help" for instructions'
      rescue => e
        handle_error e
      end
    },
    :help => ["more", "List next results"]
  )
end
# list next results for previous command
# ~/.termtter/config
# t.plug 'some'

