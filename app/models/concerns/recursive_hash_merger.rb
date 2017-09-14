class RecursiveHashMerger
  def self.merge(*hashes)
    final = {}
    hashes.each do |hash|
      final.merge!(hash) do |key, oldval, newval|
        if oldval.respond_to?(:merge) and newval.respond_to?(:merge)
          self.merge(oldval, newval)
        else
          newval
        end
      end
    end
    final
  end
end