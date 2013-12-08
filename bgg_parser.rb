require 'set'
require 'rubygems'
require 'open-uri'
require 'nokogiri'

BASE_RPG_URL = "http://www.rpggeek.com"
BASE_USER_URL = "http://www.rpgeek.com/user/"
RPG_URL = "http://www.rpggeek.com/rpg/"
RPG_ITEM_URL = "http://www.rpggeek.com/rpgitem/"
RPG_RATING_URL = "http://www.rpggeek.com/collection/items/rpg/"
RPG_ITEM_RATING_URL = "http://www.rpggeek.com/collection/items/rpgitem/"
USER_RATING_URL = "http://www.rpggeek.com/collection/user/"

RPG = "rpg"
RPG_ITEM = "rpgitem"


class BGGParser
  # Gets ratings for an item and it's parent family
  # If you just need the item or the family's ratings without
  # the aggregation, use the vanila get_ratings method
  def get_rpg_ratings( item_id )
    ratings_hash = get_ratings( RPG_ITEM_RATING_URL + item_id )  
    doc = Nokogiri::HTML( open( RPG_ITEM_URL + item_id ) )
    family_url = doc.xpath( "//div/div/table[2]/tr/td[2]/table/tr/td/div/table[2]/tr/td/div/div[2]/table/tr[2]/td/div/table/tr/td[2]/table/tr[1]/td[2]/div[2]/div/a" )[0]["href"]
    family_url = RPG_RATING_URL + family_url[/\d{1,8}/]
    return_hash = get_ratings( family_url )
    return_hash.merge( ratings_hash )
  end

  def get_ratings( url )
    response = ''
    ret_value = Hash.new
    current_url = url + '?rated=1'
    while( true ) do
      doc = Nokogiri::HTML( open( current_url ) )
      counter = 1 
      doc.xpath( "//tr/td[2]/table/tr/td/div/table/tr" ).each do | result |
        if( counter != 1 ) then
          ret_value[ result.xpath( ".//td[1]/div/div[2]/a")[0]["href"].delete("\/user\/") ] = result.xpath( ".//td[2]/div/div").text
        end
        counter = counter + 1
      end
      if( doc.xpath( "//p/a[@title='next page']" ).empty? )
        break
      end
      current_url = BASE_RPG_URL + doc.xpath( "//p/a[@title='next page']" )[0]["href"]
    end
    ret_value
  end

  def get_ratings_for_user( user, type="rpgitem" )
    return_hash = Hash.new
    counter = 1
    current_url = USER_RATING_URL + user + "?subtype=#{type}&rated=1"    
    while( true ) do
      doc = Nokogiri::HTML( open( current_url ) )
      doc.xpath( "//table[@id='collectionitems']/tr" ).each do | result |
        if( counter != 1 ) then 
          return_hash[ ( result.xpath( ".//td[1]/div//a")[0]["href"] )[/\d{1,8}/] ] = result.xpath( ".//td[3]/div[2]/div/div").text
        end
        counter = counter + 1
      end
      if( doc.xpath( "//p/a[@title='next page']" ).empty? )
        break
      end
      current_url = BASE_RPG_URL + doc.xpath( "//p/a[@title='next page']" )[0]["href"]
    end
    return_hash
  end

  def get_rpg_recommendations( user )
    totals = Hash.new
    totals.default = 0
    rpgsimsums = Hash.new
    rpgsimsums.default = 0
    itemsimsums = Hash.new
    itemsimsums.default = 0
    rpg_rankings = Hash.new
    item_rankings = Hash.new
    rated_games = get_ratings_for_user( user, RPG )
#    rated_items = get_ratings_for_user( user, RPG_ITEM )
    peers = create_peer_list( rated_games.keys )   #, rated_items.keys )  
    peer_rpg_ratings = Hash.new
    peer_item_ratings = Hash.new
puts "Got ratings"
    peers.each do | peer |
      peer_rpg_ratings[ peer ] = get_ratings_for_user( peer, RPG )
#      peer_item_ratings[ peer ] = get_ratings_for_user( peer, RPG_ITEM )
      sim = sim_pearson( rated_games, peer_rpg_ratings[ peer ] )
puts "Calculated similarities"
      if sim <= 0 then next end
      peer_rpg_ratings[ peer ].each do | rpg, rating |
        if rated_games.include? rpg then next end
        totals[ rpg ] = totals[ rpg ] + rating.to_f * sim
        rpgsimsums[ rpg ] = rpgsimsums[ rpg ] + sim
      end
    end
puts "Calculated scores."
    totals.each do | key, value |
      rpg_rankings[ key ] = totals[ key ] / rpgsimsums[ key ]
    end
puts "DONE!"
    rpg_rankings
  end

  def create_peer_list( for_games )   #, for_items )
    peers = Set.new
#    for_items.each do | item |
#      peers.merge get_ratings( RPG_ITEM_RATING_URL + item )
#    end
    for_games.each do | game |
      peers.merge get_ratings( RPG_RATING_URL + game ).keys
    end
    peers
  end

  # Just a reminder, the order of who is first and second matters!
  # This is a magnitude indicating the direction of a vector and should
  # be treated as such
  def sim_pearson( first, second )
    si = Hash.new
    first.each do | item, value |
      if( second.has_key? item ) then si[ item ] = 1 end
    end

    size = si.size
    if( size == 0 ) then return 0 end
    sum = 0.0
    first.keys.each { | item | if si.has_key? item then sum = sum + first[ item ].to_f end }
    sum1 = sum
    sum = 0.0
    second.keys.each { | item | if si.has_key? item then sum = sum + second[ item ].to_f end }
    sum2 = sum
    sum = 0.0
    first.keys.each { | item | if si.has_key? item then sum = sum + (first[item].to_f * first[item].to_f) end }
    sumsq1 = sum
    sum = 0.0
    second.keys.each { | item | if si.has_key? item then sum = sum + (second[item].to_f * second[item].to_f) end }
    sumsq2 = sum
    sum = 0.0
    si.keys.each { | item | if first.has_key?( item ) && second.has_key?( item ) then sum = sum + ( first[item].to_f * second[item].to_f ) end }
    sumproducts = sum

    num = sumproducts.to_f - ( sum1.to_f * sum2.to_f / size.to_f )
    den = Math.sqrt( ( sumsq1.to_f - ( sum1.to_f * sum1.to_f ) / size.to_f ) * (sumsq2.to_f - ( sum2.to_f * sum2.to_f ) / size.to_f ) )
    if den == 0 then return 0 end
    num/den
  end

  def get_rpg_name( id )
    doc = Nokogiri::HTML( open( "http://rpggeek.com/xmlapi2/family?id=#{id}&type=rpg" ) )
    return doc.xpath( "//name[@type='primary']" )[0]["value"]
  end
end

parser = BGGParser.new
#ratings = parser.get_ratings_for_user( 'rjstreet' )
#ratings = parser.get_rpg_ratings( '66316' )
#ratings = parser.get_ratings( RPG_ITEM_RATING_URL + '66316' )
#parser.get_rpg_name( 4472 )
ratings = parser.get_rpg_recommendations( 'rjstreet' )
ratings.each do | item |
  puts "#{parser.get_rpg_name(item[0])}\t#{item[1]}"
end
