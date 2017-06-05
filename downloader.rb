require 'json'
require 'mechanize'
# require 'http-cookie'
require 'date'
require 'io/console'

require_relative 'torrent'
require_relative 'myepisodes'
require_relative 'linkgrabber'
require_relative 'subtitles'
Dir[File.join(__dir__, 'grabbers', '*.rb')].each {|file| require file }

begin
	require_relative 'config'
rescue LoadError
	puts "Config file not found. Try renaming the config_example file to config.rb"
	exit
end

module ShowDownloader

	class Downloader

		attr_reader :offset, :auto, :subs

		def initialize(offset)
			@offset = offset.abs
			@auto = ShowDownloader::CONFIG[:auto]
			# @subs = ShowDownloader::CONFIG[:subs]
			Thread.abort_on_exception = true
		end

		def download_single_show(show)
			t = Torrent.new
			download(t.get_link(show, @auto))
		end


		def download_from_file(filename)
			raise "File doesn't exist" if !File.exists? filename
			t = Torrent.new
			File.readlines(filename).each { |show| download(t.get_link(show, @auto)) }

		end

		##
		# Gets the links.
		def run(dont_write_to_date_file)
			# Change to installation directory
			Dir.chdir(__dir__)
			
			date = check_date

			myepisodes = MyEpisodes.new(ShowDownloader::CONFIG[:myepisodes_user], ShowDownloader::CONFIG[:cookie_path])
			# Log in using cookie by default
			myepisodes.load_cookie
			shows = myepisodes.get_shows(date)
			
			if shows.empty?
				puts "Nothing to download"

			else
				t = Torrent.new
				to_download = fix_names(shows)

				queue = Queue.new
				
				# Adds a link (or empty string to the queue)
				link_t = Thread.new do
					to_download.each { |show| queue << t.get_link(show, @auto) }
				end

				# Downloads the links as they are added
				download_t = Thread.new do
					to_download.size.times do
						magnet = queue.pop
						next if magnet == "" # Doesn't download if no torrents are found
						download(magnet)
					end
				end

				# Downloading the subtitles
				# subs_t = @subs and Thread.new do
				# 	to_download.each { |show| @s.get_subs(show) }
				# end

				link_t.join
				download_t.join
				# subs_t.join

				puts "Completed. Exiting..."
			end

			File.write("date", Date.today) unless dont_write_to_date_file

		rescue InvalidLoginError
			puts "Wrong username/password combination"
		end


		def check_date
			content = File.read("date")
			
			last = Date.parse(content)
			if last - @offset != Date.today
				last - @offset
			else
				puts "Everything up to date"
				exit
			end
			
		rescue Errno::ENOENT
			File.write("date", Date.today-1)
			retry
		end


		def fix_names(shows)
			# Ignored shows
			s = shows.reject do |i|
				# Remove season+episode
				ShowDownloader::CONFIG[:ignored].include?(i.split(" ")[0..-2].join(" "))
			end

			# Removes apostrophes and parens
			s.map { |t| t.gsub(/ \(.+\)|[']/, "") }
		end


		def download(link)
			exec = "xdg-open \"#{link}\""
			
			Process.detach(Process.spawn(exec, [:out, :err]=>"/dev/null"))

		end
	end
end
