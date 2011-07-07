%w{rubident test/unit pp}.each { |g| require g }

class TestSetup < Test::Unit::TestCase

	# the required files exist
	def test_files_exist
		%w{rubident-test rubident-keys-test}.each do |f|
			begin
				# Try to open existing file
				File.open("#{ENV["HOME"]}/.#{f}", "r")
				
				# Read
				assert_nothing_raised {
					File.open("#{ENV["HOME"]}/.#{f}", "r") { |t| t.read }
				}
			rescue	# File not found
				# Create
				assert_nothing_raised {
					File.new("#{ENV["HOME"]}/.#{f}", "a+")
				}
				assert_nothing_raised {
					# Read
					File.open("#{ENV["HOME"]}/.#{f}", "r") { |t| t.read }
				}
			end

			# Delete
			assert_nothing_raised {
				File.delete("#{ENV["HOME"]}/.#{f}")
			}	
		end
	end

end