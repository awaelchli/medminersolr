class SearchEngine

  attr_reader :input
  def initialize(text)
    @input = text
    @processor = TextProcessor.new(text)
    @result_lists = ListMerger.new
  end

  def search_results
    @result_lists.clear

    search_for_keywords
    fulltext_search(@input)
    @result_lists.merge
  end

  private

  def search_for_nouns
    @processor.nouns.each do |noun|
      fulltext_search(noun)
    end
  end

  def search_for_keywords
    keyword_search(@processor.keywords)
  end

  def fulltext_search(text)
    # search = Sunspot.search(Text) do |query|
      # paginate :page => 1, :per_page => 200
      # query.fulltext text do
        # # fields(:content,:page => 1)
         # phrase_fields :content => 2000000.0
         # query_phrase_slop 10000
      # end
      
      search = Text.search do
        fulltext text
        paginate :page => 1, :per_page => 10000
      end
      
    

    results = ResultsList.new(search.hits)
    @result_lists.push results
  end
  
  def keyword_search(keywords_array)

    keywords_array.each do |keyword|
      fulltext_search(keyword)
    end
    
  end

end