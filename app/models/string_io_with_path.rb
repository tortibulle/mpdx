# Workaround for adding original_filename to StringIO as needed by CarrierWave see:
# https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-Upload-from-a-string-in-Rails-3
class StringIOWithPath < StringIO
  attr_reader :original_filename

  def initialize(*args)
    super(*args[1..-1])
    @original_filename = args[0]
  end
end
