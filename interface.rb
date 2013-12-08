require 'rubygems'
require 'sinatra'
require 'thread'
require 'bgg_parser'

mutex = Mutex.new

get '/' do
  erb :index
end

get '/mmd' do
  erb :mmd
end

get '/rpg-recommendations' do 
  erb :rpgrecommendations
end

post '/find-rpg-recommendations' do
  parser = BGGParser.new
  Thread.new {
    results = parser.get_rpg_recommendations params[:username]
    File.open( "public/#{params[:username]}.txt", 'w' ) do |f2|
      f2.puts "RPG\tPredicted Rating"
      printresults = results.sort{|a,b| b[1]<=>a[1]}
      printresults.each do |item|
        f2.puts "#{parser.get_rpg_name(item[0])}\t#{item[1]}"
      end
    end
  }
  "The program is running in the background and will likely take a while (anywhere from minutes to an hour depending on server load and the number of items you've rated) to complete based on how many items you have rated.  Check back for your results later by <a href=\"#{params[:username]}.txt\">clicking here</a>"
end

post '/translate' do
   output = ''
   mutex.synchronize do
    File.open('to_translate.txt', 'w') do |f2|
      f2.puts params[:data]
    end
    if params[:output] == 'xhtml'
      system './mmd/bin/mmd2XHTML.pl to_translate.txt'
      system 'cp to_translate.html public/to_translate.html'
      output = '<a href="to_translate.html">Translated File</a>'
    end
    if params[:output] == 'pdf'
      system './mmd/bin/mmd2PDF.pl to_translate.txt'
      system 'cp to_translate.pdf public/to_translate.pdf'
      output = '<a href="to_translate.pdf">Translated File</a>'
    end
    if params[:output] == 'rtf'
      system './mmd/bin/mmd2RTF.pl to_translate.txt'
      system 'cp to_translate.rtf public/to_translate.rtf'
      output = '<a href="to_translate.rtf">Translated File</a>'
    end
    output
  end
end
