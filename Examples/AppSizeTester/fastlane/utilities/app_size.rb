class AppSize
  attr_accessor :compressed, :uncompressed

  def initialize(compressed, uncompressed)
    @compressed = compressed
    @uncompressed = uncompressed
  end

  # Factory method; uses the hash from `get_app_size_from_ipa` action
  def self.from_hash(hash)
    new(hash[:compressed_size], hash[:uncompressed_size])
  end

  def to_s
    "
    - Compressed: #{@compressed} MB
    - Uncompressed: #{@uncompressed} MB
    "
  end

  def -(other)
    AppSize.new(@compressed - other.compressed, @uncompressed - other.uncompressed)
  end
end
