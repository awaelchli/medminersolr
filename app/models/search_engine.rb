class SearchEngine

  attr_reader :input, :used_keywords
  def initialize(text)
    @input = text
    @processor = TextProcessor.new(text)
    @result_lists = ListMerger.new
    @used_keywords = Array.new
    @dimensionwords = Array.new
  end

  def search_results
    @result_lists.clear

    search_for_keywords
    
    single_list = @result_lists.merge
    @used_keywords = single_list.used_keywords
    single_list
  end

  private

  def search_for_keywords
     f = File.open('./solr/conf/dimesionwords.txt')
    all_dimensionwords = Array.new
    all_dimensionwords = f.read.split("\n")
    reduced_words = @processor.words.map(&:downcase) - all_dimensionwords.flatten.map(&:downcase)
    @dimensionwords = @processor.words.map(&:downcase) - reduced_words
    keyword_search(reduced_words)
  end
  
  def keyword_search(keywords_array)
    keywords_array.each do |keyword|
      fulltext_search(keyword)
    end
  end

  def fulltext_search(text)
      search = Text.search do
        fulltext text do
          fields(:content,:page => 0.1)
        end
        paginate :page => 1, :per_page => 1000
      end
      
    search_hits = search.hits.map {|hit| SearchHit.new(hit)}
    
    results = ResultsList.new(search_hits, [text])
    @result_lists.push results
  end

end