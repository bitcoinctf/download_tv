require 'json'
require 'mechanize'
require 'date'
require 'io/console'
require_relative 'torrent'
require_relative 'myepisodes'
require_relative 'linkgrabber'
require_relative 'grabbers/torrentapi'
require_relative 'grabbers/eztv'

module ShowDownloader

	class Downloader

		attr_reader :app, :offset
		attr_reader :t

		def initialize(args)
			@app = args[0]# || (raise ArgumentError)
			@offset = args[1].to_i || 0
			@t = Torrent.new
			Thread.abort_on_exception = true
		end

		##
		# Gets the links .
		# Auto flag means it selects the torrent without user input
		def run(auto=true)
			Dir.chdir(File.dirname(__FILE__))
			
			check, date = check_date

			exit if check

			print "Enter your MyEpisodes password: "
			pass = STDIN.noecho(&:gets).chomp
			puts

			shows = MyEpisodes.get_shows "Cracky7", pass, date

			puts "Nothing to download" if shows.empty?

			# While the user is selecting a torrent, new Thread to pull next show
			to_download = fix_names(shows)

			queue = Queue.new
			
			link_t = Thread.new do
				to_download.each do |show|
					# puts "Downloading #{show}"
					queue << @t.get_link(show, auto)
				end
				
			end

			download_t = Thread.new do
				to_download.size.times do
					download(queue.pop)
				end
			end

			# Only necessary to join one? Maybe neither
			link_t.join
			download_t.join

			puts "Completed. Exiting..."

			File.write("date", Date.today)

		rescue AuthenticationError
			puts "Wrong username/password combination"
		end

		def check_date
			if !File.exist?("date")
				File.write("date", Date.today-1)
			end
			last = Date.parse(File.read("date"))
			if last != Date.today
				[false, last - @offset]
			else
				puts "Everything up to date"
				[true, nil]
			end
			
		end

		def fix_names(shows)
			# Removes dots and parens
			s = shows.map do |term|
				term.gsub(/(\.|\(|\))/, "")
			end

			# Ignored shows
			ignored = File.read("ignored").split("\n")
			s.reject do |i|
				ignored.include?(i.split(" ")[0..-2].join(" "))
			end
		end

		def download(link)
			exec = "#{@app} \"#{link}\""
			
			Process.detach(Process.spawn(exec, [:out, :err]=>"/dev/null"))

		end

	end
end

=begin
	
TODO: Subtitleseeker http://api.subtitleseeker.com/
TODO: When torrentapi can't find a torrent,
	save the show in a file and try again next execution
TODO: User selects the torrent to download
	
=end