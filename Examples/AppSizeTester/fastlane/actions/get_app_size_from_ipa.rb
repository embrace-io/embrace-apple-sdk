module Fastlane
  module Actions
    module SharedValues
      APP_THINNING_FILE = :APP_THINNING_FILE
      APP_SIZE_COMPRESSED_VALUE = :APP_SIZE_COMPRESSED_VALUE
      APP_SIZE_UNCOMPRESSED_VALUE = :APP_SIZE_UNCOMPRESSED_VALUE
    end

    class GetAppSizeFromIpaAction < Action
      def self.run(params)
        ipa_directory_name = File.dirname(params[:ipa_path])
        if File.directory?(ipa_directory_name)
          app_size = read_app_thinning_report(ipa_directory_name)

          if params[:show_output]
            puts("\n")
            puts(Terminal::Table.new(
              title: params[:ipa_path].green,
              headings: ['Compressed (MB)', 'Uncompressed (MB)'],
              rows: [[app_size[:compressed_size], app_size[:uncompressed_size]]]
            ))
            puts("\n")
          end

          return app_size
        end
        UI.user_error!("#{ipa_directory_name} is not a valid path.")
      end
  
      def self.convert_to_mb(size, unit)
        case unit
        when "KB"
          size / 1024.0
        when "MB"
          size
        else
          UI.user_error!("Unsupported unit #{unit}")
        end
      end
  
      # Parse the given line to extract compressed and uncompressed sizes.
      #
      # This method uses regular expressions to find size data in the input line. It supports sizes
      # in both KB and MB units and converts all sizes to MB. If the necessary data cannot be found,
      # it raises a user error via Fastlane's UI.user_error! method, which halts execution.
      #
      # @param line [String] the string containing the size data to be parsed.
      # @return [Hash] A hash containing the compressed and uncompressed sizes in MB.
      #                The hash includes two keys: :compressed_size and :uncompressed_size.
      #                Each key's value is a Float representing the size in MB.
      # @raise [FastlaneCore::Interface::FastlaneError] if the line does not contain valid size data.
      #
      # @example
      #   line = "App size: 120,3 KB compressed, 1,0 MB uncompressed"
      #   sizes = parse_app_size_line(line)
      #   puts sizes  # => { compressed_size: 0.1175, uncompressed_size: 1.0 }

      def self.parse_app_size_line(line)

        compressed_match = line.match(/(\d+([.,]\d+)?) (KB|MB) compressed/)
        uncompressed_match = line.match(/(\d+([.,]\d+)?) (KB|MB) uncompressed/)
    
        if compressed_match && uncompressed_match
          compressed_size, compressed_unit = compressed_match[1].gsub(',', '.').to_f, compressed_match[3]
          uncompressed_size, uncompressed_unit = uncompressed_match[1].gsub(',', '.').to_f, uncompressed_match[3]
  
          compressed_size = convert_to_mb(compressed_size, compressed_unit)
          uncompressed_size = convert_to_mb(uncompressed_size, uncompressed_unit)
    
          return {
            "compressed_size": compressed_size,
            "uncompressed_size": uncompressed_size
          }
        else
          UI.user_error!("Couldn't file un/compressed sizes in line: #{line}")
        end
      end 

      # Reads the 'App Thinning Size Report' from a specified folder and extracts app size data.
      #
      # This method searches for an "App Thinning Size Report.txt" file in the given folder.
      # It parses the file to find the line that starts with "App size:" and extracts compressed
      # and uncompressed sizes using `parse_app_size_line`. If found, it adds the report file path
      # to the resulting hash.
      #
      # @param folder [String] the path to the folder containing the App Thinning Size Report.
      # @return [Hash] A hash containing the compressed and uncompressed sizes and the path to the report file.
      #                The hash keys are :compressed_size, :uncompressed_size, and :app_thining_file.
      # @raise [FastlaneCore::Interface::FastlaneError] if the report file is not found or the App Size line is missing.
      #
      # @example
      #   folder_path = "./path/to/reports"
      #   result = read_app_thinning_report(folder_path)
      #   puts result  # => { compressed_size: 1.2, uncompressed_size: 3.4, app_thining_file: "./path/to/reports/App Thinning Size Report.txt" }
      
      def self.read_app_thinning_report(folder)
        report_file = "#{folder}/App Thinning Size Report.txt"
        if File.exist?(report_file)
          UI.success("Found report in #{folder}")
          File.foreach(report_file) do |line|
            if line.start_with?("App size:")
              UI.message("Extracting sizes from line:\n'#{line.strip}'\n")
              hash = parse_app_size_line(line)
              hash[:app_thining_file] = report_file
              return hash
            end
          end
          UI.user_error!("Couldn't fine App Size in report #{report_file}")
        else
          UI.user_error!("No 'App Thinning Size Report.txt' found in #{folder}")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Given the path of an .ipa with an app thining report, provides the compressed/uncompressed size of it'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :ipa_path,
                                       description: 'The path of the .ipa to measure the size of',
                                       default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
                                       is_string: true,
                                       verify_block: proc do |value|
                                         unless value && !value.empty?
                                           UI.user_error!("No ipa path was provided")
                                         end
                                       end
                                       ),
          FastlaneCore::ConfigItem.new(key: :show_output,
                                       description: 'Prints the output before returning',
                                       env_name: "SHOW_APP_SIZE_OUTPUT",
                                       default_value: false,
                                       is_string: false
                                       ),
        ]
      end

      def self.output
        [
          ['APP_THINNING_FILE', 'The path to the App Thinning Size Report file used by this action'],
          ['APP_SIZE_COMPRESSED_VALUE', 'The compressed size of the .ipa, extracted from the App Thinning Size Report'],
          ['APP_SIZE_UNCOMPRESSED_VALUE', 'The uncompressed size of the .ipa, extracted from the App Thinning Size Report' ]
        ]
      end

      def self.return_value
        'Outputs hash of results with the following keys: :compressed_size, :uncompressed_size, :app_thining_file'
      end

      def self.return_type
        :hash
      end

      def self.authors
        ['Embrace (https://https://embrace.io/)']
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
